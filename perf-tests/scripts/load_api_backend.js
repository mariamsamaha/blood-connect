/**
 * BloodConnect API Backend — Performance Test Suite
 * ===================================================
 *
 * Targets ONLY routes that exist in api-backend/src/server.js as of this
 * suite's writing. No endpoint here is invented. Each scenario cites the
 * exact route and the reason it was selected for load testing.
 *
 * This script does NOT assert correctness (no expect()/assert()). It is a
 * pure load generator + latency/throughput collector. Functional behavior
 * is the responsibility of api-backend/tests/*, which is explicitly out of
 * scope for this suite.
 */
'use strict';

const autocannon = require('autocannon');
const fs = require('fs');
const path = require('path');
const { config, assertAuthConfigured } = require('../config/config');

const results = { generatedAt: new Date().toISOString(), target: config.API_BASE_URL, scenarios: [] };

function authHeaders(token) {
  return { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
}

/**
 * Wraps autocannon in a Promise and normalizes the bits of its result object
 * this suite reports on (P50/P75/P90/P95/P99, throughput, error counts).
 */
function run(scenarioName, opts) {
  return new Promise((resolve, reject) => {
    console.log(`\n▶ Running: ${scenarioName}`);
    console.log(`  ${opts.method || 'GET'} ${opts.url}  (connections=${opts.connections ?? config.CONNECTIONS}, duration=${opts.duration ?? config.DURATION_SEC}s)`);
    const instance = autocannon(
      {
        connections: config.CONNECTIONS,
        duration: config.DURATION_SEC,
        ...opts,
      },
      (err, result) => {
        if (err) return reject(err);
        const summary = {
          scenario: scenarioName,
          route: `${opts.method || 'GET'} ${new URL(opts.url).pathname}`,
          connections: opts.connections ?? config.CONNECTIONS,
          durationSec: opts.duration ?? config.DURATION_SEC,
          requests: {
            total: result.requests.total,
            average: result.requests.average,
            p50: result.requests.p50,
            p97_5: result.requests.p97_5,
          },
          latencyMs: {
            average: result.latency.average,
            p50: result.latency.p50,
            p75: result.latency.p75,
            p90: result.latency.p90,
            p97_5: result.latency.p97_5,
            p99: result.latency.p99,
            max: result.latency.max,
          },
          throughput: {
            averageBytesPerSec: result.throughput.average,
          },
          errors: result.errors,
          timeouts: result.timeouts,
          non2xx: (result.statusCodeStats &&
            Object.entries(result.statusCodeStats)
              .filter(([code]) => Number(code) >= 300)
              .reduce((sum, [, v]) => sum + v.count, 0)) || 0,
          statusCodeStats: result.statusCodeStats || {},
        };
        results.scenarios.push(summary);
        printSummary(summary);
        resolve(summary);
      },
    );
    autocannon.track(instance, { renderProgressBar: false });
  });
}

function printSummary(s) {
  console.log(`  ✓ ${s.requests.total} requests | ${s.requests.average.toFixed(1)} req/s avg`);
  console.log(
    `    Latency (ms): p50=${s.latencyMs.p50} p90=${s.latencyMs.p90} p99=${s.latencyMs.p99} max=${s.latencyMs.max}`,
  );
  if (s.errors > 0 || s.timeouts > 0 || s.non2xx > 0) {
    console.log(`    ⚠ errors=${s.errors} timeouts=${s.timeouts} non-2xx=${s.non2xx}`);
  }
}

async function main() {
  assertAuthConfigured();
  fs.mkdirSync(config.REPORT_DIR, { recursive: true });

  console.log('═══════════════════════════════════════════════════════════');
  console.log(' BloodConnect API Backend — Performance Test Suite');
  console.log(' Target:', config.API_BASE_URL);
  console.log('═══════════════════════════════════════════════════════════');

  // ── 1. Unauthenticated health check ──────────────────────────────────
  // Why: GET / is the cheapest possible request (no DB, no auth). It is the
  // baseline every other scenario should be compared against, and it is the
  // endpoint used as the headline "695 RPS" figure in prior benchmarking
  // (see docs/BENCHMARK.md). Re-measuring it here under autocannon, with a
  // consistent connection/duration shape across all scenarios, lets this
  // suite sanity-check that number rather than just repeat it.
  await run('Health check (no DB, no auth)', {
    url: `${config.API_BASE_URL}/`,
    method: 'GET',
  });

  // ── 2. Database-backed health check ──────────────────────────────────
  // Why: GET /health/db runs `SELECT 1` through the *main* connection pool
  // (api-backend/src/db.js, pool.totalCount/idleCount/waitingCount are
  // reported in the response body). This isolates "is the DB round-trip
  // itself the bottleneck" from "is application logic the bottleneck."
  await run('Health check (with DB round-trip)', {
    url: `${config.API_BASE_URL}/health/db`,
    method: 'GET',
  });

  // ── 3. Static OpenAPI spec ────────────────────────────────────────────
  // Why: GET /api/docs.json serves a pre-built object with minimal
  // middleware. This is the theoretical throughput ceiling of the Express
  // app itself (routing + JSON serialization, no DB, no auth, no business
  // logic) — useful as an upper bound when interpreting every other result.
  await run('Static JSON (theoretical ceiling)', {
    url: `${config.API_BASE_URL}/api/docs.json`,
    method: 'GET',
  });

  // ── 4. Authenticated profile read (auth middleware + Redis token cache) ─
  // Why: GET /api/v1/users/me is the single most-called authenticated route
  // in the app (every authenticated screen load triggers profile checks
  // indirectly). It exercises the full auth chain in api-backend/src/auth.js:
  // Bearer extraction → Redis cache lookup (~5ms claimed) → Firebase
  // verifyIdToken() on cache miss (~50-100ms claimed). Running this
  // repeatedly with the SAME token, back-to-back, should make every request
  // after the first a cache hit — this scenario is designed to measure that
  // cached-token cost specifically.
  await run('Authenticated profile read (token cache hot path)', {
    url: `${config.API_BASE_URL}/api/v1/users/me`,
    method: 'GET',
    headers: authHeaders(config.FIREBASE_ID_TOKEN),
  });

  // ── 5. Donor matching (inline ST_Distance query, no GIST-optimized form) ─
  // Why: GET /api/v1/donor/matches (server.js ~line 1259) is the query
  // behind the donor home screen — the single highest-traffic read for the
  // donor role. It computes ST_Distance(...) <= radius inline rather than
  // using ST_DWithin, which is the form PostGIS's planner is documented to
  // use most reliably with a GIST index. This is the single most likely
  // database bottleneck candidate in the whole backend; this scenario exists
  // specifically to surface it under concurrent load.
  if (config.TEST_DONOR_ID) {
    const qs = new URLSearchParams({
      donorId: config.TEST_DONOR_ID,
      compatibleTypesCsv: 'O+,O-,A+,A-,B+,B-,AB+,AB-',
      donorLat: String(config.TEST_HOSPITAL_LAT),
      donorLng: String(config.TEST_HOSPITAL_LNG),
      radiusKm: '120',
    });
    await run('Donor matching (spatial query, donor/matches)', {
      url: `${config.API_BASE_URL}/api/v1/donor/matches?${qs}`,
      method: 'GET',
      headers: authHeaders(config.FIREBASE_ID_TOKEN),
    });
  } else {
    console.log('\n⏭  Skipping donor/matches: PERF_TEST_DONOR_ID not set (see README "Seeding test data").');
  }

  // ── 6. Nearby hospitals (PostGIS proximity, used on the create-request screen) ─
  await run('Nearby hospitals (spatial query, /hospitals)', {
    url: `${config.API_BASE_URL}/api/v1/hospitals?lat=${config.TEST_HOSPITAL_LAT}&lng=${config.TEST_HOSPITAL_LNG}`,
    method: 'GET',
    headers: authHeaders(config.FIREBASE_ID_TOKEN),
  });

  // ── 7. Leaderboard (window function query) ───────────────────────────
  // Why: donor_leaderboard view uses a PostgreSQL window function
  // (RANK() OVER (...) per the thesis's description of §5.2.5). Window
  // functions over the full users table do not benefit from row-level
  // indexes the way a WHERE-clause-filtered query does, so this is a
  // distinct bottleneck class from the spatial queries above.
  await run('Donor leaderboard (window function query)', {
    url: `${config.API_BASE_URL}/api/v1/donor/leaderboard`,
    method: 'GET',
    headers: authHeaders(config.FIREBASE_ID_TOKEN),
  });

  // ── 8. Blood request creation (the heaviest write path in the app) ────
  // Why: POST /api/v1/requests (server.js ~line 894) is, by line count and
  // round-trip count, the single most expensive endpoint in the backend:
  // (1) a hospital lookup SELECT, (2) generate_short_request_id() — a
  // PL/pgSQL stored procedure with its own collision-detection retry loop,
  // (3) a find_nearby_donors() COUNT query, (4) a 4-statement database
  // transaction (INSERT request, UPDATE user, INSERT audit log, INSERT
  // notification), and (5) a fire-and-forget call to notifyNewRequest(),
  // which itself runs a further ST_DWithin query and an HTTP call to the
  // notification backend. This scenario uses a LOW connection count and
  // SHORT duration relative to the read scenarios above, specifically
  // because this is a write path that creates real rows on every iteration
  // — left at the suite's default connection count, it would flood the
  // database with thousands of rows per run.
  if (config.TEST_RECIPIENT_ID && config.TEST_HOSPITAL_ID) {
    await run('Blood request creation (5-roundtrip write path)', {
      url: `${config.API_BASE_URL}/api/v1/requests`,
      method: 'POST',
      headers: authHeaders(config.FIREBASE_ID_TOKEN),
      connections: Math.min(config.CONNECTIONS, 5),
      duration: Math.min(config.DURATION_SEC, 10),
      setupClient: (client) => {
        client.setBody(JSON.stringify({
          requesterId: config.TEST_RECIPIENT_ID,
          bloodType: 'O+',
          unitsNeeded: 1,
          urgencyLevel: 'routine',
          hospitalId: config.TEST_HOSPITAL_ID,
          hospitalLat: config.TEST_HOSPITAL_LAT,
          hospitalLng: config.TEST_HOSPITAL_LNG,
          contactPhone: '+201000000000',
        }));
      },
    });
  } else {
    console.log('\n⏭  Skipping request creation: PERF_TEST_RECIPIENT_ID / PERF_TEST_HOSPITAL_ID not set.');
  }

  // ── 9. SLO endpoint (CPU-bound rolling-window computation) ───────────
  // Why: GET /slo (api-backend/src/slo.js) reads Redis sorted sets and
  // recomputes p95/p99 locally by sorting all members in the current
  // window in process. Earlier single-worker benchmarking already showed
  // this as the slowest GET endpoint (379 RPS vs. 695 RPS for /). This
  // scenario exists to confirm that gap holds under autocannon's load
  // shape and to see whether it widens under sustained concurrency.
  await run('SLO report (CPU-bound percentile computation)', {
    url: `${config.API_BASE_URL}/slo`,
    method: 'GET',
  });

  // ── Write results ──────────────────────────────────────────────────────
  const outPath = path.join(config.REPORT_DIR, 'api_backend_results.json');
  fs.writeFileSync(outPath, JSON.stringify(results, null, 2));
  console.log(`\n✓ API backend results written to ${outPath}`);
}

main().catch((err) => {
  console.error('\n✗ API backend performance suite failed:', err);
  process.exit(1);
});
