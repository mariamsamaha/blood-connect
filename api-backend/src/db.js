const { Pool, types } = require('pg');
const metrics = require('./metrics');
const logger = require('./logger');

// Force timestamp without time zone (OID 1114) to be parsed as UTC.
// Default pg behavior interprets values in the Node.js local timezone,
// which causes timezone shifting when the server runs in a non-UTC timezone.
types.setTypeParser(types.builtins.TIMESTAMP, (val) => new Date(val + 'Z'));

function supabaseSsl() {
  if ((process.env.SUPABASE_REQUIRE_SSL || 'true').toLowerCase() === 'false') {
    return false;
  }
  // Supabase pooler uses certs that often fail strict Node verification.
  return { rejectUnauthorized: false };
}

function buildPoolConfig() {
  const timeouts = {
    max: 10,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
    statement_timeout: 10_000,
    query_timeout: 12_000,
  };

  if (process.env.DATABASE_URL) {
    return {
      connectionString: process.env.DATABASE_URL,
      ssl: supabaseSsl(),
      ...timeouts,
    };
  }

  return {
    host: process.env.SUPABASE_HOST,
    port: parseInt(process.env.SUPABASE_PORT || '5432', 10),
    database: process.env.SUPABASE_DATABASE || 'postgres',
    user: process.env.SUPABASE_USERNAME,
    password: process.env.SUPABASE_DB_PASSWORD,
    ssl: supabaseSsl(),
    ...timeouts,
  };
}

function validateDbConfig() {
  if (process.env.DATABASE_URL) {
    return { ok: true, mode: 'DATABASE_URL' };
  }

  const missing = [];
  if (!process.env.SUPABASE_HOST) missing.push('SUPABASE_HOST');
  if (!process.env.SUPABASE_USERNAME) missing.push('SUPABASE_USERNAME');
  if (!process.env.SUPABASE_DB_PASSWORD) missing.push('SUPABASE_DB_PASSWORD');

  if (missing.length > 0) {
    return { ok: false, missing };
  }
  return { ok: true, mode: 'SUPABASE_*' };
}

const pool = new Pool(buildPoolConfig());

pool.on('error', (err) => {
  logger.error({ err }, 'Unexpected idle client error from pool');
});

async function query(sql, params = []) {
  const start = Date.now();
  try {
    const result = await pool.query(sql, params);
    metrics.trackDbQuery(sql.split(/\s+/)[0].toUpperCase(), Date.now() - start);
    return result.rows;
  } catch (err) {
    metrics.trackDbQuery('ERROR', Date.now() - start);
    throw err;
  }
}

async function withTransaction(callback) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const q = async (sql, params) => {
      const start = Date.now();
      try {
        const result = await client.query(sql, params);
        metrics.trackDbQuery(sql.split(/\s+/)[0].toUpperCase(), Date.now() - start);
        return result.rows;
      } catch (err) {
        metrics.trackDbQuery('ERROR', Date.now() - start);
        throw err;
      }
    };
    const result = await callback(q);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch (rbErr) {
      logger.warn({ err: rbErr }, 'ROLLBACK failed');
    }
    throw err;
  } finally {
    client.release();
  }
}

async function testConnection() {
  const start = Date.now();
  try {
    const row = await pool.query('SELECT 1 AS ok');
    metrics.trackDbQuery('TEST', Date.now() - start);
    return row.rows[0]?.ok === 1;
  } catch (err) {
    metrics.trackDbQuery('TEST_ERROR', Date.now() - start);
    throw err;
  }
}

module.exports = { pool, query, withTransaction, testConnection, validateDbConfig };
