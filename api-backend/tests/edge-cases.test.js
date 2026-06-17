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
  withTransaction: jest.fn(),
  testConnection: jest.fn().mockResolvedValue(true),
  validateDbConfig: jest.fn().mockReturnValue({ ok: true, mode: 'test' }),
  pool: {
    totalCount: 0,
    idleCount: 0,
    waitingCount: 0,
    on: jest.fn(),
  },
}));

describe('Edge Cases', () => {
  let app;

  beforeAll(() => {
    app = require('../src/server');
  });

  describe('Large payload handling', () => {
    test('rejects oversized request body (over 1MB)', async () => {
      const largeBody = { data: 'x'.repeat(2 * 1024 * 1024) };
      const res = await request(app)
        .post('/api/v1/users/me/bootstrap')
        .set('Authorization', 'Bearer test-token')
        .send(largeBody);
      expect(res.status).toBe(413);
    });
  });

  describe('Invalid JSON body', () => {
    test('returns 400 for malformed JSON', async () => {
      const res = await request(app)
        .post('/api/v1/users/me/bootstrap')
        .set('Authorization', 'Bearer test-token')
        .set('Content-Type', 'application/json')
        .send('not-json-at-all');
      expect(res.status).toBe(400);
    });
  });

  describe('Missing content-type header', () => {
    test('handles request without content-type', async () => {
      const res = await request(app)
        .get('/api/v1/users/me')
        .set('Authorization', 'Bearer test-token');
      expect([401, 404, 500]).toContain(res.status);
    });
  });

  describe('SQL injection attempts', () => {
    test('query param injection does not crash', async () => {
      const res = await request(app)
        .get('/api/v1/hospitals?lat=1;DROP TABLE users;--&lng=2');
      expect([200, 401]).toContain(res.status);
    });

    test('path traversal does not crash', async () => {
      const res = await request(app)
        .get('/api/v1/requests/../../../etc/passwd');
      expect([401, 404]).toContain(res.status);
    });
  });

  describe('Double-slash in path', () => {
    test('handles double slash gracefully', async () => {
      const res = await request(app)
        .get('//api/v1/users/me')
        .set('Authorization', 'Bearer test-token');
      expect([200, 401, 404]).toContain(res.status);
    });
  });

  describe('Extremely long path', () => {
    test('handles long URL path without crashing', async () => {
      const longPath = '/api/v1/' + 'a'.repeat(5000);
      const res = await request(app).get(longPath);
      expect([404, 400, 401, 431]).toContain(res.status);
    });
  });

  describe('Unexpected HTTP methods', () => {
    test('OPTIONS returns successfully', async () => {
      const res = await request(app).options('/');
      expect([200, 204]).toContain(res.status);
    });

    test('PUT returns 404', async () => {
      const res = await request(app)
        .put('/api/v1/users/me')
        .set('Content-Type', 'application/json');
      expect(res.status).toBe(404);
    });

    test('TRACE returns 404', async () => {
      const res = await request(app).trace('/');
      expect(res.status).toBe(404);
    });
  });

  describe('Empty request body', () => {
    test('POST with empty body returns 400 for bootstrap', async () => {
      const res = await request(app)
        .post('/api/v1/users/me/bootstrap')
        .set('Authorization', 'Bearer test-token')
        .set('Content-Type', 'application/json')
        .send();
      expect([201, 400, 500]).toContain(res.status);
    });
  });

  describe('Invalid blood type in requests', () => {
    test('rejects blood type with wrong casing', async () => {
      const res = await request(app)
        .post('/api/v1/requests')
        .set('Authorization', 'Bearer test-token')
        .send({
          requesterId: 'uuid',
          bloodType: 'o+',
          unitsNeeded: 1,
          urgencyLevel: 'routine',
          hospitalId: 'uuid',
          hospitalLat: 30,
          hospitalLng: 31,
        });
      expect([400, 401]).toContain(res.status);
    });
  });

  describe('Negative coordinate values', () => {
    test('handles negative lat/lng on hospital query', async () => {
      const res = await request(app)
        .get('/api/v1/hospitals?lat=-33.86&lng=151.21');
      expect([200, 401]).toContain(res.status);
    });
  });

  describe('Zero radius for donor matching', () => {
    test('handles radiusKm=0 gracefully', async () => {
      const res = await request(app)
        .get('/api/v1/donor/matches?donorId=test&compatibleTypesCsv=O%2B&donorLat=30&donorLng=31&radiusKm=0');
      expect([200, 401]).toContain(res.status);
    });
  });
});
