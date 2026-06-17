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

  describe('close / getClient', () => {
    beforeEach(() => {
      process.env.REDIS_URL = 'redis://localhost:6379';
    });

    test('close calls quit and nullifies client', async () => {
      mockRedis.on.mockImplementation((event, cb) => {
        if (event === 'connect') process.nextTick(cb);
        return mockRedis;
      });
      const redis = require('../src/redis');
      await redis.init();
      await redis.close();
      expect(mockRedis.quit).toHaveBeenCalled();
      expect(redis.isEnabled()).toBe(false);
    });

    test('getClient returns null when not initialized', () => {
      const redis = require('../src/redis');
      expect(redis.getClient()).toBeNull();
    });
  });
});
