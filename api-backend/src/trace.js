const { randomUUID } = require('crypto');

function traceMiddleware(req, res, next) {
  const traceId = req.headers['x-trace-id'] || randomUUID();
  const parentSpanId = req.headers['x-span-id'];
  const spanId = randomUUID().split('-')[0];

  req.trace = { traceId, spanId, parentSpanId };
  req.requestId = req.requestId || traceId;

  res.setHeader('x-trace-id', traceId);
  res.setHeader('x-span-id', spanId);

  if (req.log) {
    req.log.setBindings({ traceId, spanId });
  }

  next();
}

module.exports = { traceMiddleware };
