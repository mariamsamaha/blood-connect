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
  req.log = { info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(), setBindings: jest.fn() };
  next();
});

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
  healthQuery: jest.fn().mockResolvedValue([{ ok: 1 }]),
  validateDbConfig: jest.fn().mockReturnValue({ ok: true, mode: 'test' }),
  pool: { totalCount: 5, idleCount: 2, waitingCount: 0, end: jest.fn(), on: jest.fn() },
  bulkheadPool: { totalCount: 2, idleCount: 1, waitingCount: 0, on: jest.fn() },
};
jest.mock('../src/db', () => mockDb);

const { CircuitBreaker, STATE } = require('../src/circuit-breaker');

describe('Chaos & Resilience', () => {
  describe('1. Circuit breaker OPEN state behavior', () => {
    test('blocks calls and returns fallback in OPEN state', async () => {
      const cb = new CircuitBreaker('open-test', {
        failureThreshold: 2,
        timeoutMs: 30000,
      });

      await cb.call(() => Promise.reject(new Error('fail'))).catch(() => {});
      await cb.call(() => Promise.reject(new Error('fail'))).catch(() => {});
      expect(cb.getStateName()).toBe('OPEN');

      const fn = jest.fn().mockResolvedValue('should not run');
      const result = await cb.call(fn);
      expect(fn).not.toHaveBeenCalled();
      expect(result).toEqual({ circuitBreakerOpen: true, service: 'open-test' });
    });

    test('rejects with error when no fallback provided', async () => {
      const cb = new CircuitBreaker('no-fallback-open', {
        failureThreshold: 1,
        timeoutMs: 30000,
      });

      await expect(cb.call(() => Promise.reject(new Error('fail')))).rejects.toThrow('fail');
      expect(cb.getStateName()).toBe('OPEN');
    });
  });

  describe('2. Circuit breaker HALF_OPEN -> CLOSED recovery via time travel', () => {
    test('transitions to HALF_OPEN then CLOSED after enough successes', async () => {
      const realDateNow = Date.now;
      const t0 = realDateNow();

      Date.now = jest.fn(() => t0);
      const cb = new CircuitBreaker('recovery-test', {
        failureThreshold: 2,
        successThreshold: 2,
        timeoutMs: 10000,
      });

      await cb.call(() => Promise.reject(new Error('fail'))).catch(() => {});
      await cb.call(() => Promise.reject(new Error('fail'))).catch(() => {});
      expect(cb.getStateName()).toBe('OPEN');

      Date.now = jest.fn(() => t0 + 10001);
      const r1 = await cb.call(() => Promise.resolve('ok'));
      expect(r1).toBe('ok');
      expect(cb.getStateName()).toBe('HALF_OPEN');

      const r2 = await cb.call(() => Promise.resolve('ok'));
      expect(r2).toBe('ok');
      expect(cb.getStateName()).toBe('CLOSED');

      Date.now = realDateNow;
    });

    test('re-opens after failure in HALF_OPEN state', async () => {
      const realDateNow = Date.now;
      const t0 = realDateNow();

      Date.now = jest.fn(() => t0);
      const cb = new CircuitBreaker('half-open-fail', {
        failureThreshold: 2,
        successThreshold: 1,
        timeoutMs: 5000,
      });

      await cb.call(() => Promise.reject(new Error('fail'))).catch(() => {});
      await cb.call(() => Promise.reject(new Error('fail'))).catch(() => {});
      expect(cb.getStateName()).toBe('OPEN');

      Date.now = jest.fn(() => t0 + 5001);
      await cb.call(() => Promise.reject(new Error('still fail'))).catch(() => {});
      expect(cb.getStateName()).toBe('OPEN');

      Date.now = realDateNow;
    });

    test('returns fallback while still OPEN before timeout elapses', async () => {
      const realDateNow = Date.now;
      const t0 = realDateNow();

      Date.now = jest.fn(() => t0);
      const cb = new CircuitBreaker('timeout-test', {
        failureThreshold: 1,
        timeoutMs: 10000,
      });

      await cb.call(() => Promise.reject(new Error('fail'))).catch(() => {});
      expect(cb.getStateName()).toBe('OPEN');

      Date.now = jest.fn(() => t0 + 5000);
      const result = await cb.call(() => Promise.resolve('should not run'));
      expect(result).toEqual({ circuitBreakerOpen: true, service: 'timeout-test' });

      Date.now = realDateNow;
    });
  });

  describe('3. Success in CLOSED resets failure count', () => {
    test('resets failure count on success in CLOSED state', async () => {
      const cb = new CircuitBreaker('mixed', {
        failureThreshold: 3,
        successThreshold: 2,
        timeoutMs: 30000,
      });

      await cb.call(() => Promise.reject(new Error('fail'))).catch(() => {});
      expect(cb.failureCount).toBe(1);

      await cb.call(() => Promise.resolve('ok'));
      expect(cb.failureCount).toBe(0);
    });
  });

  describe('4. DB pool health reporting', () => {
    test('health endpoint returns pool stats', async () => {
      const request = require('supertest');
      const app = require('../src/server');
      const res = await request(app).get('/health/db');
      expect(res.status).toBe(200);
      expect(res.body.pool).toBeDefined();
      expect(res.body.pool.total).toBe(5);
      expect(res.body.bulkhead).toBeDefined();
      expect(res.body.circuit_breakers).toBeDefined();
      expect(res.body.circuit_breakers.notification_backend).toBe('CLOSED');
      expect(res.body.circuit_breakers.ai).toBe('CLOSED');
    });
  });

  describe('5. Server root endpoint', () => {
    test('root returns service status', async () => {
      const request = require('supertest');
      const app = require('../src/server');
      const res = await request(app).get('/');
      expect(res.status).toBe(200);
      expect(res.body.service).toBe('bloodconnect-api');
    });
  });

  describe('6. Multiple circuit breaker isolation', () => {
    test('separate breakers do not affect each other', async () => {
      const cb1 = new CircuitBreaker('service-a', { failureThreshold: 2, timeoutMs: 30000 });
      const cb2 = new CircuitBreaker('service-b', { failureThreshold: 2, timeoutMs: 30000 });

      await cb1.call(() => Promise.reject(new Error('fail'))).catch(() => {});
      await cb1.call(() => Promise.reject(new Error('fail'))).catch(() => {});
      expect(cb1.getStateName()).toBe('OPEN');
      expect(cb2.getStateName()).toBe('CLOSED');

      const ok = await cb2.call(() => Promise.resolve('ok'));
      expect(ok).toBe('ok');
    });
  });

  describe('7. Circuit breaker fallback variations', () => {
    test('custom fallback is called instead of default', async () => {
      const cb = new CircuitBreaker('custom-fallback', {
        failureThreshold: 1,
        timeoutMs: 30000,
      });

      await cb.call(() => Promise.reject(new Error('fail'))).catch(() => {});
      const fallback = jest.fn().mockReturnValue({ custom: true, message: 'degraded' });
      const result = await cb.call(() => Promise.resolve('ignored'), fallback);
      expect(fallback).toHaveBeenCalled();
      expect(result).toEqual({ custom: true, message: 'degraded' });
    });

    test('default fallback contains service name', async () => {
      const cb = new CircuitBreaker('my-service', { failureThreshold: 1, timeoutMs: 30000 });
      await cb.call(() => Promise.reject(new Error('fail'))).catch(() => {});
      const result = await cb.call(() => Promise.resolve('should not run'));
      expect(result).toEqual({ circuitBreakerOpen: true, service: 'my-service' });
    });
  });

  describe('8. Multiple concurrent circuit breaker instances', () => {
    test('three independent breakers with different thresholds', async () => {
      const cbA = new CircuitBreaker('svc-a', { failureThreshold: 1, timeoutMs: 30000 });
      const cbB = new CircuitBreaker('svc-b', { failureThreshold: 3, timeoutMs: 30000 });
      const cbC = new CircuitBreaker('svc-c', { failureThreshold: 5, timeoutMs: 30000 });

      for (let i = 0; i < 4; i++) {
        await cbA.call(() => Promise.reject(new Error('fail'))).catch(() => {});
        await cbB.call(() => Promise.reject(new Error('fail'))).catch(() => {});
        await cbC.call(() => Promise.reject(new Error('fail'))).catch(() => {});
      }

      expect(cbA.getStateName()).toBe('OPEN');
      expect(cbB.getStateName()).toBe('OPEN');
      expect(cbC.getStateName()).toBe('CLOSED');

      await cbC.call(() => Promise.reject(new Error('fail'))).catch(() => {});
      expect(cbC.getStateName()).toBe('OPEN');
    });
  });
});
