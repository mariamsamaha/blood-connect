const { serverError, isDev } = require('../src/errors');

describe('errors.js', () => {
  describe('isDev', () => {
    const origEnv = process.env.NODE_ENV;

    afterEach(() => {
      process.env.NODE_ENV = origEnv;
    });

    test('returns true when NODE_ENV is not production', () => {
      delete process.env.NODE_ENV;
      expect(isDev()).toBe(true);
    });

    test('returns false when NODE_ENV is production', () => {
      process.env.NODE_ENV = 'production';
      expect(isDev()).toBe(false);
    });
  });

  describe('serverError', () => {
    test('returns 500 JSON with error and detail in dev', () => {
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
      };
      serverError(res, new Error('test error'), 'GET /test');
      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: 'internal_error',
          detail: 'test error',
          route: 'GET /test',
        })
      );
    });

    test('returns 500 JSON without detail in production', () => {
      const origEnv = process.env.NODE_ENV;
      process.env.NODE_ENV = 'production';
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
      };
      serverError(res, new Error('test error'), 'GET /test');
      expect(res.json).toHaveBeenCalledWith({
        error: 'internal_error',
      });
      process.env.NODE_ENV = origEnv;
    });
  });
});
