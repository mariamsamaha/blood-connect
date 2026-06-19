const prometheus = require('prom-client');

const register = new prometheus.Registry();

prometheus.collectDefaultMetrics({ register, prefix: 'bloodconnect_' });

const notificationDispatchDuration = new prometheus.Histogram({
  name: 'bloodconnect_notification_dispatch_duration_ms',
  help: 'Duration of FCM notification dispatch',
  labelNames: ['route'],
  buckets: [50, 100, 200, 500, 1000, 2000, 5000],
  registers: [register],
});

const notificationDispatchesTotal = new prometheus.Counter({
  name: 'bloodconnect_notification_dispatches_total',
  help: 'Total FCM notification dispatches',
  labelNames: ['route', 'status'],
  registers: [register],
});

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

function metricsMiddleware(req, res, next) {
  if (req.path === '/metrics') {
    return next();
  }
  const route = req.route ? req.route.path : req.path;
  const end = httpRequestDuration.startTimer({ method: req.method, route });

  res.on('finish', () => {
    const labels = { method: req.method, route, status_code: res.statusCode };
    httpRequestTotal.inc(labels);
    end(labels);
  });

  next();
}

async function metricsHandler(_req, res) {
  res.setHeader('Content-Type', register.contentType);
  res.end(await register.metrics());
}

module.exports = {
  register,
  metricsMiddleware,
  metricsHandler,
  notificationDispatchDuration,
  notificationDispatchesTotal,
};
