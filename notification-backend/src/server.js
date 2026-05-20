// Simple Express backend to send FCM v1 notifications.
// Uses Firebase Admin SDK and the service account pointed to by
// GOOGLE_APPLICATION_CREDENTIALS in your environment.

const express = require('express');
const rateLimit = require('express-rate-limit');
const admin = require('firebase-admin');

admin.initializeApp();

const app = express();
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
    console.error('INTERNAL_SECRET env var is not set. Refusing request.');
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
app.post('/sendNewRequest', requireSecret, async (req, res) => {
  try {
    const { request, tokens } = req.body || {};

    if (!request || !Array.isArray(tokens)) {
      return res.status(400).json({ error: 'invalid_payload' });
    }

    const cleanTokens = tokens.filter((t) => typeof t === 'string' && t.length > 0);
    if (cleanTokens.length === 0) {
      return res.status(200).json({ sent: 0 });
    }

    const message = {
      notification: {
        title: `Blood request: ${request.blood_type}`,
        body: `${request.units_needed} unit(s) needed at ${request.hospital_name}`,
      },
      data: {
        type: 'new_request',
        request_id: String(request.id ?? ''),
        short_id: String(request.short_id ?? ''),
        blood_type: String(request.blood_type ?? ''),
        hospital_name: String(request.hospital_name ?? ''),
      },
      tokens: cleanTokens,
    };

    const CHUNK = 500;
    let successCount = 0;
    let failureCount = 0;
    const staleTokens = [];

    for (let i = 0; i < cleanTokens.length; i += CHUNK) {
      const chunk = cleanTokens.slice(i, i + CHUNK);
      const response = await admin.messaging().sendEachForMulticast({
        ...message,
        tokens: chunk,
      });

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
      console.warn(`Stale tokens to purge: ${staleTokens.length}`);
    }

    console.log(`Sent ${successCount}/${cleanTokens.length} for request ${request.short_id}`);
    return res.status(200).json({ sent: successCount, failed: failureCount, stale_tokens: staleTokens });
  } catch (err) {
    console.error('Error in /sendNewRequest', err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

const port = parseInt(process.env.PORT || '8080', 10);
const useTls =
  isProduction && process.env.TLS_KEY_PATH && process.env.TLS_CERT_PATH;

if (useTls) {
  const fs = require('fs');
  const https = require('https');
  https
    .createServer(
      {
        key: fs.readFileSync(process.env.TLS_KEY_PATH),
        cert: fs.readFileSync(process.env.TLS_CERT_PATH),
      },
      app,
    )
    .listen(port, () => {
      console.log(`Notification backend listening on HTTPS port ${port}`);
    });
} else {
  const http = require('http');
  http.createServer(app).listen(port, () => {
    console.log(
      `Notification backend listening on HTTP port ${port}${isProduction ? ' (terminate TLS at load balancer or set TLS_KEY_PATH/TLS_CERT_PATH)' : ''}`,
    );
  });
}