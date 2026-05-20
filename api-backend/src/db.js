const { Pool } = require('pg');

function supabaseSsl() {
  if ((process.env.SUPABASE_REQUIRE_SSL || 'true').toLowerCase() === 'false') {
    return false;
  }
  // Supabase pooler uses certs that often fail strict Node verification.
  return { rejectUnauthorized: false };
}

function buildPoolConfig() {
  if (process.env.DATABASE_URL) {
    return {
      connectionString: process.env.DATABASE_URL,
      ssl: supabaseSsl(),
      max: 10,
    };
  }

  return {
    host: process.env.SUPABASE_HOST,
    port: parseInt(process.env.SUPABASE_PORT || '5432', 10),
    database: process.env.SUPABASE_DATABASE || 'postgres',
    user: process.env.SUPABASE_USERNAME,
    password: process.env.SUPABASE_DB_PASSWORD,
    ssl: supabaseSsl(),
    max: 10,
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

async function query(sql, params = []) {
  const result = await pool.query(sql, params);
  return result.rows;
}

async function testConnection() {
  const row = await pool.query('SELECT 1 AS ok');
  return row.rows[0]?.ok === 1;
}

module.exports = { pool, query, testConnection, validateDbConfig };
