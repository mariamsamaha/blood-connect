const { diag, DiagConsoleLogger, DiagLogLevel } = require('@opentelemetry/api');

if (process.env.OTEL_LOG_LEVEL) {
  diag.setLogger(new DiagConsoleLogger(), DiagLogLevel[process.env.OTEL_LOG_LEVEL] || DiagLogLevel.WARN);
}

const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { BatchSpanProcessor, ConsoleSpanExporter } = require('@opentelemetry/sdk-trace-base');
const { registerInstrumentations } = require('@opentelemetry/instrumentation');
const { ExpressInstrumentation } = require('@opentelemetry/instrumentation-express');
const { HttpInstrumentation } = require('@opentelemetry/instrumentation-http');
const { PgInstrumentation } = require('@opentelemetry/instrumentation-pg');
const { IORedisInstrumentation } = require('@opentelemetry/instrumentation-ioredis');

const provider = new NodeTracerProvider({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'bloodconnect-api',
    [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
    'deployment.environment': process.env.NODE_ENV || 'development',
  }),
});

const otlpEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || process.env.OTLP_ENDPOINT;
if (otlpEndpoint) {
  const traceExporter = new OTLPTraceExporter({
    url: `${otlpEndpoint.replace(/\/+$/, '')}/v1/traces`,
  });
  provider.addSpanProcessor(new BatchSpanProcessor(traceExporter, {
    maxExportBatchSize: 512,
    scheduledDelayMillis: 5000,
    maxQueueSize: 2048,
  }));
} else {
  provider.addSpanProcessor(new BatchSpanProcessor(new ConsoleSpanExporter(), {
    scheduledDelayMillis: 10000,
  }));
}

provider.register();

registerInstrumentations({
  instrumentations: [
    new ExpressInstrumentation(),
    new HttpInstrumentation(),
    new PgInstrumentation(),
    new IORedisInstrumentation(),
  ],
});

module.exports = { provider };
