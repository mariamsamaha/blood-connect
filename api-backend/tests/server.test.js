// Prevent AI_SERVICE_URL from .env causing timeouts — use rule-based fallback
// Set to empty (dotenv won't override an already-set variable)
process.env.AI_SERVICE_URL = '';

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

const mockDb = {
  query: jest.fn(),
  withTransaction: jest.fn(),
  testConnection: jest.fn().mockResolvedValue(true),
  healthQuery: jest.fn().mockResolvedValue([{ ok: 1 }]),
  validateDbConfig: jest.fn().mockReturnValue({ ok: true, mode: 'test' }),
  pool: {
    totalCount: 0,
    idleCount: 0,
    waitingCount: 0,
    on: jest.fn(),
  },
  bulkheadPool: {
    totalCount: 0,
    idleCount: 0,
    waitingCount: 0,
    on: jest.fn(),
  },
};

jest.mock('../src/db', () => mockDb);

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

  describe('POST /api/v1/ai/eligibility', () => {
    test('returns 401 without token', async () => {
      const res = await request(app).post('/api/v1/ai/eligibility').send({
        donorId: 'd-1',
        bloodType: 'O+',
      });
      expect(res.status).toBe(401);
    });

    test('returns 400 when donorId or bloodType is missing', async () => {
      const res = await request(app)
        .post('/api/v1/ai/eligibility')
        .set('Authorization', 'Bearer test-token')
        .send({
          donorId: 'd-1',
        });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('donor_id_and_blood_type_required');
    });

    test('returns eligible status for fully healthy rule check', async () => {
      const res = await request(app)
        .post('/api/v1/ai/eligibility')
        .set('Authorization', 'Bearer test-token')
        .send({
          donorId: 'd-1',
          bloodType: 'O+',
          feelingWell: true,
          recentIllness: false,
        });
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('eligible');
      expect(res.body.score).toBeCloseTo(0.8);
      expect(res.body.warnings).toHaveLength(0);
      expect(res.body.tips).toContain('Great — you appear to be in good health for donation.');
    });

    test('returns uncertain status when having recent illness but feeling well', async () => {
      const res = await request(app)
        .post('/api/v1/ai/eligibility')
        .set('Authorization', 'Bearer test-token')
        .send({
          donorId: 'd-1',
          bloodType: 'O+',
          feelingWell: true,
          recentIllness: true,
        });
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('uncertain');
      expect(res.body.score).toBeCloseTo(0.5);
    });

    test('returns not_eligible status when feeling unwell', async () => {
      const res = await request(app)
        .post('/api/v1/ai/eligibility')
        .set('Authorization', 'Bearer test-token')
        .send({
          donorId: 'd-1',
          bloodType: 'O+',
          feelingWell: false,
          recentIllness: false,
        });
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('not_eligible');
      expect(res.body.score).toBeCloseTo(0.4);
    });

    test('returns not_eligible when feeling unwell and has recent illness', async () => {
      const res = await request(app)
        .post('/api/v1/ai/eligibility')
        .set('Authorization', 'Bearer test-token')
        .send({
          donorId: 'd-1',
          bloodType: 'O+',
          feelingWell: false,
          recentIllness: true,
        });
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('not_eligible');
      expect(res.body.score).toBeCloseTo(0.1);
    });
  });

  describe('GET /api/v1/users/me (not found)', () => {
    test('returns 404 when user not found in DB', async () => {
      const db = require('../src/db');
      db.query.mockResolvedValueOnce([]);

      const res = await request(app)
        .get('/api/v1/users/me')
        .set('Authorization', 'Bearer test-token');
      expect(res.status).toBe(404);
      expect(res.body.error).toBe('not_found');
    });
  });

  describe('POST /api/v1/users/me/complete', () => {
    test('returns 400 when dateOfBirth is missing for non-hospital', async () => {
      const res = await request(app)
        .post('/api/v1/users/me/complete')
        .set('Authorization', 'Bearer test-token')
        .send({ accountType: 'regular' });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('date_of_birth_required');
    });

    test('returns 400 when dateOfBirth is invalid', async () => {
      const res = await request(app)
        .post('/api/v1/users/me/complete')
        .set('Authorization', 'Bearer test-token')
        .send({ accountType: 'regular', dateOfBirth: 'not-a-date' });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('invalid_date_of_birth');
    });

    test('returns 400 when user is under 18', async () => {
      const res = await request(app)
        .post('/api/v1/users/me/complete')
        .set('Authorization', 'Bearer test-token')
        .send({ accountType: 'regular', dateOfBirth: '2020-01-01' });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('must_be_18_or_older');
    });

    test('returns 201 when accountType is hospital (no DOB required)', async () => {
      const db = require('../src/db');
      db.query
        .mockResolvedValueOnce([])                           // check by firebase_uid
        .mockResolvedValueOnce([])                           // check by email
        .mockResolvedValueOnce([{ id: 'h-new', hospital_name: 'City Hospital' }]);  // INSERT

      const res = await request(app)
        .post('/api/v1/users/me/complete')
        .set('Authorization', 'Bearer test-token')
        .send({
          accountType: 'hospital',
          email: 'hosp@test.com',
          name: 'Test Hosp',
          hospitalName: 'City Hospital',
          hospitalCode: 'CH001',
          latitude: 30.04,
          longitude: 31.23,
        });
      expect(res.status).toBe(201);
    });
  });

  describe('PATCH /api/v1/users/me', () => {
    test('returns 400 when updates is missing', async () => {
      const res = await request(app)
        .patch('/api/v1/users/me')
        .set('Authorization', 'Bearer test-token')
        .send({});
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('invalid_payload');
    });

    test('returns 400 when no allowed fields in updates', async () => {
      const res = await request(app)
        .patch('/api/v1/users/me')
        .set('Authorization', 'Bearer test-token')
        .send({ updates: { disallowed_field: 'value' } });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('no_allowed_fields');
    });
  });

  describe('GET /api/v1/hospitals', () => {
    test('returns hospitals with location-based sorting', async () => {
      const db = require('../src/db');
      db.query.mockResolvedValueOnce([{ id: 'h1', hospital_name: 'Test Hosp', distance_km: 5, is_far: 0 }]);

      const res = await request(app)
        .get('/api/v1/hospitals?lat=30.04&lng=31.23')
        .set('Authorization', 'Bearer test-token');
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body[0].hospital_name).toBe('Test Hosp');
    });
  });

  describe('POST /api/v1/requests validation', () => {
    test('returns 400 for invalid urgency level', async () => {
      const res = await request(app)
        .post('/api/v1/requests')
        .set('Authorization', 'Bearer test-token')
        .send({
          requesterId: 'uuid',
          bloodType: 'O+',
          unitsNeeded: 1,
          urgencyLevel: 'invalid',
          hospitalId: 'uuid',
          hospitalLat: 30,
          hospitalLng: 31,
        });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('invalid_urgency_level');
    });

    test('returns 400 for negative units', async () => {
      const res = await request(app)
        .post('/api/v1/requests')
        .set('Authorization', 'Bearer test-token')
        .send({
          requesterId: 'uuid',
          bloodType: 'O+',
          unitsNeeded: -1,
          urgencyLevel: 'routine',
          hospitalId: 'uuid',
          hospitalLat: 30,
          hospitalLng: 31,
        });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('unitsNeeded must be a positive integer');
    });
  });

  describe('GET /metrics', () => {
    test('returns Prometheus metrics', async () => {
      const res = await request(app).get('/metrics');
      expect(res.status).toBe(200);
      expect(res.text).toContain('bloodconnect_');
    });
  });

  describe('GET /slo', () => {
    test('returns SLO report with in-memory fallback', async () => {
      const res = await request(app).get('/slo');
      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('targets');
      expect(res.body).toHaveProperty('windows');
      expect(res.body.backend).toBe('in-memory-fallback');
    });
  });

  describe('Content-Type validation', () => {
    test('rejects POST with wrong content type', async () => {
      const res = await request(app)
        .post('/api/v1/users/me/bootstrap')
        .set('Authorization', 'Bearer test-token')
        .set('Content-Type', 'text/plain')
        .send('raw data');
      expect(res.status).toBe(415);
      expect(res.body.error).toBe('unsupported_media_type');
    });
  });

  describe('POST /api/v1/hospital/verify authorization', () => {
    test('returns 403 for donor role', async () => {
      // Role lookup returns 'donor' — not allowed
      mockDb.query.mockResolvedValue([{ id: 'user-uuid', role: 'donor' }]);

      const res = await request(app)
        .post('/api/v1/hospital/verify')
        .set('Authorization', 'Bearer test-token')
        .send({ requestId: 'req-uuid', staffName: 'Dr. Test' });
      expect(res.status).toBe(403);
      expect(res.body.error).toBe('forbidden_role');
    });

    test('returns 403 for recipient role', async () => {
      mockDb.query.mockResolvedValue([{ id: 'user-uuid', role: 'recipient' }]);

      const res = await request(app)
        .post('/api/v1/hospital/verify')
        .set('Authorization', 'Bearer test-token')
        .send({ requestId: 'req-uuid', staffName: 'Dr. Test' });
      expect(res.status).toBe(403);
      expect(res.body.error).toBe('forbidden_role');
    });

    test('returns 404 when user not found in DB', async () => {
      mockDb.query.mockResolvedValue([]);

      const res = await request(app)
        .post('/api/v1/hospital/verify')
        .set('Authorization', 'Bearer test-token')
        .send({ requestId: 'req-uuid' });
      expect(res.status).toBe(404);
      expect(res.body.error).toBe('user_not_found');
    });
  });
});

