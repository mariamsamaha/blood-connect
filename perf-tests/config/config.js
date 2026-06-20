/**
 * Shared configuration for BloodConnect performance tests.
 *
 * Every value here is read from an environment variable with a sane local-dev
 * default. Nothing here invents endpoints — every URL/path corresponds to a
 * route confirmed to exist in api-backend/src/server.js, notification-backend/src/server.js,
 * or ai-service/main.py at the time this suite was written.
 */
'use strict';

require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });

const config = {
  // ── Target services ────────────────────────────────────────────────────
  API_BASE_URL: process.env.PERF_API_BASE_URL || 'http://localhost:8090',
  NOTIFICATION_BASE_URL: process.env.PERF_NOTIFICATION_BASE_URL || 'http://localhost:8080',
  AI_BASE_URL: process.env.PERF_AI_BASE_URL || 'http://localhost:8000',

  // ── Auth ───────────────────────────────────────────────────────────────
  // A real Firebase ID token is REQUIRED for every /api/v1/* route except
  // GET /, GET /health/db, GET /api/docs.json. There is no bypass in
  // api-backend/src/auth.js (requireFirebaseAuth always calls
  // admin.auth().verifyIdToken() on cache miss). See README.md "Obtaining a
  // Firebase ID token" for how to populate this.
  FIREBASE_ID_TOKEN: process.env.PERF_FIREBASE_ID_TOKEN || '',
  // Optional second token for a *different* user, used by tests that need
  // two distinct identities (e.g. donor accept vs. hospital verify).
  FIREBASE_ID_TOKEN_SECONDARY: process.env.PERF_FIREBASE_ID_TOKEN_SECONDARY || '',

  // Internal shared secret used by the API backend to call the notification
  // backend directly (NOTIFICATION_BACKEND_SECRET in api-backend/.env,
  // INTERNAL_SECRET in notification-backend/.env — same value on both sides).
  NOTIFICATION_INTERNAL_SECRET: process.env.PERF_NOTIFICATION_INTERNAL_SECRET || '',

  // ── Known-good seed IDs ────────────────────────────────────────────────
  // These must reference rows that actually exist in the target database.
  // See README.md "Seeding test data" for a script that creates them.
  TEST_DONOR_ID: process.env.PERF_TEST_DONOR_ID || '',
  TEST_RECIPIENT_ID: process.env.PERF_TEST_RECIPIENT_ID || '',
  TEST_HOSPITAL_ID: process.env.PERF_TEST_HOSPITAL_ID || '',
  TEST_HOSPITAL_LAT: parseFloat(process.env.PERF_TEST_HOSPITAL_LAT || '30.0444'), // Cairo
  TEST_HOSPITAL_LNG: parseFloat(process.env.PERF_TEST_HOSPITAL_LNG || '31.2357'),

  // ── Load shape ─────────────────────────────────────────────────────────
  CONNECTIONS: parseInt(process.env.PERF_CONNECTIONS || '20', 10),
  DURATION_SEC: parseInt(process.env.PERF_DURATION_SEC || '20', 10),
  WARMUP_SEC: parseInt(process.env.PERF_WARMUP_SEC || '3', 10),
  PIPELINING: parseInt(process.env.PERF_PIPELINING || '1', 10),

  // Stress test escalation steps (connections), run sequentially.
  STRESS_STEPS: (process.env.PERF_STRESS_STEPS || '10,25,50,100,150')
    .split(',').map((n) => parseInt(n.trim(), 10)),
  STRESS_STEP_DURATION_SEC: parseInt(process.env.PERF_STRESS_STEP_DURATION_SEC || '15', 10),

  // ── Direct database connection (for db_performance.js only) ───────────
  // Same connection a developer would use locally; never the production
  // Supabase superuser credentials in CI.
  DATABASE_URL: process.env.PERF_DATABASE_URL || process.env.DATABASE_URL || '',

  // ── Output ─────────────────────────────────────────────────────────────
  REPORT_DIR: require('path').resolve(__dirname, '../reports'),
};

function assertAuthConfigured() {
  if (!config.FIREBASE_ID_TOKEN) {
    console.error(
      '\n✗ PERF_FIREBASE_ID_TOKEN is not set.\n' +
      '  Every authenticated endpoint under test requires a real Firebase ID token.\n' +
      '  See README.md → "Obtaining a Firebase ID token" before running this script.\n',
    );
    process.exit(1);
  }
}

module.exports = { config, assertAuthConfigured };
