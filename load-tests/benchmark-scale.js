/**
 * Benchmark: Horizontal Scaling (3.2)
 *
 * Measures RPS improvement when running 3 api-backend replicas
 * behind Nginx least_conn with shared Redis rate limiting.
 *
 * Usage:
 *   # Start the scaled stack:
 *   docker compose -f docker-compose.yml -f docker-compose.gateway.yml -f docker-compose.scale.yml up -d
 *
 *   # Run benchmark against the gateway:
 *   node load-tests/benchmark-scale.js
 *
 *   # Compare with single-instance baseline:
 *   API_BASE_URL=http://localhost:8090 node load-tests/benchmark-scale.js
 */

const http = require('http');

const BASE_URL = process.env.API_BASE_URL || 'http://localhost:80';
const DURATION_SEC = parseInt(process.env.DURATION_SEC || '10', 10);
const CONCURRENCY = parseInt(process.env.CONCURRENCY || '20', 10);
const WARMUP_SEC = 2;

const urlParts = new URL(BASE_URL);

function httpGet(path) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: urlParts.hostname,
      port: urlParts.port || 80,
      path,
      method: 'GET',
      timeout: 10000,
    };
    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => resolve({ status: res.statusCode, body }));
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
    req.end();
  });
}

async function runLoad(durationMs, path) {
  const results = [];
  const errors = [];
  let running = true;

  async function worker() {
    while (running) {
      const start = Date.now();
      try {
        const res = await httpGet(path);
        results.push({ status: res.status, duration: Date.now() - start });
      } catch (err) {
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

async function benchmark(options = {}) {
  const {
    name,
    endpoint,
    durationMs = DURATION_SEC * 1000,
  } = options;

  await runLoad(WARMUP_SEC * 1000, endpoint);

  const startTime = Date.now();
  const { results, errors } = await runLoad(durationMs, endpoint);
  const totalTime = (Date.now() - startTime) / 1000;

  const totalRequests = results.length + errors.length;
  const rps = totalRequests / totalTime;
  const statusCounts = {};
  for (const r of results) {
    statusCounts[r.status] = (statusCounts[r.status] || 0) + 1;
  }
  const durations = results.map((r) => r.duration).sort((a, b) => a - b);
  const p50 = durations[Math.floor(durations.length * 0.5)] || 0;
  const p95 = durations[Math.floor(durations.length * 0.95)] || 0;
  const p99 = durations[Math.floor(durations.length * 0.99)] || 0;
  const avg = durations.reduce((a, b) => a + b, 0) / (durations.length || 1);

  return {
    name,
    endpoint,
    duration: `${durationMs / 1000}s`,
    concurrency: CONCURRENCY,
    totalRequests,
    rps: rps.toFixed(2),
    statusCounts,
    networkErrors: errors.length,
    latencyMs: {
      avg: avg.toFixed(1),
      p50: p50.toFixed(1),
      p95: p95.toFixed(1),
      p99: p99.toFixed(1),
    },
  };
}

function pad(s, n) {
  return String(s).padEnd(n);
}

async function runAll() {
  const divider = '\u2500'.repeat(78);

  console.log(`\nBloodConnect Scaling Benchmark`);
  console.log(`Base URL: ${BASE_URL}`);
  console.log(`Concurrency: ${CONCURRENCY}, Measurement: ${DURATION_SEC}s (${WARMUP_SEC}s warmup)`);
  console.log(divider);

  const endpoints = [
    { name: 'Health Check (scaled)', endpoint: '/' },
    { name: 'Metrics (scaled)', endpoint: '/metrics' },
    { name: 'SLO Report (scaled)', endpoint: '/slo' },
    { name: 'OpenAPI JSON (scaled)', endpoint: '/api/docs.json' },
  ];

  const all = [];
  for (const ep of endpoints) {
    const result = await benchmark({
      name: ep.name,
      endpoint: ep.endpoint,
      durationMs: DURATION_SEC * 1000,
    });
    all.push(result);

    const status = Object.entries(result.statusCounts)
      .map(([code, count]) => `${code}:${count}`)
      .join(' ');
    const netErr = result.networkErrors > 0 ? `  netErr:${result.networkErrors}` : '';
    console.log(
      `[${pad(result.name, 25)}]  RPS:${pad(result.rps, 7)}` +
      `  p50:${pad(result.latencyMs.p50, 6)}ms  p95:${pad(result.latencyMs.p95, 6)}ms  p99:${pad(result.latencyMs.p99, 6)}ms` +
      `  ${status}${netErr}`
    );
  }

  console.log(divider);
  console.log('SCALE BENCHMARK COMPLETE\n');

  if (process.env.JSON_OUTPUT) {
    console.log(JSON.stringify(all, null, 2));
  }
}

runAll().catch(console.error);
