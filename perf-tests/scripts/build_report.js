/**
 * BloodConnect Performance Suite — Report Builder
 * ==================================================
 *
 * Reads every reports/*_results.json file produced by the individual test
 * scripts and produces:
 *   - reports/summary.json       (consolidated, machine-readable)
 *   - reports/summary.csv        (one row per scenario/test, for spreadsheets)
 *   - Console output             (human-readable, with interpretation)
 *
 * Threshold values used for interpretation are documented in INTERPRETATION.md
 * alongside this script and are NOT arbitrary — each is tied either to a
 * value already present in the codebase (e.g. the SLO targets in
 * api-backend/src/slo.js) or to a widely-cited industry rule of thumb
 * (e.g. the "100ms feels instant, 1s is the limit of flow, 10s loses
 * attention" UX latency bands), cited inline below.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { config } = require('../config/config');

// SLO targets actually defined in api-backend/src/slo.js (SLO_TARGETS).
const API_SLO = { availability: 99.5, p95LatencyMs: 2000, p99LatencyMs: 5000, errorRatePercent: 5 };
// AI prediction latency target stated in the thesis NFR table (§4.2): p95 < 30s.
const AI_P95_TARGET_MS = 30000;

function loadJsonIfExists(filename) {
  const p = path.join(config.REPORT_DIR, filename);
  if (!fs.existsSync(p)) return null;
  try {
    return JSON.parse(fs.readFileSync(p, 'utf8'));
  } catch {
    return null;
  }
}

function rateLabel(value, warnAt, critAt, higherIsWorse = true) {
  if (value == null) return 'NOT MEASURED';
  const bad = higherIsWorse ? value >= critAt : value <= critAt;
  const warn = higherIsWorse ? value >= warnAt : value <= warnAt;
  if (bad) return 'CRITICAL';
  if (warn) return 'WARNING';
  return 'GOOD';
}

function section(title) {
  console.log(`\n${'─'.repeat(70)}\n ${title}\n${'─'.repeat(70)}`);
}

function main() {
  const apiResults = loadJsonIfExists('api_backend_results.json');
  const stressResults = loadJsonIfExists('stress_test_results.json');
  const notificationResults = loadJsonIfExists('notification_backend_results.json');
  const dbResults = loadJsonIfExists('database_results.json');
  const aiResults = loadJsonIfExists('ai_service_results.json');
  const resourceResults = loadJsonIfExists('resource_usage.json');

  console.log('\n═══════════════════════════════════════════════════════════');
  console.log(' BloodConnect Performance Test Suite — Consolidated Report');
  console.log(' Generated:', new Date().toISOString());
  console.log('═══════════════════════════════════════════════════════════');

  const csvRows = [['component', 'scenario', 'metric', 'value', 'unit', 'rating']];
  const consolidated = { generatedAt: new Date().toISOString(), components: {} };

  // ── API backend ──────────────────────────────────────────────────────
  if (apiResults) {
    section('API Backend');
    consolidated.components.apiBackend = apiResults;
    for (const s of apiResults.scenarios) {
      const p95 = s.latencyMs.p97_5 ?? s.latencyMs.p95;
      const p99 = s.latencyMs.p99;
      const p95Rating = rateLabel(p95, API_SLO.p95LatencyMs * 0.5, API_SLO.p95LatencyMs);
      const p99Rating = rateLabel(p99, API_SLO.p99LatencyMs * 0.5, API_SLO.p99LatencyMs);
      console.log(`\n  ${s.scenario}  [${s.route}]`);
      console.log(`    Throughput: ${s.requests.average.toFixed(1)} req/s`);
      console.log(`    p50=${s.latencyMs.p50}ms  p95=${p95}ms [${p95Rating}]  p99=${p99}ms [${p99Rating}]  max=${s.latencyMs.max}ms`);
      if (s.errors || s.timeouts) console.log(`    ⚠ errors=${s.errors} timeouts=${s.timeouts}`);
      csvRows.push(['api_backend', s.scenario, 'throughput_rps', s.requests.average.toFixed(2), 'req/s', '']);
      csvRows.push(['api_backend', s.scenario, 'p50_latency', s.latencyMs.p50, 'ms', '']);
      csvRows.push(['api_backend', s.scenario, 'p95_latency', p95, 'ms', p95Rating]);
      csvRows.push(['api_backend', s.scenario, 'p99_latency', p99, 'ms', p99Rating]);
    }
  } else {
    console.log('\n(API backend results not found — run `npm run test:api` first.)');
  }

  // ── Stress test ──────────────────────────────────────────────────────
  if (stressResults) {
    section('Stress Test (Escalating Concurrency, GET /health/db)');
    for (const step of stressResults.steps) {
      console.log(
        `  ${step.connections} conns: ${step.requestsPerSec.toFixed(1)} req/s | ` +
        `p95=${step.latencyP95}ms p99=${step.latencyP99}ms | error_rate=${step.errorRatePercent}%`,
      );
      csvRows.push(['api_backend_stress', `connections_${step.connections}`, 'requests_per_sec', step.requestsPerSec.toFixed(2), 'req/s', '']);
      csvRows.push(['api_backend_stress', `connections_${step.connections}`, 'error_rate', step.errorRatePercent, '%', step.errorRatePercent > 1 ? 'CRITICAL' : 'GOOD']);
    }
    console.log(`\n  Breaking point: ${stressResults.breakingPoint.connections ?? 'not reached'} connections (${stressResults.breakingPoint.reason})`);
  } else {
    console.log('\n(Stress test results not found — run `node scripts/stress_test_api_backend.js` first.)');
  }

  // ── Notification backend ─────────────────────────────────────────────
  if (notificationResults) {
    section('Notification Backend');
    for (const s of notificationResults.scenarios) {
      console.log(`\n  ${s.scenario}  [${s.route}]`);
      console.log(`    Throughput: ${s.requests.average.toFixed(1)} req/s | p50=${s.latencyMs.p50}ms p99=${s.latencyMs.p99}ms`);
      csvRows.push(['notification_backend', s.scenario, 'throughput_rps', s.requests.average.toFixed(2), 'req/s', '']);
      csvRows.push(['notification_backend', s.scenario, 'p99_latency', s.latencyMs.p99, 'ms', '']);
    }
  } else {
    console.log('\n(Notification backend results not found — run `npm run test:notification` first.)');
  }

  // ── Database ─────────────────────────────────────────────────────────
  if (dbResults) {
    section('Database');
    for (const t of dbResults.tests) {
      if (t.avgMs != null) {
        console.log(`  ${t.test}: avg=${t.avgMs}ms p95=${t.p95Ms}ms`);
        csvRows.push(['database', t.test, 'avg_latency', t.avgMs, 'ms', '']);
      } else if (t.totalElapsedMs != null) {
        const expected = t.expectedIfUnbottlenecked;
        const ratio = t.totalElapsedMs / expected;
        const rating = ratio > 3 ? 'CRITICAL' : ratio > 1.5 ? 'WARNING' : 'GOOD';
        console.log(`  ${t.test}: ${t.totalElapsedMs}ms (expected ~${expected}ms if unbottlenecked) [${rating}]`);
        csvRows.push(['database', t.test, 'elapsed_vs_expected_ratio', ratio.toFixed(2), 'x', rating]);
      }
    }
    if (dbResults.indexUsageFinding) {
      const f = dbResults.indexUsageFinding;
      console.log(`\n  Index usage finding: ${f.usesIndexAccordingToPlanner ? '✓ Planner DOES use an index scan' : '✗ Planner does NOT use an index scan'} for the inline ST_Distance form used by GET /api/v1/donor/matches.`);
      csvRows.push(['database', 'donor_matches_index_usage', 'uses_index_scan', f.usesIndexAccordingToPlanner, 'bool', f.usesIndexAccordingToPlanner ? 'GOOD' : 'WARNING']);
    }
  } else {
    console.log('\n(Database results not found — run `npm run test:db` first.)');
  }

  // ── AI service ───────────────────────────────────────────────────────
  if (aiResults) {
    section('AI Service');
    for (const t of aiResults.tests) {
      if (t.avgMs != null) {
        const rating = rateLabel(t.p95Ms ?? t.avgMs, AI_P95_TARGET_MS * 0.5, AI_P95_TARGET_MS);
        console.log(`  ${t.test}: avg=${t.avgMs}ms p95=${t.p95Ms ?? 'n/a'}ms [${rating}]`);
        csvRows.push(['ai_service', t.test, 'avg_latency', t.avgMs, 'ms', rating]);
      }
    }
    if (aiResults.blockingHypothesisFinding) {
      const f = aiResults.blockingHypothesisFinding;
      const ratingRatio = f.scalingRatio;
      const blocked = ratingRatio !== null && ratingRatio > f.concurrencyLevelTested * 0.7;
      console.log(`\n  Concurrency scaling ratio (concurrency=${f.concurrencyLevelTested}): ${f.scalingRatio}`);
      console.log(`  ${blocked ? '✗ CONFIRMED' : '○ NOT CONFIRMED'}: requests at this concurrency level appear to be ${blocked ? 'serialized (event-loop/worker blocking)' : 'running with at least partial parallelism'}.`);
      csvRows.push(['ai_service', 'concurrency_blocking_hypothesis', 'scaling_ratio', f.scalingRatio, 'x', blocked ? 'CRITICAL' : 'GOOD']);
    }
  } else {
    console.log('\n(AI service results not found — run `python3 scripts/load_ai_service.py` first.)');
  }

  // ── Resource usage ───────────────────────────────────────────────────
  if (resourceResults && resourceResults.samples && resourceResults.samples.length) {
    section('Resource Usage (CPU / Memory)');
    console.log(`  Mode: ${resourceResults.mode} | Samples collected: ${resourceResults.samples.length}`);
    console.log('  (Full time series in reports/resource_usage.json; not aggregated here to avoid implying false precision.)');
  } else {
    console.log('\n(Resource usage not measured — see README.md "Optional: CPU/memory monitoring while tests run" to enable Docker stats or PID-based sampling.)');
  }

  // ── Write consolidated outputs ───────────────────────────────────────
  fs.writeFileSync(path.join(config.REPORT_DIR, 'summary.json'), JSON.stringify(consolidated, null, 2));
  const csv = csvRows.map((row) => row.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(',')).join('\n');
  fs.writeFileSync(path.join(config.REPORT_DIR, 'summary.csv'), csv);

  console.log('\n═══════════════════════════════════════════════════════════');
  console.log(' Reports written:');
  console.log(`   ${path.join(config.REPORT_DIR, 'summary.json')}`);
  console.log(`   ${path.join(config.REPORT_DIR, 'summary.csv')}`);
  console.log(' See INTERPRETATION.md for what each rating (GOOD/WARNING/CRITICAL) means.');
  console.log('═══════════════════════════════════════════════════════════\n');
}

main();
