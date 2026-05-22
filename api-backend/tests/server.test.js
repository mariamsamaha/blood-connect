const mockLogger = {
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
  debug: jest.fn(),
  child: jest.fn(() => mockLogger),
  level: 'silent',
};

jest.mock('../src/logger', () => mockLogger);

jest.mock('pino-http', () => () => (req, _res, next) => {
  req.log = { info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() };
  next();
});

const request = require('supertest');

jest.mock('firebase-admin', () => ({
  credential: { cert: jest.fn() },
  initializeApp: jest.fn(),
  apps: [],
  auth: () => ({
    verifyIdToken: jest.fn().mockResolvedValue({ uid: 'test-uid' }),
  }),
}));

jest.mock('../src/db', () => ({
  query: jest.fn(),
  testConnection: jest.fn().mockResolvedValue(true),
  validateDbConfig: jest.fn().mockReturnValue({ ok: true, mode: 'test' }),
  pool: {
    totalCount: 0,
    idleCount: 0,
    waitingCount: 0,
    on: jest.fn(),
  },
}));

describe('API Backend Server', () => {
  let app;

  beforeAll(() => {
    app = require('../src/server');
  });

  afterAll(() => {
    jest.unmock('firebase-admin');
    jest.unmock('../src/db');
  });

  describe('GET /', () => {
    test('returns 200 with service status', async () => {
      const res = await request(app).get('/');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ok');
      expect(res.body.service).toBe('bloodconnect-api');
    });
  });

  describe('GET /health/db', () => {
    test('returns 200 when DB is healthy', async () => {
      const res = await request(app).get('/health/db');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ok');
    });

    test('returns 503 when DB config is invalid', async () => {
      const db = require('../src/db');
      db.validateDbConfig.mockReturnValueOnce({ ok: false, missing: ['SUPABASE_HOST'] });
      const res = await request(app).get('/health/db');
      expect(res.status).toBe(503);
      expect(res.body.status).toBe('misconfigured');
    });

    test('returns pool stats and uptime', async () => {
      const res = await request(app).get('/health/db');
      expect(res.body).toHaveProperty('pool');
      expect(res.body).toHaveProperty('uptime_s');
      expect(res.body).toHaveProperty('latency_ms');
    });
  });

  describe('GET /api/v1/users/me', () => {
    test('returns 401 without auth header', async () => {
      const res = await request(app).get('/api/v1/users/me');
      expect(res.status).toBe(401);
      expect(res.body.error).toBe('missing_token');
    });

    test('returns 401 with malformed auth header', async () => {
      const res = await request(app)
        .get('/api/v1/users/me')
        .set('Authorization', 'Basic token');
      expect(res.status).toBe(401);
      expect(res.body.error).toBe('missing_token');
    });
  });

  describe('auth middleware', () => {
    test('rejects request without Bearer token', async () => {
      const res = await request(app)
        .get('/api/v1/users/me')
        .set('Authorization', 'Bearer ');
      expect(res.status).toBe(401);
    });
  });

  describe('GET /api/docs', () => {
    test('serves Swagger UI', async () => {
      const res = await request(app).get('/api/docs/');
      expect([301, 302, 200]).toContain(res.status);
    });
  });

  describe('GET /api/docs.json', () => {
    test('returns OpenAPI spec', async () => {
      const res = await request(app).get('/api/docs.json');
      expect(res.status).toBe(200);
      expect(res.body.openapi).toBe('3.0.0');
      expect(res.body.info.title).toBe('BloodConnect API');
    });
  });

  describe('rate limiting', () => {
    test('global limiter does not block low traffic', async () => {
      for (let i = 0; i < 5; i++) {
        await request(app).get('/');
      }
      const res = await request(app).get('/');
      expect(res.status).toBe(200);
    });
  });
});
