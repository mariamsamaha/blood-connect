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

const mockSendEachForMulticast = jest.fn().mockResolvedValue({
  successCount: 2,
  failureCount: 0,
  responses: [],
});

jest.mock('firebase-admin', () => ({
  initializeApp: jest.fn(),
  messaging: () => ({
    sendEachForMulticast: mockSendEachForMulticast,
  }),
}));

const request = require('supertest');

describe('Notification Backend', () => {
  let app;
  const origEnv = { ...process.env };

  beforeAll(() => {
    process.env.INTERNAL_SECRET = 'test-secret';
    app = require('../src/server');
  });

  afterAll(() => {
    process.env = { ...origEnv };
  });

  beforeEach(() => {
    mockSendEachForMulticast.mockClear();
  });

  describe('GET /', () => {
    test('returns 200 with status message', async () => {
      const res = await request(app).get('/');
      expect(res.status).toBe(200);
      expect(res.text).toContain('Notification backend is running');
    });
  });

  describe('POST /sendNewRequest', () => {
    test('returns 401 without secret header', async () => {
      const res = await request(app)
        .post('/sendNewRequest')
        .send({ request: {}, tokens: [] });
      expect(res.status).toBe(401);
      expect(res.body.error).toBe('unauthorized');
    });

    test('returns 401 with wrong secret', async () => {
      const res = await request(app)
        .post('/sendNewRequest')
        .set('x-internal-secret', 'wrong-secret')
        .send({ request: {}, tokens: [] });
      expect(res.status).toBe(401);
    });

    test('returns 400 for invalid payload', async () => {
      const res = await request(app)
        .post('/sendNewRequest')
        .set('x-internal-secret', 'test-secret')
        .send({});
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('invalid_payload');
    });

    test('returns 400 when tokens is not an array', async () => {
      const res = await request(app)
        .post('/sendNewRequest')
        .set('x-internal-secret', 'test-secret')
        .send({ request: {}, tokens: 'not-array' });
      expect(res.status).toBe(400);
    });

    test('returns 200 with sent=0 when tokens array is empty', async () => {
      const res = await request(app)
        .post('/sendNewRequest')
        .set('x-internal-secret', 'test-secret')
        .send({ request: { id: '1', blood_type: 'O+', hospital_name: 'H' }, tokens: [] });
      expect(res.status).toBe(200);
      expect(res.body.sent).toBe(0);
    });

    test('filters out empty tokens', async () => {
      const res = await request(app)
        .post('/sendNewRequest')
        .set('x-internal-secret', 'test-secret')
        .send({
          request: { id: '1', blood_type: 'O+', hospital_name: 'H' },
          tokens: ['valid-token', '', null, 'another-token'],
        });
      expect(res.status).toBe(200);
    });

    test('sends notification and returns counts', async () => {
      const res = await request(app)
        .post('/sendNewRequest')
        .set('x-internal-secret', 'test-secret')
        .send({
          request: {
            id: 'req-1',
            short_id: 'CH-1234',
            blood_type: 'O+',
            units_needed: 2,
            hospital_name: 'Test Hospital',
          },
          tokens: ['token1', 'token2'],
        });
      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('sent');
      expect(res.body).toHaveProperty('failed');
      expect(res.body).toHaveProperty('stale_tokens');
    });
  });

  describe('sendWithRetry', () => {
    test('retries on failure and eventually succeeds', async () => {
      mockSendEachForMulticast
        .mockRejectedValueOnce(new Error('network error'))
        .mockRejectedValueOnce(new Error('network error'))
        .mockResolvedValueOnce({
          successCount: 1,
          failureCount: 0,
          responses: [],
        });

      const res = await request(app)
        .post('/sendNotification')
        .set('x-internal-secret', 'test-secret')
        .send({
          title: 'Test',
          body: 'Test body',
          tokens: ['token1'],
        });

      expect(res.status).toBe(200);
      expect(mockSendEachForMulticast).toHaveBeenCalledTimes(3);
    });
  });
});
