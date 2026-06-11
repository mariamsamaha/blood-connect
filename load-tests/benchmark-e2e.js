/**
 * BloodConnect End-to-End Flow Benchmark
 *
 * Measures real user flow latency:
 *   POST /requests → GET /donor/matches → POST /donor/responses/accept → POST /hospital/verify
 *
 * Records p50/p95/p99 for each step and the total flow.
 *
 * Usage:
 *   FIREBASE_TOKEN="<token>" node load-tests/benchmark-e2e.js
 *   API_BASE_URL=http://localhost:8090 FIREBASE_TOKEN="<token>" node load-tests/benchmark-e2e.js
 *   SKIP_REQUESTS=3 SAMPLE_SIZE=10 node load-tests/benchmark-e2e.js
 */

const http = require('http');

const BASE_URL = process.env.API_BASE_URL || 'http://localhost:8090';
const FIREBASE_TOKEN = process.env.FIREBASE_TOKEN || '';
const SAMPLE_SIZE = parseInt(process.env.SAMPLE_SIZE || '20', 10);
const SKIP_REQUESTS = parseInt(process.env.SKIP_REQUESTS || '3', 10);
const CONCURRENCY = parseInt(process.env.CONCURRENCY || '5', 10);
const TIMEOUT = 15000;

const urlParts = new URL(BASE_URL);
const AUTH_HEADERS = FIREBASE_TOKEN
  ? { Authorization: `Bearer ${FIREBASE_TOKEN}`, 'Content-Type': 'application/json' }
  : { 'Content-Type': 'application/json' };

// Sample data for creating requests
const TEST_REQUEST = {
  requesterId: '00000000-0000-0000-0000-000000000001',
  bloodType: 'O+',
  unitsNeeded: 2,
  urgencyLevel: 'routine',
  hospitalId: '00000000-0000-0000-0000-000000000002',
  hospitalLat: 30.0444,
  hospitalLng: 31.2357,
};
const TEST_DONOR_ID = '00000000-0000-0000-0000-000000000003';

function httpRequest(method, path, body) {
  return new Promise((resolve, reject) => {
    const bodyStr = body ? JSON.stringify(body) : undefined;
    const options = {
      hostname: urlParts.hostname,
      port: urlParts.port || 80,
      path,
      method,
      headers: { ...AUTH_HEADERS },
      timeout: TIMEOUT,
    };
    if (bodyStr) {
      options.headers['Content-Length'] = Buffer.byteLength(bodyStr);
    }
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        resolve({ status: res.statusCode, body: data, headers: res.headers });
      });
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
    if (bodyStr) req.write(bodyStr);
    req.end();
  });
}

async function measureSingleFlow() {
  const steps = {};
  const flowStart = Date.now();

  // Step 1: POST /requests
  const t1 = Date.now();
  const createRes = await httpRequest('POST', '/api/v1/requests', TEST_REQUEST);
  steps['POST /requests'] = Date.now() - t1;
  if (createRes.status >= 400) {
    return { error: `create_request: ${createRes.status} ${createRes.body}`, steps, duration: Date.now() - flowStart };
  }
  let requestId;
  try { requestId = JSON.parse(createRes.body).id; } catch { requestId = null; }
  if (!requestId) {
    return { error: `no_request_id: ${createRes.body}`, steps, duration: Date.now() - flowStart };
  }

  // Step 2: GET /donor/matches
  const t2 = Date.now();
  const matchPath = `/api/v1/donor/matches?donorId=${TEST_DONOR_ID}&compatibleTypesCsv=O%2B&donorLat=30.0444&donorLng=31.2357&radiusKm=120`;
  const matchRes = await httpRequest('GET', matchPath);
  steps['GET /donor/matches'] = Date.now() - t2;

  // Step 3: POST /donor/responses/accept
  const t3 = Date.now();
  const acceptRes = await httpRequest('POST', '/api/v1/donor/responses/accept', {
    requestId,
    donorId: TEST_DONOR_ID,
    donorLat: 30.05,
    donorLng: 31.24,
  });
  steps['POST /donor/responses/accept'] = Date.now() - t3;

  // Step 4: POST /hospital/verify
  const t4 = Date.now();
  const verifyRes = await httpRequest('POST', '/api/v1/hospital/verify', {
    hospitalUserId: '00000000-0000-0000-0000-000000000002',
    requestId,
    staffName: 'Benchmark Staff',
  });
  steps['POST /hospital/verify'] = Date.now() - t4;

  return { steps, duration: Date.now() - flowStart };
}

function computePercentiles(sorted, pct) {
  if (sorted.length === 0) return 0;
  const idx = Math.floor(sorted.length * pct);
  return sorted[Math.min(idx, sorted.length - 1)];
}

async function runBenchmark() {
  console.log(`\nBloodConnect E2E Flow Benchmark`);
  console.log(`Base URL: ${BASE_URL}`);
  console.log(`Samples: ${SAMPLE_SIZE}, Skip first: ${SKIP_REQUESTS}, Concurrency: ${CONCURRENCY}`);
  console.log(`Auth: ${FIREBASE_TOKEN ? 'Bearer <token>' : 'NONE (will get 401)'}`);
  console.log('─'.repeat(78));

  // Phase 1: Warmup (skip first N)
  console.log(`\nWarming up (${SKIP_REQUESTS} requests)...`);
  for (let i = 0; i < SKIP_REQUESTS; i++) {
    try { await measureSingleFlow(); } catch { /* skip warmup errors */ }
  }

  // Phase 2: Measured runs
  console.log(`Measuring ${SAMPLE_SIZE} flows...`);
  const allSteps = {};
  const allDurations = [];
  let successes = 0;
  let errors = 0;

  for (let i = 0; i < SAMPLE_SIZE; i++) {
    try {
      const result = await measureSingleFlow();
      if (result.error) {
        errors++;
        if (i < 3) console.log(`  [ERROR #${i + 1}] ${result.error}`);
        continue;
      }
      successes++;
      allDurations.push(result.duration);
      for (const [step, dur] of Object.entries(result.steps)) {
        if (!allSteps[step]) allSteps[step] = [];
        allSteps[step].push(dur);
      }
    } catch (err) {
      errors++;
      if (i < 3) console.log(`  [ERROR #${i + 1}] ${err.message}`);
    }
  }

  // Compute stats
  console.log(`\nResults: ${successes} succeeded, ${errors} failed`);
  if (successes === 0) {
    console.log('\nNo successful flows. Check that server is running and FIREBASE_TOKEN is valid.');
    console.log('To run without auth, set FIREBASE_TOKEN to a valid Firebase ID token.');
    return;
  }

  const sortedTotal = [...allDurations].sort((a, b) => a - b);
  const totalP50 = computePercentiles(sortedTotal, 0.5);
  const totalP95 = computePercentiles(sortedTotal, 0.95);
  const totalP99 = computePercentiles(sortedTotal, 0.99);
  const totalAvg = allDurations.reduce((a, b) => a + b, 0) / allDurations.length;

  console.log('\n── Total Flow ──');
  console.log(`  Avg:  ${totalAvg.toFixed(1)}ms`);
  console.log(`  p50:  ${totalP50}ms`);
  console.log(`  p95:  ${totalP95}ms`);
  console.log(`  p99:  ${totalP99}ms`);

  console.log('\n── Per-Step Latency ──');
  const stepNames = ['POST /requests', 'GET /donor/matches', 'POST /donor/responses/accept', 'POST /hospital/verify'];
  console.log(`  ${'Step'.padEnd(32)} ${'Avg'.padEnd(8)} ${'p50'.padEnd(8)} ${'p95'.padEnd(8)} ${'p99'.padEnd(8)}`);
  console.log('  ' + '─'.repeat(64));
  for (const name of stepNames) {
    const values = allSteps[name];
    if (!values || values.length === 0) {
      console.log(`  ${name.padEnd(32)} ${'N/A'.padEnd(8)} ${'N/A'.padEnd(8)} ${'N/A'.padEnd(8)} ${'N/A'.padEnd(8)}`);
      continue;
    }
    const sorted = [...values].sort((a, b) => a - b);
    const avg = values.reduce((a, b) => a + b, 0) / values.length;
    const p50 = computePercentiles(sorted, 0.5);
    const p95 = computePercentiles(sorted, 0.95);
    const p99 = computePercentiles(sorted, 0.99);
    console.log(`  ${name.padEnd(32)} ${avg.toFixed(1).padEnd(8)} ${p50.toString().padEnd(8)} ${p95.toString().padEnd(8)} ${p99.toString().padEnd(8)}`);
  }

  console.log('─'.repeat(78));
  console.log('E2E BENCHMARK COMPLETE\n');

  if (process.env.JSON_OUTPUT) {
    console.log(JSON.stringify({
      totalFlows: successes,
      errors,
      totalMs: { avg: totalAvg.toFixed(1), p50: totalP50, p95: totalP95, p99: totalP99 },
      perStep: stepNames.map(n => {
        const values = allSteps[n] || [];
        const sorted = [...values].sort((a, b) => a - b);
        return {
          step: n,
          samples: values.length,
          avg: values.length ? (values.reduce((a, b) => a + b, 0) / values.length).toFixed(1) : null,
          p50: values.length ? computePercentiles(sorted, 0.5) : null,
          p95: values.length ? computePercentiles(sorted, 0.95) : null,
          p99: values.length ? computePercentiles(sorted, 0.99) : null,
        };
      }),
    }, null, 2));
  }
}

runBenchmark().catch(console.error);
