const request = require('supertest');

describe('API Backend Server', () => {
  let app;

  beforeAll(() => {
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
    }));
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
});
