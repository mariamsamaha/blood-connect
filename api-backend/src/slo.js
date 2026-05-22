const logger = require('./logger');

const SLO_TARGETS = {
  availability: 99.5,
  p95LatencyMs: 2000,
  p99LatencyMs: 5000,
  errorRatePercent: 5,
};

const windows = {
  hourly: { maxEntries: 3600, entries: [] },
  daily: { maxEntries: 86400, entries: [] },
};

function recordRequest(statusCode, durationMs) {
  const now = Date.now();
  const entry = { ts: now, status: statusCode, duration: durationMs };

  windows.hourly.entries.push(entry);
  if (windows.hourly.entries.length > windows.hourly.maxEntries) {
    windows.hourly.entries.shift();
  }

  windows.daily.entries.push(entry);
  if (windows.daily.entries.length > windows.daily.maxEntries) {
    windows.daily.entries.shift();
  }
}

function analyzeWindow(window) {
  const total = window.entries.length;
  if (total === 0) return null;

  const errors = window.entries.filter((e) => e.status >= 500).length;
  const durations = window.entries.map((e) => e.duration).sort((a, b) => a - b);

  const p95Idx = Math.ceil(total * 0.95) - 1;
  const p99Idx = Math.ceil(total * 0.99) - 1;

  return {
    total,
    errors,
    availability: ((total - errors) / total) * 100,
    errorRatePercent: (errors / total) * 100,
    p95LatencyMs: durations[p95Idx] || 0,
    p99LatencyMs: durations[p99Idx] || 0,
    avgLatencyMs: durations.reduce((a, b) => a + b, 0) / total,
  };
}

function checkSLOViolations() {
  const hourly = analyzeWindow(windows.hourly);
  const daily = analyzeWindow(windows.daily);

  const violations = [];

  if (hourly) {
    if (hourly.availability < SLO_TARGETS.availability) {
      violations.push({
        severity: 'P1',
        message: `Hourly availability ${hourly.availability.toFixed(2)}% below target ${SLO_TARGETS.availability}%`,
        window: '1h',
        actual: hourly.availability,
        target: SLO_TARGETS.availability,
      });
    }
    if (hourly.p95LatencyMs > SLO_TARGETS.p95LatencyMs) {
      violations.push({
        severity: 'P2',
        message: `Hourly p95 latency ${hourly.p95LatencyMs}ms above target ${SLO_TARGETS.p95LatencyMs}ms`,
        window: '1h',
        actual: hourly.p95LatencyMs,
        target: SLO_TARGETS.p95LatencyMs,
      });
    }
    if (hourly.errorRatePercent > SLO_TARGETS.errorRatePercent) {
      violations.push({
        severity: 'P2',
        message: `Hourly error rate ${hourly.errorRatePercent.toFixed(2)}% above target ${SLO_TARGETS.errorRatePercent}%`,
        window: '1h',
        actual: hourly.errorRatePercent,
        target: SLO_TARGETS.errorRatePercent,
      });
    }
  }

  if (daily) {
    if (daily.availability < SLO_TARGETS.availability) {
      violations.push({
        severity: 'P2',
        message: `Daily availability ${daily.availability.toFixed(2)}% below target ${SLO_TARGETS.availability}%`,
        window: '24h',
        actual: daily.availability,
        target: SLO_TARGETS.availability,
      });
    }
  }

  return violations;
}

function sloReportHandler(_req, res) {
  const hourly = analyzeWindow(windows.hourly);
  const daily = analyzeWindow(windows.daily);

  res.json({
    targets: SLO_TARGETS,
    windows: {
      hourly: hourly || { total: 0, availability: 100, errorRatePercent: 0 },
      daily: daily || { total: 0, availability: 100, errorRatePercent: 0 },
    },
    violations: checkSLOViolations(),
    timestamp: new Date().toISOString(),
  });
}

module.exports = { recordRequest, checkSLOViolations, sloReportHandler };
