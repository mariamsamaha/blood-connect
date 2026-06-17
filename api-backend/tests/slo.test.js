const mockLogger = {
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
  debug: jest.fn(),
  child: jest.fn(() => mockLogger),
  level: 'silent',
};
jest.mock('../src/logger', () => mockLogger);

const mockRedis = {
  isEnabled: jest.fn().mockReturnValue(false),
  getClient: jest.fn().mockReturnValue(null),
  init: jest.fn(),
  close: jest.fn(),
};
jest.mock('../src/redis', () => mockRedis);

function freshSlo() {
  jest.resetModules();
  return require('../src/slo');
}

describe('slo.js', () => {
  describe('recordRequest (in-memory fallback)', () => {
    test('records a successful request and no violations', async () => {
      const slo = freshSlo();
      await slo.recordRequest(200, 50);
      const violations = await slo.checkSLOViolations();
      expect(violations).toHaveLength(0);
    });

    test('records an error request triggers availability violation', async () => {
      const slo = freshSlo();
      await slo.recordRequest(200, 10);
      await slo.recordRequest(500, 100);
      const violations = await slo.checkSLOViolations();
      const availViolations = violations.filter(v => v.message.includes('availability'));
      expect(availViolations.length).toBeGreaterThan(0);
    });
  });

  describe('recordRequest with Redis enabled', () => {
    beforeEach(() => {
      mockRedis.isEnabled.mockReturnValue(true);
      mockRedis.getClient.mockReturnValue({
        pipeline: jest.fn(() => ({
          zadd: jest.fn().mockReturnThis(),
          zremrangebyscore: jest.fn().mockReturnThis(),
          expire: jest.fn().mockReturnThis(),
          exec: jest.fn().mockResolvedValue([]),
        })),
      });
    });

    afterEach(() => {
      mockRedis.isEnabled.mockReturnValue(false);
      mockRedis.getClient.mockReturnValue(null);
    });

    test('records request via Redis pipeline when enabled', async () => {
      const slo = freshSlo();
      await slo.recordRequest(200, 30);
      expect(mockRedis.getClient).toHaveBeenCalled();
    });

    test('falls back to in-memory when Redis pipeline fails', async () => {
      mockRedis.getClient.mockReturnValue({
        pipeline: jest.fn(() => { throw new Error('connection lost'); }),
      });
      const slo = freshSlo();
      await slo.recordRequest(200, 30);
      const violations = await slo.checkSLOViolations();
      expect(violations).toHaveLength(0);
    });
  });

  describe('checkSLOViolations', () => {
    test('returns no violations when all requests succeed', async () => {
      const slo = freshSlo();
      await slo.recordRequest(200, 50);
      const violations = await slo.checkSLOViolations();
      expect(violations).toHaveLength(0);
    });

    test('detects availability violation with mostly errors', async () => {
      const slo = freshSlo();
      for (let i = 0; i < 10; i++) {
        await slo.recordRequest(500, 50);
      }
      const violations = await slo.checkSLOViolations();
      expect(violations.length).toBeGreaterThan(0);
      expect(violations[0].severity).toBe('P1');
      expect(violations[0].message).toContain('availability');
    });

    test('detects p95 latency violation', async () => {
      const slo = freshSlo();
      for (let i = 0; i < 5; i++) {
        await slo.recordRequest(200, 3000);
      }
      const violations = await slo.checkSLOViolations();
      const latencyViolations = violations.filter(v => v.message.includes('latency'));
      expect(latencyViolations.length).toBeGreaterThan(0);
    });

    test('detects error rate violation', async () => {
      const slo = freshSlo();
      for (let i = 0; i < 8; i++) {
        await slo.recordRequest(200, 10);
      }
      for (let i = 0; i < 2; i++) {
        await slo.recordRequest(500, 50);
      }
      const violations = await slo.checkSLOViolations();
      const rateViolations = violations.filter(v => v.message.includes('error rate'));
      expect(rateViolations.length).toBeGreaterThan(0);
    });
  });

  describe('sloReportHandler', () => {
    test('returns SLO report JSON with in-memory backend', async () => {
      const slo = freshSlo();
      await slo.recordRequest(200, 30);
      const res = {
        json: jest.fn(),
        status: jest.fn().mockReturnThis(),
      };
      await slo.sloReportHandler(null, res);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          targets: expect.any(Object),
          windows: expect.objectContaining({
            hourly: expect.any(Object),
            daily: expect.any(Object),
          }),
          backend: 'in-memory-fallback',
        }),
      );
    });

    test('returns SLO report with zero requests', async () => {
      const slo = freshSlo();
      const res = {
        json: jest.fn(),
        status: jest.fn().mockReturnThis(),
      };
      await slo.sloReportHandler(null, res);
      const callArg = res.json.mock.calls[0][0];
      expect(callArg.windows.hourly.total).toBe(0);
      expect(callArg.windows.hourly.availability).toBe(100);
    });

    test('handles Redis-enabled backend in report', async () => {
      mockRedis.isEnabled.mockReturnValue(true);
      mockRedis.getClient.mockReturnValue({
        pipeline: jest.fn(() => ({
          zadd: jest.fn().mockReturnThis(),
          zremrangebyscore: jest.fn().mockReturnThis(),
          expire: jest.fn().mockReturnThis(),
          exec: jest.fn().mockResolvedValue([]),
        })),
        zcard: jest.fn().mockResolvedValue(5),
        zrange: jest.fn().mockResolvedValue([]),
      });
      const slo = freshSlo();
      const res = {
        json: jest.fn(),
        status: jest.fn().mockReturnThis(),
      };
      await slo.sloReportHandler(null, res);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ backend: 'redis' }),
      );
    });
  });
});
