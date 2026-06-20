/**
 * BloodConnect API Backend — Stress Test (Escalating Concurrency)
 * =================================================================
 *
 * Unlike load_api_backend.js (which measures steady-state behavior at a
 * fixed concurrency), this script escalates connection count through
 * PERF_STRESS_STEPS (default: 10,25,50,100,150) against a single endpoint
 * and reports where latency/error-rate breaks down. This directly answers
 * "what is the breaking point," which a single fixed-load test cannot.
 *
 * Endpoint under test: GET /health/db. Chosen deliberately, NOT GET / —
 * the unauthenticated health check bypasses the database entirely, so it
 * would not reveal connection-pool exhaustion (api-backend/src/db.js pool
 * max: 18). /health/db forces every request through the same pool real
 * traffic uses, making pool exhaustion visible if it occurs.
 */
'use strict';

const autocannon = require('autocannon');
const fs = require('fs');
const path = require('path');
const { config } = require('../config/config');

const results = {
  generatedAt: new Date().toISOString(),
  target: config.API_BASE_URL,
  endpoint: 'GET /health/db',
  steps: [],
};

function runStep(connections) {
  return new Promise((resolve, reject) => {
    console.log(`\n▶ Stress step: ${connections} concurrent connections for ${config.STRESS_STEP_DURATION_SEC}s`);
    const instance = autocannon(
      {
        url: `${config.API_BASE_URL}/health/db`,
        method: 'GET',
        connections,
        duration: config.STRESS_STEP_DURATION_SEC,
      },
      (err, result) => {
        if (err) return reject(err);
        const errorRate = result.requests.total > 0
          ? (result.errors + result.timeouts) / result.requests.total
          : 0;
        const step = {
          connections,
          requestsPerSec: result.requests.average,
          totalRequests: result.requests.total,
          latencyP50: result.latency.p50,
          latencyP95: result.latency.p97_5,
          latencyP99: result.latency.p99,
          latencyMax: result.latency.max,
          errors: result.errors,
          timeouts: result.timeouts,
          errorRatePercent: Math.round(errorRate * 10000) / 100,
        };
        results.steps.push(step);
        console.log(
          `  ${step.requestsPerSec.toFixed(1)} req/s | p50=${step.latencyP50}ms p95=${step.latencyP95}ms ` +
          `p99=${step.latencyP99}ms | errors=${step.errors} timeouts=${step.timeouts} (${step.errorRatePercent}%)`,
        );
        resolve(step);
      },
    );
    autocannon.track(instance, { renderProgressBar: false });
  });
}

async function main() {
  console.log('═══════════════════════════════════════════════════════════');
  console.log(' BloodConnect API Backend — Stress Test (Escalating Load)');
  console.log(' Target:', config.API_BASE_URL);
  console.log(' Steps (connections):', config.STRESS_STEPS.join(', '));
  console.log('═══════════════════════════════════════════════════════════');

  for (const connections of config.STRESS_STEPS) {
    await runStep(connections);
  }

  // Identify the first step where error rate exceeds 1% or p99 exceeds 2x
  // the first step's p99 — a simple, explainable "breaking point" heuristic.
  const baseline = results.steps[0];
  let breakingPoint = null;
  for (const step of results.steps) {
    if (step.errorRatePercent > 1 || (baseline && step.latencyP99 > baseline.latencyP99 * 2)) {
      breakingPoint = step;
      break;
    }
  }
  results.breakingPoint = breakingPoint
    ? { connections: breakingPoint.connections, reason: breakingPoint.errorRatePercent > 1 ? 'error_rate_exceeded_1_percent' : 'p99_latency_doubled_vs_baseline' }
    : { connections: null, reason: 'not_reached_within_tested_steps' };

  fs.mkdirSync(config.REPORT_DIR, { recursive: true });
  const outPath = path.join(config.REPORT_DIR, 'stress_test_results.json');
  fs.writeFileSync(outPath, JSON.stringify(results, null, 2));

  console.log('\n───────────────────────────────────────────────────────────');
  if (breakingPoint) {
    console.log(`✗ Breaking point reached at ${breakingPoint.connections} connections (${results.breakingPoint.reason})`);
  } else {
    console.log(`✓ No breaking point reached within tested steps (max ${Math.max(...config.STRESS_STEPS)} connections)`);
  }
  console.log(`✓ Stress test results written to ${outPath}`);
}

main().catch((err) => {
  console.error('\n✗ Stress test failed:', err);
  process.exit(1);
});
