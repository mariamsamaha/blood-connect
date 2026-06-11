/**
 * BloodConnect Bottleneck Isolation Benchmark
 *
 * Tests with DISABLE_RATE_LIMIT=true to identify the bottleneck:
 * Firebase token verification or PostGIS query.
 *
 * Measures:
 * - Unauthenticated endpoints (no Firebase overhead)
 * - Authenticated endpoints (with Firebase verifyIdToken)
 * - With and without rate limiting enabled
 *
 * Usage:
 *   # With rate limiting (DISABLE_RATE_LIMIT=false — default)
 *   node load-tests/benchmark-bottleneck.js
 *
 *   # Without rate limiting
 *   DISABLE_RATE_LIMIT=true node load-tests/benchmark-bottleneck.js
 *
 *   # With valid Firebase token (for real auth measurements)
 *   FIREBASE_TOKEN="<token>" node load-tests/benchmark-bottleneck.js
 */

const http = require('http');

const BASE_URL = process.env.API_BASE_URL || 'http://localhost:8090';
const FIREBASE_TOKEN = process.env.FIREBASE_TOKEN || '';
const ITERATIONS = parseInt(process.env.ITERATIONS || '5', 10);
const CONCURRENCY = parseInt(process.env.CONCURRENCY || '10', 10);
const MEASUREMENT_SEC = parseInt(process.env.MEASUREMENT_SEC || '5', 10);

const urlParts = new URL(BASE_URL);
const DISABLE_RATE_LIMIT = process.env.DISABLE_RATE_LIMIT === 'true';

function httpRequest(method, path, body) {
  return new Promise((resolve, reject) => {
    const headers = { 'Content-Type': 'application/json' };
    if (FIREBASE_TOKEN) {
      headers.Authorization = `Bearer ${FIREBASE_TOKEN}`;
    }
    const bodyStr = body ? JSON.stringify(body) : undefined;
    const options = {
      hostname: urlParts.hostname,
      port: urlParts.port || 80,
      path,
      method,
      headers,
      timeout: 10000,
    };
    if (bodyStr) {
      options.headers['Content-Length'] = Buffer.byteLength(bodyStr);
    }
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => resolve({ status: res.statusCode, body: data }));
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
    if (bodyStr) req.write(bodyStr);
    req.end();
  });
}

async function runLoad(durationMs, endpoint, method, body) {
  const results = [];
  const errors = [];
  let running = true;

  async function worker() {
    while (running) {
      const start = Date.now();
      try {
        const res = await httpRequest(method, endpoint, body);
        results.push({ status: res.status, duration: Date.now() - start });
      } catch {
        errors.push(Date.now());
      }
    }
  }

  const pool = Array.from({ length: CONCURRENCY }, () => worker());
  await new Promise((r) => setTimeout(r, durationMs));
  running = false;
  await Promise.all(pool);

  return { results, errors };
}

async function benchmarkEndpoint(options) {
  const { name, endpoint, method = 'GET', body, durationMs = MEASUREMENT_SEC * 1000 } = options;

  // Warmup
  await runLoad(1000, endpoint, method, body);

  // Measured
  const startTime = Date.now();
  const { results, errors } = await runLoad(durationMs, endpoint, method, body);
  const totalTime = (Date.now() - startTime) / 1000;

  const totalReqs = results.length + errors.length;
  const rps = totalTime > 0 ? totalReqs / totalTime : 0;
  const durations = results.map(r => r.duration).sort((a, b) => a - b);
  const p50 = durations[Math.floor(durations.length * 0.5)] || 0;
  const p95 = durations[Math.floor(durations.length * 0.95)] || 0;
  const p99 = durations[Math.floor(durations.length * 0.99)] || 0;
  const avg = durations.length > 0 ? durations.reduce((a, b) => a + b, 0) / durations.length : 0;

  return { name, endpoint, rps: rps.toFixed(1), avg: avg.toFixed(1), p50, p95, p99, total: totalReqs, errors: errors.length, results: results.length };
}

async function runAll() {
  const mode = DISABLE_RATE_LIMIT ? 'WITHOUT rate limiting' : 'WITH rate limiting';
  const authMode = FIREBASE_TOKEN ? 'WITH valid token' : 'WITHOUT valid token (expect 401)';
  console.log(`\nBloodConnect Bottleneck Isolation Benchmark`);
  console.log(`Base URL: ${BASE_URL}`);
  console.log(`Mode: ${mode}`);
  console.log(`Auth: ${authMode}`);
  console.log(`Concurrency: ${CONCURRENCY}, Measurement: ${MEASUREMENT_SEC}s`);
  console.log('─'.repeat(70));

  // Endpoints to test — ordered from least to most overhead
  const endpoints = [
    { name: 'Unauthenticated — Static JSON', endpoint: '/api/docs.json', method: 'GET' },
    { name: 'Unauthenticated — Health', endpoint: '/', method: 'GET' },
    { name: 'Auth — Users Me', endpoint: '/api/v1/users/me', method: 'GET' },
    { name: 'Auth — Hospitals', endpoint: '/api/v1/hospitals', method: 'GET' },
    { name: 'Auth — Donor Matches', endpoint: '/api/v1/donor/matches?donorId=test&compatibleTypesCsv=O%2B&donorLat=30&donorLng=31&radiusKm=120', method: 'GET' },
    { name: 'Auth — AI Eligibility', endpoint: '/api/v1/ai/eligibility', method: 'POST', body: { donorId: 'test', bloodType: 'O+' } },
  ];

  const all = [];
  for (const ep of endpoints) {
    const result = await benchmarkEndpoint(ep);
    all.push(result);
    const status = `${result.total} req`;
    const errNote = result.errors > 0 ? `  err:${result.errors}` : '';
    console.log(
      `[${result.name.padEnd(35)}]  RPS:${result.rps.padStart(7)}` +
      `  p50:${String(result.p50).padStart(5)}ms  p95:${String(result.p95).padStart(5)}ms  p99:${String(result.p99).padStart(5)}ms` +
      `  ${status}${errNote}`
    );
  }

  console.log('─'.repeat(70));

  // Analysis
  const authEndpoints = all.filter(e => e.name.startsWith('Auth'));
  const unauthEndpoints = all.filter(e => e.name.startsWith('Unauthenticated'));

  console.log('\n── Bottleneck Analysis ──');
  if (unauthEndpoints.length > 0) {
    const unauthAvgRps = unauthEndpoints.reduce((s, e) => s + parseFloat(e.rps), 0) / unauthEndpoints.length;
    console.log(`  Unauthenticated avg RPS: ${unauthAvgRps.toFixed(1)}`);
  }
  if (authEndpoints.length > 0) {
    const authAvgRps = authEndpoints.reduce((s, e) => s + parseFloat(e.rps), 0) / authEndpoints.length;
    console.log(`  Authenticated avg RPS:   ${authAvgRps.toFixed(1)}`);
    console.log(`  Auth overhead: ~${(authAvgRps > 0 ? ((1 - authAvgRps / Math.max(...unauthEndpoints.map(e => parseFloat(e.rps)))) * 100) : 0).toFixed(0)}% RPS reduction`);
  }
  console.log(`  Rate limiting: ${DISABLE_RATE_LIMIT ? 'DISABLED' : 'ENABLED (60 req/user/min)'}`);
  console.log('─'.repeat(70));
  console.log('BENCHMARK COMPLETE\n');
}

runAll().catch(console.error);
