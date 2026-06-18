jest.mock('pg', () => {
  return {
    Pool: jest.fn(() => ({
      query: jest.fn(),
      connect: jest.fn(),
      on: jest.fn(),
      totalCount: 0,
      idleCount: 0,
      waitingCount: 0,
    })),
    types: {
      builtins: { TIMESTAMP: 1114 },
      setTypeParser: jest.fn(),
    },
  };
});

const mockMetrics = { trackDbQuery: jest.fn() };
jest.mock('../src/metrics', () => mockMetrics);

jest.mock('../src/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

const db = require('../src/db');
const { Pool } = require('pg');

describe('db.js', () => {
  let mainPool, bulkheadPool;

  beforeAll(() => {
    mainPool = Pool.mock.results[0].value;
    bulkheadPool = Pool.mock.results[1].value;
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('pool SSL config', () => {
    const origEnv = { ...process.env };

    afterEach(() => {
      jest.resetModules();
      process.env = { ...origEnv };
    });

    function loadPoolConfigs(env) {
      jest.resetModules();
      process.env = { ...origEnv, ...env };
      const pg = require('pg');
      pg.Pool.mockClear();
      require('../src/db');
      return pg.Pool.mock.calls.map(([config]) => config);
    }

    test('does not force SSL for local DATABASE_URL connections', () => {
      const configs = loadPoolConfigs({
        DATABASE_URL: 'postgres://postgres:test@localhost:5432/test',
      });

      expect(configs[0].ssl).toBe(false);
      expect(configs[1].ssl).toBe(false);
    });

    test('does not force SSL when DATABASE_URL disables sslmode', () => {
      const configs = loadPoolConfigs({
        DATABASE_URL: 'postgres://postgres:test@db.example.com:5432/test?sslmode=disable',
      });

      expect(configs[0].ssl).toBe(false);
      expect(configs[1].ssl).toBe(false);
    });

    test('keeps SSL enabled by default for remote DATABASE_URL connections', () => {
      const configs = loadPoolConfigs({
        DATABASE_URL: 'postgres://postgres:test@db.example.com:5432/test',
      });

      expect(configs[0].ssl).toEqual({ rejectUnauthorized: false });
      expect(configs[1].ssl).toEqual({ rejectUnauthorized: false });
    });
  });

  describe('validateDbConfig', () => {
    const origEnv = { ...process.env };

    afterEach(() => {
      process.env = { ...origEnv };
    });

    test('returns ok when DATABASE_URL is set', () => {
      process.env.DATABASE_URL = 'postgres://user:pass@host:5432/db';
      const result = db.validateDbConfig();
      expect(result.ok).toBe(true);
      expect(result.mode).toBe('DATABASE_URL');
    });

    test('returns ok when all SUPABASE_* vars are set', () => {
      delete process.env.DATABASE_URL;
      process.env.SUPABASE_HOST = 'host.supabase.co';
      process.env.SUPABASE_USERNAME = 'user';
      process.env.SUPABASE_DB_PASSWORD = 'pass';
      const result = db.validateDbConfig();
      expect(result.ok).toBe(true);
      expect(result.mode).toBe('SUPABASE_*');
    });

    test('returns missing fields when SUPABASE_* vars are incomplete', () => {
      delete process.env.DATABASE_URL;
      delete process.env.SUPABASE_HOST;
      delete process.env.SUPABASE_USERNAME;
      delete process.env.SUPABASE_DB_PASSWORD;
      const result = db.validateDbConfig();
      expect(result.ok).toBe(false);
      expect(result.missing).toContain('SUPABASE_HOST');
      expect(result.missing).toContain('SUPABASE_USERNAME');
      expect(result.missing).toContain('SUPABASE_DB_PASSWORD');
    });

    test('returns only actually missing fields', () => {
      delete process.env.DATABASE_URL;
      delete process.env.SUPABASE_HOST;
      process.env.SUPABASE_USERNAME = 'user';
      process.env.SUPABASE_DB_PASSWORD = 'pass';
      const result = db.validateDbConfig();
      expect(result.ok).toBe(false);
      expect(result.missing).toEqual(['SUPABASE_HOST']);
    });
  });

  describe('query', () => {
    test('returns rows and tracks metric on success', async () => {
      mainPool.query.mockResolvedValue({ rows: [{ id: 1, name: 'test' }] });

      const result = await db.query('SELECT * FROM users WHERE id = $1', [1]);

      expect(result).toEqual([{ id: 1, name: 'test' }]);
      expect(mainPool.query).toHaveBeenCalledWith('SELECT * FROM users WHERE id = $1', [1]);
      expect(mockMetrics.trackDbQuery).toHaveBeenCalledWith('SELECT', expect.any(Number));
    });

    test('throws and tracks ERROR metric on failure', async () => {
      mainPool.query.mockRejectedValue(new Error('connection failed'));

      await expect(db.query('SELECT 1')).rejects.toThrow('connection failed');
      expect(mockMetrics.trackDbQuery).toHaveBeenCalledWith('ERROR', expect.any(Number));
    });
  });

  describe('withTransaction', () => {
    let mockClient;

    beforeEach(() => {
      mockClient = { query: jest.fn(), release: jest.fn() };
      mainPool.connect.mockResolvedValue(mockClient);
    });

    test('calls callback with query function and commits', async () => {
      const callback = jest.fn().mockResolvedValue('result');
      mockClient.query.mockResolvedValue({ rows: [] });

      const result = await db.withTransaction(callback);

      expect(result).toBe('result');
      expect(mainPool.connect).toHaveBeenCalledTimes(1);
      expect(mockClient.query).toHaveBeenCalledWith('BEGIN');
      expect(callback).toHaveBeenCalledTimes(1);
      expect(mockClient.query).toHaveBeenCalledWith('COMMIT');
      expect(mockClient.release).toHaveBeenCalledTimes(1);
    });

    test('rolls back on callback error and releases client', async () => {
      const callback = jest.fn().mockRejectedValue(new Error('tx failed'));

      await expect(db.withTransaction(callback)).rejects.toThrow('tx failed');

      expect(mockClient.query).toHaveBeenCalledWith('BEGIN');
      expect(mockClient.query).toHaveBeenCalledWith('ROLLBACK');
      expect(mockClient.release).toHaveBeenCalledTimes(1);
    });

    test('tracks metrics on callback inner queries', async () => {
      mockClient.query.mockResolvedValue({ rows: [{ count: 1 }] });
      const callback = async (q) => {
        await q('UPDATE users SET name = $1', ['new']);
        return 'done';
      };

      await db.withTransaction(callback);

      expect(mockMetrics.trackDbQuery).toHaveBeenCalledWith('UPDATE', expect.any(Number));
    });
  });

  describe('testConnection', () => {
    test('returns true when SELECT 1 returns ok', async () => {
      mainPool.query.mockResolvedValue({ rows: [{ ok: 1 }] });

      const result = await db.testConnection();

      expect(result).toBe(true);
      expect(mainPool.query).toHaveBeenCalledWith('SELECT 1 AS ok');
      expect(mockMetrics.trackDbQuery).toHaveBeenCalledWith('TEST', expect.any(Number));
    });

    test('returns false when SELECT 1 returns unexpected value', async () => {
      mainPool.query.mockResolvedValue({ rows: [{ ok: 0 }] });

      const result = await db.testConnection();

      expect(result).toBe(false);
    });

    test('throws on connection error', async () => {
      mainPool.query.mockRejectedValue(new Error('timeout'));

      await expect(db.testConnection()).rejects.toThrow('timeout');
      expect(mockMetrics.trackDbQuery).toHaveBeenCalledWith('TEST_ERROR', expect.any(Number));
    });
  });

  describe('healthQuery', () => {
    test('returns rows from bulkhead pool and tracks HEALTH metric', async () => {
      bulkheadPool.query.mockResolvedValue({ rows: [{ ok: 1 }] });

      const result = await db.healthQuery('SELECT 1 AS ok');

      expect(result).toEqual([{ ok: 1 }]);
      expect(bulkheadPool.query).toHaveBeenCalledWith('SELECT 1 AS ok', []);
      expect(mockMetrics.trackDbQuery).toHaveBeenCalledWith('HEALTH', expect.any(Number));
    });

    test('throws and tracks HEALTH_ERROR metric on failure', async () => {
      bulkheadPool.query.mockRejectedValue(new Error('bulkhead full'));

      await expect(db.healthQuery('SELECT 1')).rejects.toThrow('bulkhead full');
      expect(mockMetrics.trackDbQuery).toHaveBeenCalledWith('HEALTH_ERROR', expect.any(Number));
    });
  });
});
