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
  connect: jest.fn(),
  quit: jest.fn().mockResolvedValue(),
  get: jest.fn(),
  setex: jest.fn().mockResolvedValue('OK'),
  on: jest.fn().mockReturnThis(),
};
jest.mock('ioredis', () => jest.fn(() => mockRedis));

beforeEach(() => {
  delete process.env.REDIS_URL;
  mockRedis.connect.mockReset();
  mockRedis.quit.mockReset();
  mockRedis.get.mockReset();
  mockRedis.setex.mockReset();
  mockRedis.on.mockReturnThis();
});

afterEach(async () => {
  const redis = require('../src/redis');
  await redis.close();
  jest.resetModules();
});

describe('redis.js', () => {
  describe('init (no REDIS_URL)', () => {
    test('returns null when REDIS_URL is not set', async () => {
      const redis = require('../src/redis');
      const client = await redis.init();
      expect(client).toBeNull();
      expect(redis.isEnabled()).toBe(false);
    });
  });

  describe('init (with REDIS_URL)', () => {
    beforeEach(() => {
      process.env.REDIS_URL = 'redis://localhost:6379';
    });

    test('creates a client and attempts connection', async () => {
      const Redis = require('ioredis');
      const redis = require('../src/redis');
      const client = await redis.init();
      expect(Redis).toHaveBeenCalledWith(process.env.REDIS_URL, expect.objectContaining({
        maxRetriesPerRequest: 3,
        lazyConnect: true,
      }));
    });

    test('isEnabled returns false before connect event fires', async () => {
      const redis = require('../src/redis');
      await redis.init();
      expect(redis.isEnabled()).toBe(false);
    });
  });

  describe('getCachedToken / setCachedToken', () => {
    test('getCachedToken returns null when redis is not enabled', async () => {
      const redis = require('../src/redis');
      const result = await redis.getCachedToken('some-token');
      expect(result).toBeNull();
    });

    test('setCachedToken does nothing when disabled', async () => {
      const redis = require('../src/redis');
      await redis.setCachedToken('token', { uid: 'u1' });
      expect(mockRedis.setex).not.toHaveBeenCalled();
    });
  });

  describe('init connection failure', () => {
    beforeEach(() => {
      process.env.REDIS_URL = 'redis://localhost:6379';
    });

    test('sets enabled false when connect throws', async () => {
      mockRedis.connect.mockRejectedValue(new Error('ECONNREFUSED'));
      const redis = require('../src/redis');
      const client = await redis.init();
      expect(client).toBe(mockRedis);
      expect(redis.isEnabled()).toBe(false);
    });
  });

  describe('init returns existing client', () => {
    beforeEach(() => {
      process.env.REDIS_URL = 'redis://localhost:6379';
    });

    test('second call returns same client without reconnecting', async () => {
      const redis = require('../src/redis');
      const client1 = await redis.init();
      mockRedis.connect.mockReset();
      const client2 = await redis.init();
      expect(client2).toBe(client1);
      expect(mockRedis.connect).not.toHaveBeenCalled();
    });
  });

  describe('event handlers', () => {
    beforeEach(() => {
      process.env.REDIS_URL = 'redis://localhost:6379';
    });

    test('connect event sets enabled to true', async () => {
      mockRedis.on.mockImplementation((event, cb) => {
        if (event === 'connect') cb();
        return mockRedis;
      });
      const redis = require('../src/redis');
      await redis.init();
      expect(redis.isEnabled()).toBe(true);
    });

    test('error event sets enabled to false', async () => {
      let errorCb;
      mockRedis.on.mockImplementation((event, cb) => {
        if (event === 'connect') cb();
        if (event === 'error') errorCb = cb;
        return mockRedis;
      });
      const redis = require('../src/redis');
      await redis.init();
      errorCb(new Error('Redis error'));
      expect(redis.isEnabled()).toBe(false);
    });

    test('close event sets enabled to false', async () => {
      let closeCb;
      mockRedis.on.mockImplementation((event, cb) => {
        if (event === 'connect') cb();
        if (event === 'close') closeCb = cb;
        return mockRedis;
      });
      const redis = require('../src/redis');
      await redis.init();
      closeCb();
      expect(redis.isEnabled()).toBe(false);
    });
  });

  describe('getCachedToken when enabled', () => {
    beforeEach(() => {
      process.env.REDIS_URL = 'redis://localhost:6379';
      mockRedis.on.mockImplementation((event, cb) => {
        if (event === 'connect') cb();
        return mockRedis;
      });
    });

    test('returns parsed JSON when key exists', async () => {
      mockRedis.get.mockResolvedValue(JSON.stringify({ uid: 'u1', role: 'donor' }));
      const redis = require('../src/redis');
      await redis.init();
      const result = await redis.getCachedToken('valid-token');
      expect(result).toEqual({ uid: 'u1', role: 'donor' });
      expect(mockRedis.get).toHaveBeenCalledWith('fb:token:valid-token');
    });

    test('returns null when key does not exist', async () => {
      mockRedis.get.mockResolvedValue(null);
      const redis = require('../src/redis');
      await redis.init();
      const result = await redis.getCachedToken('missing-token');
      expect(result).toBeNull();
    });

    test('returns null when get throws', async () => {
      mockRedis.get.mockRejectedValue(new Error('connection lost'));
      const redis = require('../src/redis');
      await redis.init();
      const result = await redis.getCachedToken('fail-token');
      expect(result).toBeNull();
    });
  });

  describe('setCachedToken when enabled', () => {
    beforeEach(() => {
      process.env.REDIS_URL = 'redis://localhost:6379';
      mockRedis.on.mockImplementation((event, cb) => {
        if (event === 'connect') cb();
        return mockRedis;
      });
    });

    test('calls setex with TTL and serialized data', async () => {
      process.env.TOKEN_CACHE_TTL_SEC = '600';
      const redis = require('../src/redis');
      await redis.init();
      await redis.setCachedToken('my-token', { uid: 'u2' });
      expect(mockRedis.setex).toHaveBeenCalledWith('fb:token:my-token', 600, JSON.stringify({ uid: 'u2' }));
    });

    test('does not throw when setex fails', async () => {
      mockRedis.setex.mockRejectedValue(new Error('write failed'));
      const redis = require('../src/redis');
      await redis.init();
      await expect(redis.setCachedToken('t', { uid: 'u3' })).resolves.not.toThrow();
    });
  });

  describe('close / getClient', () => {
    beforeEach(() => {
      process.env.REDIS_URL = 'redis://localhost:6379';
    });

    test('close calls quit and nullifies client', async () => {
      mockRedis.on.mockImplementation((event, cb) => {
        if (event === 'connect') cb();
        return mockRedis;
      });
      const redis = require('../src/redis');
      await redis.init();
      await redis.close();
      expect(mockRedis.quit).toHaveBeenCalled();
      expect(redis.isEnabled()).toBe(false);
    });

    test('close is a no-op when no client', async () => {
      const redis = require('../src/redis');
      await expect(redis.close()).resolves.not.toThrow();
    });

    test('getClient returns null when not initialized', () => {
      const redis = require('../src/redis');
      expect(redis.getClient()).toBeNull();
    });

    test('getClient returns client when initialized', async () => {
      process.env.REDIS_URL = 'redis://localhost:6379';
      const redis = require('../src/redis');
      await redis.init();
      expect(redis.getClient()).toBe(mockRedis);
    });
  });

  describe('retryStrategy', () => {
    beforeEach(() => {
      process.env.REDIS_URL = 'redis://localhost:6379';
    });

    test('returns null after 3 retries', () => {
      const redis = require('../src/redis');
      redis.init();
      const Redis = require('ioredis');
      const callArgs = Redis.mock.calls[0][1];
      const retryFn = callArgs.retryStrategy;
      expect(retryFn(4)).toBeNull();
    });

    test('returns delay for first retries', () => {
      const redis = require('../src/redis');
      redis.init();
      const Redis = require('ioredis');
      const callArgs = Redis.mock.calls[0][1];
      const retryFn = callArgs.retryStrategy;
      expect(retryFn(1)).toBe(200);
      expect(retryFn(2)).toBe(400);
      expect(retryFn(3)).toBe(600);
    });
  });
});
