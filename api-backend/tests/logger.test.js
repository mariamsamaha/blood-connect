describe('logger', () => {
  const originalEnv = { ...process.env };

  afterEach(() => {
    jest.resetModules();
    process.env = { ...originalEnv };
  });

  test('creates a production logger with the configured level', () => {
    process.env.NODE_ENV = 'production';
    process.env.LOG_LEVEL = 'warn';

    const logger = require('../src/logger');

    expect(logger.level).toBe('warn');
    expect(typeof logger.info).toBe('function');
    expect(typeof logger.error).toBe('function');
  });

  test('serializes request and response metadata safely', () => {
    process.env.NODE_ENV = 'production';
    const pino = require('pino');
    const logger = require('../src/logger');
    const serializers = logger[pino.symbols.serializersSym];

    expect(serializers.req({
      method: 'GET',
      url: '/health',
      id: 'fallback-id',
      headers: { 'x-request-id': 'request-id' },
    })).toEqual({
      method: 'GET',
      url: '/health',
      requestId: 'request-id',
    });

    expect(serializers.req({
      method: 'POST',
      url: '/requests',
      id: 'fallback-id',
    })).toEqual({
      method: 'POST',
      url: '/requests',
      requestId: 'fallback-id',
    });

    expect(serializers.res({ statusCode: 204 })).toEqual({ statusCode: 204 });
    expect(typeof serializers.err).toBe('function');
  });
});
