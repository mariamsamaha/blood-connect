const { validateDbConfig } = require('../src/db');

describe('db.js', () => {
  describe('validateDbConfig', () => {
    const origEnv = { ...process.env };

    afterEach(() => {
      process.env = { ...origEnv };
    });

    test('returns ok when DATABASE_URL is set', () => {
      process.env.DATABASE_URL = 'postgres://user:pass@host:5432/db';
      const result = validateDbConfig();
      expect(result.ok).toBe(true);
      expect(result.mode).toBe('DATABASE_URL');
    });

    test('returns ok when all SUPABASE_* vars are set', () => {
      delete process.env.DATABASE_URL;
      process.env.SUPABASE_HOST = 'host.supabase.co';
      process.env.SUPABASE_USERNAME = 'user';
      process.env.SUPABASE_DB_PASSWORD = 'pass';
      const result = validateDbConfig();
      expect(result.ok).toBe(true);
      expect(result.mode).toBe('SUPABASE_*');
    });

    test('returns missing fields when SUPABASE_* vars are incomplete', () => {
      delete process.env.DATABASE_URL;
      delete process.env.SUPABASE_HOST;
      delete process.env.SUPABASE_USERNAME;
      delete process.env.SUPABASE_DB_PASSWORD;
      const result = validateDbConfig();
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
      const result = validateDbConfig();
      expect(result.ok).toBe(false);
      expect(result.missing).toEqual(['SUPABASE_HOST']);
    });
  });
});
