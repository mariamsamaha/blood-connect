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

const mockQ = jest.fn();
const mockWithTransaction = jest.fn().mockImplementation(async (callback) => {
  return await callback(mockQ);
});
const mockDb = {
  query: jest.fn(),
  withTransaction: mockWithTransaction,
  testConnection: jest.fn().mockResolvedValue(true),
  validateDbConfig: jest.fn().mockReturnValue({ ok: true, mode: 'test' }),
  pool: {
    totalCount: 0,
    idleCount: 0,
    waitingCount: 0,
    end: jest.fn(),
    on: jest.fn(),
  },
};

jest.mock('../src/db', () => mockDb);

const { CircuitBreaker, STATE } = require('../src/circuit-breaker');

describe('Failure Scenarios', () => {
  let app;

  beforeAll(() => {
    app = require('../src/server');
  });

  afterAll(() => {
    jest.unmock('firebase-admin');
    jest.unmock('../src/db');
  });

  describe('1. Circuit breaker: 5 notification failures -> OPEN -> fallback', () => {
    test('transitions to OPEN after threshold failures and calls fallback', async () => {
      const cb = new CircuitBreaker('test-service', {
        failureThreshold: 5,
        successThreshold: 2,
        timeoutMs: 30000,
      });

      expect(cb.getStateName()).toBe('CLOSED');

      const fallback = jest.fn().mockReturnValue({ fallback: true });
      const failingFn = jest.fn().mockRejectedValue(new Error('fail'));

      for (let i = 0; i < 5; i++) {
        const result = await cb.call(failingFn, fallback);
        if (cb.state === STATE.OPEN) {
          expect(result).toEqual({ fallback: true });
        }
      }

      expect(cb.getStateName()).toBe('OPEN');
      expect(fallback).toHaveBeenCalled();

      // When OPEN, fallback is called without executing fn
      fallback.mockClear();
      failingFn.mockClear();
      const openResult = await cb.call(failingFn, fallback);
      expect(openResult).toEqual({ fallback: true });
      expect(failingFn).not.toHaveBeenCalled();
    });

    test('returns default fallback object when no fallback provided', async () => {
      const cb = new CircuitBreaker('no-fallback', {
        failureThreshold: 1,
        timeoutMs: 30000,
      });

      await expect(cb.call(() => Promise.reject(new Error('fail')))).rejects.toThrow('fail');
      expect(cb.getStateName()).toBe('OPEN');

      const fn = jest.fn().mockResolvedValue('ok');
      const result = await cb.call(fn);
      expect(fn).not.toHaveBeenCalled();
      expect(result).toEqual({ circuitBreakerOpen: true, service: 'no-fallback' });
    });
  });

  describe('2. DB down: kill pool -> 503 on next request', () => {
    test('GET /health/db returns 503 when pool is dead', async () => {
      mockDb.testConnection.mockRejectedValueOnce(new Error('Connection refused'));

      const res = await request(app).get('/health/db');
      expect(res.status).toBe(503);
      expect(res.body.status).toBe('error');
      expect(res.body.detail).toContain('Connection refused');
    });

    test('GET /api/v1/users/me returns 500 when DB query fails', async () => {
      mockDb.query.mockRejectedValueOnce(new Error('pool is dead'));

      const res = await request(app)
        .get('/api/v1/users/me')
        .set('Authorization', 'Bearer test-token');
      expect(res.status).toBe(500);
      expect(res.body.error).toBe('internal_error');
    });
  });

  describe('3. Concurrent donor accept - exactly one succeeds', () => {
    beforeEach(() => {
      mockDb.query.mockReset();
      mockQ.mockReset();
      mockWithTransaction.mockClear();
    });

    test('parallel accepts on same request_id - first wins, second gets 409', async () => {
      let cteCallCount = 0;
      mockQ.mockImplementation((sql) => {
        if (sql.includes('FOR UPDATE')) {
          cteCallCount++;
          if (cteCallCount === 1) {
            return Promise.resolve();
          }
          const err = new Error('duplicate key value violates unique constraint "donor_responses_pkey"');
          return Promise.reject(err);
        }
        if (sql.includes('response_type')) {
          return Promise.resolve([{ response_type: 'accepted' }]);
        }
        if (sql.includes('SELECT status')) {
          return Promise.resolve([{ status: 'in_progress' }]);
        }
        return Promise.resolve([]);
      });

      const body = {
        requestId: 'req-1',
        donorId: 'donor-1',
        donorLat: 30.0444,
        donorLng: 31.2357,
      };

      const [res1, res2] = await Promise.all([
        request(app)
          .post('/api/v1/donor/responses/accept')
          .set('Authorization', 'Bearer test-token')
          .send(body),
        request(app)
          .post('/api/v1/donor/responses/accept')
          .set('Authorization', 'Bearer test-token')
          .send(body),
      ]);

      const succeeded = [res1, res2].filter(r => r.status === 204);
      const failed = [res1, res2].filter(r => r.status === 409);

      expect(succeeded.length).toBe(1);
      expect(failed.length).toBe(1);
      if (failed[0]) {
        expect(failed[0].body.error).toBe('already_accepted');
      }
    });
  });
});
