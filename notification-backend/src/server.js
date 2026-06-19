// Simple Express backend to send FCM v1 notifications.
// Uses Firebase Admin SDK and the service account pointed to by
// GOOGLE_APPLICATION_CREDENTIALS in your environment.

require('./tracing');

const express = require('express');
const rateLimit = require('express-rate-limit');
const admin = require('firebase-admin');
const logger = require('./logger');
const metrics = require('./metrics');

async function sendWithRetry(fn, { maxRetries = 3, baseDelayMs = 500, label = 'send' } = {}) {
  let lastError;
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err;
      logger.warn({ err, attempt, maxRetries, label }, 'sendWithRetry failed');
      if (attempt < maxRetries) {
        const delay = baseDelayMs * Math.pow(2, attempt - 1) + Math.random() * 200;
        await new Promise((r) => setTimeout(r, delay));
      }
    }
  }
  logger.error({ err: lastError, label, maxRetries }, 'sendWithRetry exhausted');
  throw lastError;
}

admin.initializeApp();

const app = express();
let server;
const isProduction = process.env.NODE_ENV === 'production';

if (isProduction) {
  app.set('trust proxy', 1);
  app.use((req, res, next) => {
    const proto = req.headers['x-forwarded-proto'];
    if (proto && proto !== 'https') {
      return res.status(403).json({ error: 'https_required' });
    }
    return next();
  });
}

app.use(express.json());

app.use(metrics.metricsMiddleware);

app.use((req, _res, next) => {
  req.requestId = req.headers['x-request-id'] || require('crypto').randomUUID();
  next();
});

app.use(require('pino-http')({
  logger,
  genReqId: (req) => req.requestId,
  customLogLevel: (res, _err) => {
    if (res.statusCode >= 500) return 'error';
    if (res.statusCode >= 400) return 'warn';
    return 'info';
  },
}));

const limiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  message: { error: 'too_many_requests' },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use('/sendNewRequest', limiter);

// ─── Auth middleware ──────────────────────────────────────────────────────────
// All non-health-check routes require the shared secret set in the environment.
// The Flutter app must send the same value in the x-internal-secret header.
const INTERNAL_SECRET = process.env.INTERNAL_SECRET || '';

function requireSecret(req, res, next) {
  if (!INTERNAL_SECRET) {
    // Secret not configured on the server — block all requests to avoid
    // running an open relay silently.
    logger.error('INTERNAL_SECRET env var is not set. Refusing request.');
    return res.status(500).json({ error: 'server_misconfigured' });
  }
  const provided = req.headers['x-internal-secret'] || '';
  if (provided !== INTERNAL_SECRET) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  return next();
}
// ─────────────────────────────────────────────────────────────────────────────

// Health check (no auth needed)
app.get('/', (_req, res) => {
  res.status(200).send('Notification backend is running');
});

app.get('/metrics', metrics.metricsHandler);

// Main endpoint called from the Flutter app.
// Expects body:
// {
//   "request": {
//     "id": "...",
//     "short_id": "...",
//     "blood_type": "...",
//     "units_needed": 2,
//     "hospital_name": "..."
//   },
//   "tokens": ["fcmToken1", "fcmToken2", ...]
// }
// Generic notification endpoint for any push (used for fulfillment updates, etc.)
// Expects body:
// {
//   "title": "...",
//   "body": "...",
//   "data": { ... },
//   "tokens": ["fcmToken1", ...]
// }
app.post('/sendNotification', requireSecret, async (req, res) => {
  const dispatchStart = Date.now();
  try {
    const { title, body, data, tokens } = req.body || {};

    if (!title || !body || !Array.isArray(tokens)) {
      return res.status(400).json({ error: 'invalid_payload' });
    }

    const cleanTokens = tokens.filter((t) => typeof t === 'string' && t.length > 0);
    if (cleanTokens.length === 0) {
      return res.status(200).json({ sent: 0 });
    }

    const message = {
      notification: { title, body },
      data: { ...data, type: data?.type ?? 'notification' },
      tokens: cleanTokens,
    };

    const CHUNK = 500;
    let successCount = 0;
    let failureCount = 0;
    const staleTokens = [];

    for (let i = 0; i < cleanTokens.length; i += CHUNK) {
      const chunk = cleanTokens.slice(i, i + CHUNK);
      const response = await sendWithRetry(
        () => admin.messaging().sendEachForMulticast({
          ...message,
          tokens: chunk,
        }),
        { label: 'sendNotification' },
      );

      successCount += response.successCount;
      failureCount += response.failureCount;

      if (response.failureCount > 0) {
        response.responses.forEach((r, j) => {
          if (!r.success) {
            const code = r.error?.code;
            console.error(`Token[${i + j}] failed: ${code}`);
            if (code === 'messaging/registration-token-not-registered' ||
                code === 'messaging/invalid-registration-token') {
              staleTokens.push(cleanTokens[i + j]);
            }
          }
        });
      }
    }

    if (staleTokens.length > 0) {
      logger.warn({ count: staleTokens.length }, 'Stale tokens to purge');
    }

    const elapsed = Date.now() - dispatchStart;
    metrics.notificationDispatchDuration.observe({ route: '/sendNotification' }, elapsed);
    metrics.notificationDispatchesTotal.inc({ route: '/sendNotification', status: 'success' }, successCount);
    metrics.notificationDispatchesTotal.inc({ route: '/sendNotification', status: 'failure' }, failureCount);

    logger.info({ sent: successCount, total: cleanTokens.length }, 'Push sent');
    return res.status(200).json({ sent: successCount, failed: failureCount, stale_tokens: staleTokens });
  } catch (err) {
    const elapsed = Date.now() - dispatchStart;
    metrics.notificationDispatchDuration.observe({ route: '/sendNotification' }, elapsed);
    console.error('Error in /sendNotification', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

app.post('/sendNewRequest', requireSecret, async (req, res) => {
  const dispatchStart = Date.now();
  try {
    const { request, tokens } = req.body || {};

    if (!request || !Array.isArray(tokens)) {
      return res.status(400).json({ error: 'invalid_payload' });
    }

    const cleanTokens = tokens.filter((t) => typeof t === 'string' && t.length > 0);
    if (cleanTokens.length === 0) {
      return res.status(200).json({ sent: 0 });
    }

    const urgency = request.urgency_level || 'urgent';
    const label = urgency === 'critical' ? '🚨 Critical' : urgency === 'urgent' ? '⚠️ Urgent' : 'New';

    const message = {
      notification: {
        title: `${label}: ${request.blood_type} needed`,
        body: `${request.units_needed} unit(s) needed at ${request.hospital_name}`,
      },
      data: {
        type: 'new_request',
        request_id: String(request.id ?? ''),
        short_id: String(request.short_id ?? ''),
        blood_type: String(request.blood_type ?? ''),
        hospital_name: String(request.hospital_name ?? ''),
        urgency_level: String(request.urgency_level ?? ''),
      },
      tokens: cleanTokens,
    };

    const CHUNK = 500;
    let successCount = 0;
    let failureCount = 0;
    const staleTokens = [];

    for (let i = 0; i < cleanTokens.length; i += CHUNK) {
      const chunk = cleanTokens.slice(i, i + CHUNK);
      const response = await sendWithRetry(
        () => admin.messaging().sendEachForMulticast({
          ...message,
          tokens: chunk,
        }),
        { label: 'sendNewRequest' },
      );

      successCount += response.successCount;
      failureCount += response.failureCount;

      if (response.failureCount > 0) {
        response.responses.forEach((r, j) => {
          if (!r.success) {
            const code = r.error?.code;
            console.error(`Token[${i + j}] failed: ${code}`);
            if (code === 'messaging/registration-token-not-registered' ||
                code === 'messaging/invalid-registration-token') {
              staleTokens.push(cleanTokens[i + j]);
            }
          }
        });
      }
    }

    if (staleTokens.length > 0) {
      logger.warn({ count: staleTokens.length }, 'Stale tokens to purge');
    }

    const elapsed = Date.now() - dispatchStart;
    metrics.notificationDispatchDuration.observe({ route: '/sendNewRequest' }, elapsed);
    metrics.notificationDispatchesTotal.inc({ route: '/sendNewRequest', status: 'success' }, successCount);
    metrics.notificationDispatchesTotal.inc({ route: '/sendNewRequest', status: 'failure' }, failureCount);

    logger.info({ sent: successCount, total: cleanTokens.length, shortId: request.short_id }, 'Push sent');
    return res.status(200).json({ sent: successCount, failed: failureCount, stale_tokens: staleTokens });
  } catch (err) {
    const elapsed = Date.now() - dispatchStart;
    metrics.notificationDispatchDuration.observe({ route: '/sendNewRequest' }, elapsed);
    console.error('Error in /sendNewRequest', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

if (process.env.NODE_ENV !== 'test') {
  const port = parseInt(process.env.PORT || '8080', 10);
  const useTls =
    isProduction && process.env.TLS_KEY_PATH && process.env.TLS_CERT_PATH;

  if (useTls) {
    const fs = require('fs');
    const https = require('https');
    server = https
      .createServer(
        {
          key: fs.readFileSync(process.env.TLS_KEY_PATH),
          cert: fs.readFileSync(process.env.TLS_CERT_PATH),
        },
        app,
      )
      .listen(port, () => {
        logger.info(`Notification backend listening on HTTPS port ${port}`);
      });
  } else {
    const http = require('http');
    server = http.createServer(app).listen(port, () => {
      logger.info(
        `Notification backend listening on HTTP port ${port}${isProduction ? ' (terminate TLS at load balancer or set TLS_KEY_PATH/TLS_CERT_PATH)' : ''}`,
      );
    });
  }

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

function shutdown(signal) {
  logger.info(`Shutting down gracefully on ${signal}...`);
  if (server) {
    server.close(() => {
      logger.info('Notification server closed');
      process.exit(0);
    });
  }
  setTimeout(() => {
    console.error('Forced shutdown after timeout');
    process.exit(1);
  }, 10_000).unref();
}

module.exports = app;