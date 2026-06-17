jest.mock('firebase-admin', () => ({
  credential: { cert: jest.fn() },
  initializeApp: jest.fn(),
  apps: [],
  auth: jest.fn().mockReturnValue({
    verifyIdToken: jest.fn(),
  }),
}));

jest.mock('../src/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

const mockRedis = {
  isEnabled: jest.fn().mockReturnValue(false),
  getCachedToken: jest.fn(),
  setCachedToken: jest.fn().mockResolvedValue(),
  init: jest.fn().mockResolvedValue(),
};
jest.mock('../src/redis', () => mockRedis);

const express = require('express');
const request = require('supertest');

const admin = require('firebase-admin');
const redis = require('../src/redis');
const { requireFirebaseAuth } = require('../src/auth');

function createApp() {
  const app = express();
  app.get('/test-auth', requireFirebaseAuth, (req, res) => {
    res.json({ uid: req.firebaseUser.uid });
  });
  return app;
}

describe('auth.js — requireFirebaseAuth', () => {
  let app;

  beforeEach(() => {
    jest.clearAllMocks();
    app = createApp();
  });

  test('401 when Authorization header is missing', async () => {
    const res = await request(app).get('/test-auth');
    expect(res.status).toBe(401);
    expect(res.body.error).toBe('missing_token');
  });

  test('401 when header does not start with Bearer', async () => {
    const res = await request(app)
      .get('/test-auth')
      .set('Authorization', 'Basic token');
    expect(res.status).toBe(401);
    expect(res.body.error).toBe('missing_token');
  });

  test('401 for empty Bearer token', async () => {
    const res = await request(app)
      .get('/test-auth')
      .set('Authorization', 'Bearer ');
    expect(res.status).toBe(401);
    expect(res.body.error).toBe('missing_token');
  });

  test('401 when verifyIdToken fails', async () => {
    admin.auth().verifyIdToken.mockRejectedValueOnce(new Error('invalid token'));

    const res = await request(app)
      .get('/test-auth')
      .set('Authorization', 'Bearer bad-token');
    expect(res.status).toBe(401);
    expect(res.body.error).toBe('invalid_token');
  });

  test('200 and sets firebaseUser on valid token', async () => {
    admin.auth().verifyIdToken.mockResolvedValueOnce({ uid: 'test-uid', email: 'test@test.com' });

    const res = await request(app)
      .get('/test-auth')
      .set('Authorization', 'Bearer valid-token');
    expect(res.status).toBe(200);
    expect(res.body.uid).toBe('test-uid');
  });

  test('caches verified token in Redis when Redis is enabled', async () => {
    redis.isEnabled.mockReturnValue(true);
    const mockUser = { uid: 'cached-uid' };
    admin.auth().verifyIdToken.mockResolvedValueOnce(mockUser);

    await request(app)
      .get('/test-auth')
      .set('Authorization', 'Bearer new-token');

    expect(redis.setCachedToken).toHaveBeenCalledWith('new-token', mockUser);
  });

  test('returns cached user from Redis without calling verifyIdToken', async () => {
    redis.isEnabled.mockReturnValue(true);
    redis.getCachedToken.mockResolvedValueOnce({ uid: 'cached-uid' });

    const res = await request(app)
      .get('/test-auth')
      .set('Authorization', 'Bearer cached-token');
    expect(res.status).toBe(200);
    expect(res.body.uid).toBe('cached-uid');
    expect(admin.auth().verifyIdToken).not.toHaveBeenCalled();
  });

  test('falls through to Firebase when Redis cache misses', async () => {
    redis.isEnabled.mockReturnValue(true);
    redis.getCachedToken.mockResolvedValueOnce(null);
    admin.auth().verifyIdToken.mockResolvedValueOnce({ uid: 'fresh-uid' });

    const res = await request(app)
      .get('/test-auth')
      .set('Authorization', 'Bearer fresh-token');
    expect(res.status).toBe(200);
    expect(res.body.uid).toBe('fresh-uid');
  });

  test('handles Redis getCachedToken error gracefully', async () => {
    redis.isEnabled.mockReturnValue(true);
    redis.getCachedToken.mockRejectedValueOnce(new Error('redis down'));
    admin.auth().verifyIdToken.mockResolvedValueOnce({ uid: 'recovered-uid' });

    const res = await request(app)
      .get('/test-auth')
      .set('Authorization', 'Bearer recovery-token');
    expect(res.status).toBe(200);
    expect(res.body.uid).toBe('recovered-uid');
  });
});
