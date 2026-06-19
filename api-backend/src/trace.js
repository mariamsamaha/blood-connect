const { randomUUID } = require('crypto');
const { context, trace, propagation } = require('@opentelemetry/api');

function traceMiddleware(req, res, next) {
  const activeContext = propagation.extract(context.active(), req.headers);
  const spanContext = trace.getSpanContext(activeContext);

  const traceId = spanContext?.traceId
    ? spanContext.traceId.padStart(32, '0')
    : (req.headers['x-trace-id'] || randomUUID().replace(/-/g, '')).padStart(32, '0');

  const spanId = spanContext?.spanId
    ? spanContext.spanId.padStart(16, '0')
    : randomUUID().split('-')[0].padStart(16, '0');

  req.trace = { traceId, spanId };
  req.requestId = req.requestId || traceId;

  res.setHeader('x-trace-id', traceId);
  res.setHeader('x-span-id', spanId);

  if (req.log) {
    req.log.setBindings({ traceId, spanId });
  }

  next();
}

module.exports = { traceMiddleware };
