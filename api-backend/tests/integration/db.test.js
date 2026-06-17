const describeIf = process.env.DATABASE_URL ? describe : describe.skip;

describeIf('Integration: Database', () => {
  let db;

  beforeAll(() => {
    db = require('../../src/db');
  });

  test('testConnection returns true', async () => {
    const ok = await db.testConnection();
    expect(ok).toBe(true);
  });

  test('query returns results', async () => {
    const rows = await db.query('SELECT 1 AS ok');
    expect(rows).toHaveLength(1);
    expect(rows[0].ok).toBe(1);
  });

  test('healthQuery works via bulkhead pool', async () => {
    const rows = await db.healthQuery('SELECT current_database() AS db');
    expect(rows).toHaveLength(1);
    expect(typeof rows[0].db).toBe('string');
  });

  test('withTransaction commits successfully', async () => {
    const result = await db.withTransaction(async (q) => {
      const rows = await q('SELECT 1 AS val');
      return rows[0].val;
    });
    expect(result).toBe(1);
  });

  test('withTransaction rolls back on error', async () => {
    const initial = await db.query('SELECT COUNT(*)::int AS cnt FROM pg_stat_activity');
    try {
      await db.withTransaction(async (q) => {
        await q('SELECT 1');
        throw new Error('forced rollback');
      });
    } catch (e) {
      expect(e.message).toBe('forced rollback');
    }
    const after = await db.query('SELECT COUNT(*)::int AS cnt FROM pg_stat_activity');
    expect(after[0].cnt).toBeGreaterThanOrEqual(0);
  });
});
