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
  if (req.path === '/metrics' || req.path === '/health' || req.path === '/slo') return next();

  const route = req.route ? req.route.path : req.path;
  const end = httpRequestDuration.startTimer({ method: req.method, route });
  req._startTime = Date.now();

  httpRequestInFlight.inc();

  res.on('finish', () => {
    const labels = { method: req.method, route, status_code: res.statusCode };
    httpRequestTotal.inc(labels);
    end(labels);
    httpRequestInFlight.dec();
    slo.recordRequest(res.statusCode, Date.now() - req._startTime);
  });

  next();
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
  trackDbQuery,
  updatePoolStats,
  metricsHandler,
  circuitBreakerState,
  circuitBreakerFailures,
  notificationDispatchDuration,
  notificationDispatchTotal,
};
