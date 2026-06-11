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
const mockQ = jest.fn();
const mockWithTransaction = jest.fn().mockImplementation(async (callback) => {
  return await callback(mockQ);
});
const mockDb = {
  query: jest.fn().mockImplementation((sql, params) => {
    mockQueryLog.push({ sql: sql.substring(0, 120), params });
    return Promise.resolve([]);
  }),
  withTransaction: mockWithTransaction,
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
    mockQ.mockClear();
    mockWithTransaction.mockClear();
  });

  describe('Create request + audit log + notification in explicit transaction', () => {
    test('POST /api/v1/requests writes blood_request + audit_log + notification atomically', async () => {
      mockDb.query
        .mockResolvedValueOnce([{ hospital_code: 'CH', hospital_name: 'City Hospital' }])
        .mockResolvedValueOnce([{ short_id: 'CH-ABCD' }])
        .mockResolvedValueOnce([{ donor_count: 5 }]);

      mockQ
        .mockResolvedValueOnce([{
          id: 'req-new-1', short_id: 'CH-ABCD', blood_type: 'A+',
          units_needed: 2, urgency_level: 'critical',
          hospital_name: 'City Hospital',
          hospital_lat: 30.05, hospital_lng: 31.24,
          status: 'active', nearby_donors_count: 5, total_eligible_count: 5,
          created_at: new Date().toISOString(),
          expires_at: new Date(Date.now() + 86400000).toISOString(),
        }])
        .mockResolvedValueOnce([])
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

      expect(mockWithTransaction).toHaveBeenCalledTimes(1);
      expect(mockQ).toHaveBeenCalledTimes(3);
      expect(mockQ.mock.calls[0][0]).toContain('WITH');
      expect(mockQ.mock.calls[0][0]).toContain('INSERT INTO blood_requests');
      expect(mockQ.mock.calls[1][0]).toContain('INSERT INTO request_audit_log');
      expect(mockQ.mock.calls[2][0]).toContain('INSERT INTO notifications');
    });

    test('rollback when audit_log insert fails mid-transaction', async () => {
      mockDb.query
        .mockResolvedValueOnce([{ hospital_code: 'CH', hospital_name: 'City Hospital' }])
        .mockResolvedValueOnce([{ short_id: 'CH-ABCD' }])
        .mockResolvedValueOnce([{ donor_count: 5 }]);

      mockQ
        .mockResolvedValueOnce([{
          id: 'req-1', short_id: 'CH-ABCD', blood_type: 'A+',
          units_needed: 2, urgency_level: 'critical',
          hospital_name: 'City Hospital',
          hospital_lat: 30.05, hospital_lng: 31.24,
          status: 'active',
        }])
        .mockRejectedValueOnce(new Error('db_error'));

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

      expect(res.status).toBe(500);
      expect(mockWithTransaction).toHaveBeenCalledTimes(1);
      expect(mockQ).toHaveBeenCalledTimes(2);
      expect(mockQ.mock.calls[0][0]).toContain('INSERT INTO blood_requests');
      expect(mockQ.mock.calls[1][0]).toContain('INSERT INTO request_audit_log');
      const notifCalls = mockQ.mock.calls.filter(c => c[0].includes('INSERT INTO notifications'));
      expect(notifCalls).toHaveLength(0);
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

  describe('Donor accept uses row-level locking (FOR UPDATE) in explicit transaction', () => {
    test('POST /api/v1/donor/responses/accept uses FOR UPDATE lock', async () => {
      mockQ
        .mockResolvedValueOnce()
        .mockResolvedValueOnce([{ response_type: 'accepted' }])
        .mockResolvedValueOnce([{ status: 'in_progress' }])
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce([{ requester_id: 'r1', hospital_id: 'h1', hospital_name: 'H', blood_type: 'O+' }])
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce([]);

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
      expect(mockWithTransaction).toHaveBeenCalledTimes(1);
      expect(mockQ.mock.calls[0][0]).toContain('FOR UPDATE');
      expect(mockQ.mock.calls[0][0]).toContain('INSERT INTO donor_responses');
      expect(mockQ.mock.calls[1][0]).toContain('SELECT response_type');
    });

    test('rollback when audit_log insert fails mid-transaction', async () => {
      mockQ
        .mockResolvedValueOnce()
        .mockResolvedValueOnce([{ response_type: 'accepted' }])
        .mockResolvedValueOnce([{ status: 'in_progress' }])
        .mockRejectedValueOnce(new Error('db_error'));

      const res = await request(app)
        .post('/api/v1/donor/responses/accept')
        .set('Authorization', 'Bearer test-token')
        .send({
          requestId: 'req-1',
          donorId: 'donor-1',
          donorLat: 30.0444,
          donorLng: 31.2357,
        });

      expect(res.status).toBe(500);
      expect(mockWithTransaction).toHaveBeenCalledTimes(1);
      expect(mockQ).toHaveBeenCalledTimes(4);
      expect(mockQ.mock.calls[0][0]).toContain('FOR UPDATE');
      expect(mockQ.mock.calls[3][0]).toContain('INSERT INTO request_audit_log');
      const notifCalls = mockQ.mock.calls.filter(c => c[0] && c[0].includes('INSERT INTO notifications'));
      expect(notifCalls).toHaveLength(0);
    });
  });

  describe('Hospital verify uses explicit transaction', () => {
    test('POST /api/v1/hospital/verify writes verification + notifications atomically', async () => {
      mockQ
        .mockResolvedValueOnce([{ success: true, error_message: null }])
        .mockResolvedValueOnce([{
          requester_id: 'r1', hospital_id: 'h1',
          hospital_name: 'City Hospital', blood_type: 'O+', donor_id: 'd1',
        }])
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce([]);

      const res = await request(app)
        .post('/api/v1/hospital/verify')
        .set('Authorization', 'Bearer test-token')
        .send({
          hospitalUserId: 'h1',
          requestId: 'req-1',
          staffName: 'Dr. Smith',
        });

      expect(res.status).toBe(200);
      expect(res.body.error).toBeNull();
      expect(mockWithTransaction).toHaveBeenCalledTimes(1);
      expect(mockQ).toHaveBeenCalledTimes(4);
      expect(mockQ.mock.calls[0][0]).toContain('verify_request_donation');
      expect(mockQ.mock.calls[2][0]).toContain('INSERT INTO notifications');
    });

    test('rollback when notification insert fails after verification', async () => {
      mockQ
        .mockResolvedValueOnce([{ success: true, error_message: null }])
        .mockResolvedValueOnce([{
          requester_id: 'r1', hospital_id: 'h1',
          hospital_name: 'City Hospital', blood_type: 'O+', donor_id: 'd1',
        }])
        .mockRejectedValueOnce(new Error('db_error'));

      const res = await request(app)
        .post('/api/v1/hospital/verify')
        .set('Authorization', 'Bearer test-token')
        .send({
          hospitalUserId: 'h1',
          requestId: 'req-1',
          staffName: 'Dr. Smith',
        });

      expect(res.status).toBe(500);
      expect(mockWithTransaction).toHaveBeenCalledTimes(1);
      expect(mockQ).toHaveBeenCalledTimes(3);
      expect(mockQ.mock.calls[0][0]).toContain('verify_request_donation');
      expect(mockQ.mock.calls[2][0]).toContain('INSERT INTO notifications');
    });
  });
});
