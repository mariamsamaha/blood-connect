function isDev() {
  return process.env.NODE_ENV !== 'production';
}

function serverError(res, err, route) {
  const rid = res.req?.requestId || '?';
  console.error(`[${route}] [rid=${rid}]`, err.message || err);
  if (err.stack && isDev()) {
    console.error(err.stack);
  }
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
