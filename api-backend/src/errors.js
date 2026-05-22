const logger = require('./logger');

function isDev() {
  return process.env.NODE_ENV !== 'production';
}

function serverError(res, err, route) {
  const rid = res.req?.requestId || '?';
  logger.error({ err, route, requestId: rid }, 'Server error');
  return res.status(500).json({
    error: 'internal_error',
    ...(isDev() && {
      detail: err.message || String(err),
      route,
      requestId: rid,
    }),
  });
}

module.exports = { serverError, isDev };
