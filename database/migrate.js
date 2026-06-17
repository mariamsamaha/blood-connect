/**
 * BloodConnect Database Migration Runner
 *
 * Usage:
 *   node database/migrate.js                     # uses DATABASE_URL from env
 *   DATABASE_URL=postgresql://... node database/migrate.js
 *
 * Migrations are tracked in the `_migrations` table.
 * Only unapplied migrations (sorted by filename) are executed.
 * Each migration runs inside its own transaction.
 */
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

const MIGRATIONS_DIR = path.join(__dirname, 'migrations');
const BASE_SCHEMA = path.join(__dirname, 'bloodconnect_schema.sql');
const TRACKING_TABLE = '_migrations';

async function run() {
  const dbUrl = process.env.DATABASE_URL
    || `postgresql://${process.env.SUPABASE_USERNAME}:${process.env.SUPABASE_DB_PASSWORD}@${process.env.SUPABASE_HOST}:${process.env.SUPABASE_PORT || 5432}/${process.env.SUPABASE_DATABASE || 'postgres'}${process.env.SUPABASE_REQUIRE_SSL === 'true' ? '?sslmode=require' : ''}`;

  if (!dbUrl || dbUrl.includes('your_')) {
    console.error('FATAL: No DATABASE_URL configured. Set DATABASE_URL or SUPABASE_* env vars.');
    process.exit(1);
  }

  const pool = new Pool({ connectionString: dbUrl, max: 1 });

  try {
    // Ensure tracking table exists
    await pool.query(`
      CREATE TABLE IF NOT EXISTS ${TRACKING_TABLE} (
        name TEXT PRIMARY KEY,
        applied_at TIMESTAMPTZ DEFAULT NOW(),
        hash TEXT
      )
    `);

    // Get already-applied migrations
    const { rows: applied } = await pool.query(
      `SELECT name FROM ${TRACKING_TABLE} ORDER BY name`
    );
    const appliedSet = new Set(applied.map(r => r.name));

    // Collect and sort migration files
    const files = fs.readdirSync(MIGRATIONS_DIR)
      .filter(f => f.endsWith('.sql'))
      .sort();

    console.log(`Found ${files.length} migration(s), ${appliedSet.size} already applied.`);

    for (const file of files) {
      if (appliedSet.has(file)) {
        console.log(`  SKIP  ${file} (already applied)`);
        continue;
      }

      const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, file), 'utf8');
      const hash = require('crypto').createHash('sha256').update(sql).digest('hex').slice(0, 16);

      console.log(`  APPLY ${file}`);
      await pool.query('BEGIN');
      try {
        await pool.query(sql);
        await pool.query(
          `INSERT INTO ${TRACKING_TABLE} (name, hash) VALUES ($1, $2)`,
          [file, hash]
        );
        await pool.query('COMMIT');
        console.log(`   OK   ${file}`);
      } catch (err) {
        await pool.query('ROLLBACK');
        console.error(`  FAIL  ${file}: ${err.message}`);
        throw err;
      }
    }

    // Apply base schema if tracking table is empty (fresh DB)
    const { rows: count } = await pool.query(`SELECT COUNT(*)::int AS c FROM ${TRACKING_TABLE}`);
    if (count[0].c === 0 && fs.existsSync(BASE_SCHEMA)) {
      console.log('\nNo migrations applied — applying base schema...');
      const sql = fs.readFileSync(BASE_SCHEMA, 'utf8');
      await pool.query('BEGIN');
      try {
        await pool.query(sql);
        // Mark all existing migrations as applied so they're skipped next run
        for (const file of files) {
          await pool.query(
            `INSERT INTO ${TRACKING_TABLE} (name, hash) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
            [file, '']
          );
        }
        await pool.query('COMMIT');
        console.log('Base schema applied successfully.');
      } catch (err) {
        await pool.query('ROLLBACK');
        console.error(`Base schema failed: ${err.message}`);
        throw err;
      }
    }

    console.log('\nAll migrations complete.');
  } finally {
    await pool.end();
  }
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
