const prometheus = require('prom-client');
const slo = require('./slo');

const register = new prometheus.Registry();

prometheus.collectDefaultMetrics({ register, prefix: 'bloodconnect_' });

const httpRequestDuration = new prometheus.Histogram({
  name: 'bloodconnect_http_request_duration_ms',
  help: 'Duration of HTTP requests in ms',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [10, 50, 100, 200, 500, 1000, 2000, 5000],
  registers: [register],
});

const httpRequestTotal = new prometheus.Counter({
  name: 'bloodconnect_http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register],
});

const httpRequestInFlight = new prometheus.Gauge({
  name: 'bloodconnect_http_requests_in_flight',
  help: 'Number of HTTP requests currently in flight',
  registers: [register],
});

const dbQueryDuration = new prometheus.Histogram({
  name: 'bloodconnect_db_query_duration_ms',
  help: 'Duration of database queries in ms',
  labelNames: ['operation'],
  buckets: [5, 20, 50, 100, 200, 500, 1000],
  registers: [register],
});

const dbPoolSize = new prometheus.Gauge({
  name: 'bloodconnect_db_pool_size',
  help: 'Database connection pool size',
  labelNames: ['state'],
  registers: [register],
});

const circuitBreakerState = new prometheus.Gauge({
  name: 'bloodconnect_circuit_breaker_state',
  help: 'Circuit breaker state (0=closed, 1=open, 2=half-open)',
  labelNames: ['service'],
  registers: [register],
});
circuitBreakerState.set({ service: 'notification-backend' }, 0); // 0 = CLOSED
circuitBreakerState.set({ service: 'ai' }, 0);

const circuitBreakerFailures = new prometheus.Counter({
  name: 'bloodconnect_circuit_breaker_failures_total',
  help: 'Total circuit breaker failures',
  labelNames: ['service'],
  registers: [register],
});

const notificationDispatchDuration = new prometheus.Histogram({
  name: 'bloodconnect_notification_dispatch_duration_ms',
  help: 'Duration of push notification dispatch',
  buckets: [50, 100, 200, 500, 1000, 2000, 5000],
  registers: [register],
});

const notificationDispatchTotal = new prometheus.Counter({
  name: 'bloodconnect_notification_dispatches_total',
  help: 'Total push notification dispatches',
  labelNames: ['status'],
  registers: [register],
});

function metricsMiddleware(req, res, next) {
  if (req.path === '/metrics' || req.path === '/slo' || req.path === '/' || req.path === '/health/db') {
    return next();
  }

  const route = req.route ? req.route.path : req.path;
  const end = httpRequestDuration.startTimer({ method: req.method, route });
  req._startTime = Date.now();

  httpRequestInFlight.inc();

  res.on('finish', () => {
    const labels = { method: req.method, route, status_code: res.statusCode };
    httpRequestTotal.inc(labels);
    end(labels);
    httpRequestInFlight.dec();
    // recordRequest is async (Redis-backed) — fire-and-forget with error handling
    // so a transient Redis failure can never surface as an unhandled rejection.
    slo.recordRequest(res.statusCode, Date.now() - req._startTime).catch(() => {});
  });

  next();
}

/**
 * Defense-in-depth: restrict /metrics and /slo to internal callers even at
 * the app layer, in case a request reaches the process without going through
 * Nginx (e.g. direct container port access during development).
 *
 * Two ways to pass:
 *   1. Request comes from a private/loopback IP (Docker internal network).
 *   2. METRICS_TOKEN env var is set AND the Authorization header matches.
 *
 * To enable token auth for remote Prometheus or Grafana Cloud:
 *   METRICS_TOKEN=$(openssl rand -hex 32)   # in api-backend/.env
 *   # prometheus.yml: bearer_token: <same value>
 */
function metricsAuthMiddleware(req, res, next) {
  const metricsToken = process.env.METRICS_TOKEN;

  if (metricsToken) {
    const authHeader = req.headers.authorization || '';
    if (authHeader === `Bearer ${metricsToken}`) return next();
  }

  const ip =
    req.headers['x-real-ip'] ||
    req.headers['x-forwarded-for']?.split(',')[0]?.trim() ||
    req.socket.remoteAddress ||
    '';

  const isPrivate =
    ip === '127.0.0.1' ||
    ip === '::1' ||
    ip.startsWith('10.') ||
    ip.startsWith('172.') ||
    ip.startsWith('192.168.');

  if (isPrivate) return next();

  return res.status(403).json({
    error: 'forbidden',
    detail: 'metrics endpoint is restricted to internal network',
  });
}

function trackDbQuery(operation, durationMs) {
  dbQueryDuration.observe({ operation }, durationMs);
}

function updatePoolStats(total, idle, waiting) {
  dbPoolSize.set({ state: 'total' }, total);
  dbPoolSize.set({ state: 'idle' }, idle);
  dbPoolSize.set({ state: 'waiting' }, waiting);
}

async function metricsHandler(_req, res) {
  res.setHeader('Content-Type', register.contentType);
  res.end(await register.metrics());
}

module.exports = {
  register,
  metricsMiddleware,
  metricsAuthMiddleware,
  trackDbQuery,
  updatePoolStats,
  metricsHandler,
  circuitBreakerState,
  circuitBreakerFailures,
  notificationDispatchDuration,
  notificationDispatchTotal,
};
