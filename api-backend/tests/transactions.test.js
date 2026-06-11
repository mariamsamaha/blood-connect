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

const mockQueryLog = [];
const mockDb = {
  query: jest.fn().mockImplementation((sql, params) => {
    mockQueryLog.push({ sql: sql.substring(0, 120), params });
    return Promise.resolve([]);
  }),
  testConnection: jest.fn().mockResolvedValue(true),
  validateDbConfig: jest.fn().mockReturnValue({ ok: true, mode: 'test' }),
  pool: {
    totalCount: 2,
    idleCount: 1,
    waitingCount: 0,
    on: jest.fn(),
  },
};

jest.mock('../src/db', () => mockDb);

describe('Wrapped Transaction Tests', () => {
  let app;

  beforeAll(() => {
    app = require('../src/server');
  });

  afterAll(() => {
    jest.unmock('firebase-admin');
    jest.unmock('../src/db');
  });

  beforeEach(() => {
    mockQueryLog.length = 0;
    mockDb.query.mockClear();
  });

  describe('Create request + audit log in single flow (CTE-backed)', () => {
    test('POST /api/v1/requests writes blood_request + audit_log + notification', async () => {
      mockDb.query
        .mockResolvedValueOnce([{ hospital_code: 'CH', hospital_name: 'City Hospital' }])
        .mockResolvedValueOnce([{ short_id: 'CH-ABCD' }])
        .mockResolvedValueOnce([{ donor_count: 5 }])
        .mockResolvedValueOnce([{
          id: 'req-new-1', short_id: 'CH-ABCD', blood_type: 'A+',
          units_needed: 2, urgency_level: 'critical',
          hospital_name: 'City Hospital',
          hospital_lat: 30.05, hospital_lng: 31.24,
          status: 'active', nearby_donors_count: 5, total_eligible_count: 5,
          created_at: new Date().toISOString(),
          expires_at: new Date(Date.now() + 86400000).toISOString(),
        }])
        .mockResolvedValueOnce([{ id: 'audit-1' }])
        .mockResolvedValueOnce([]);

      const res = await request(app)
        .post('/api/v1/requests')
        .set('Authorization', 'Bearer test-token')
        .send({
          requesterId: 'requester-1',
          bloodType: 'A+',
          unitsNeeded: 2,
          urgencyLevel: 'critical',
          hospitalId: 'hosp-1',
          hospitalLat: 30.05,
          hospitalLng: 31.24,
        });

      expect(res.status).toBe(201);
      expect(res.body.id).toBe('req-new-1');
      expect(res.body.short_id).toBe('CH-ABCD');

      expect(mockDb.query.mock.calls.length).toBeGreaterThanOrEqual(4);

      const insertCall = mockDb.query.mock.calls.find(call => call[0].includes('INSERT INTO blood_requests'));
      expect(insertCall).toBeDefined();
      expect(insertCall[0]).toContain('WITH');
    });
  });

  describe('Cancel request updates blood_request + user + audit log', () => {
    test('POST /api/v1/requests/:id/cancel writes multi-row changes', async () => {
      mockDb.query
        .mockResolvedValueOnce([{ id: 'req-1' }])
        .mockResolvedValueOnce([{ id: 'audit-1' }]);

      const res = await request(app)
        .post('/api/v1/requests/req-1/cancel')
        .set('Authorization', 'Bearer test-token')
        .send({ userId: 'requester-1' });

      expect(res.status).toBe(200);
      expect(res.body.ok).toBe(true);

      const cancelQuery = mockDb.query.mock.calls[0];
      expect(cancelQuery).toBeDefined();
      expect(cancelQuery[0]).toContain('UPDATE blood_requests');
      expect(cancelQuery[0]).toContain('UPDATE users');

      expect(mockDb.query.mock.calls.length).toBeGreaterThanOrEqual(2);
      const auditQuery = mockDb.query.mock.calls[1];
      expect(auditQuery[0]).toContain('INSERT INTO request_audit_log');
    });
  });

  describe('Donor accept uses row-level locking (FOR UPDATE)', () => {
    test('POST /api/v1/donor/responses/accept uses FOR UPDATE lock', async () => {
      mockDb.query
        .mockResolvedValueOnce([{ id: 'req-1', status: 'active' }])
        .mockResolvedValueOnce([{ response_type: 'accepted' }])
        .mockResolvedValueOnce([{ status: 'in_progress' }])
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce([{ requester_id: 'r1', hospital_id: 'h1', hospital_name: 'H', blood_type: 'O+' }]);

      const res = await request(app)
        .post('/api/v1/donor/responses/accept')
        .set('Authorization', 'Bearer test-token')
        .send({
          requestId: 'req-1',
          donorId: 'donor-1',
          donorLat: 30.0444,
          donorLng: 31.2357,
        });

      expect(res.status).toBe(204);

      expect(mockDb.query.mock.calls[0][0]).toContain('FOR UPDATE');
      expect(mockDb.query.mock.calls[0][0]).toContain('INSERT INTO donor_responses');
      expect(mockDb.query.mock.calls[1][0]).toContain('SELECT response_type');
    });
  });
});
