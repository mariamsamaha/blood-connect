/**
 * SLO tracking — Redis-backed rolling windows.
 *
 * The previous implementation stored requests in in-memory JS arrays,
 * capped by *entry count* (3600 / 86400 entries) rather than by elapsed
 * time. Under cluster mode each worker process held its own array, so
 * /slo reported only one worker's partial view — not the system's.
 * Under low traffic, "hourly" entries could in fact span days, since the
 * cap was entry-count-based, not time-based.
 *
 * This version stores each request in Redis sorted sets so:
 *   - All cluster workers read/write the same windows.
 *   - Windows are genuinely time-bound (last 1h / last 24h by clock time).
 *   - Stale entries are pruned on every write via ZREMRANGEBYSCORE.
 *
 * Total/error sets score members by timestamp (ms) directly, which makes
 * both eviction and counting trivial via ZCARD/ZREMRANGEBYSCORE.
 *
 * Latency sets ALSO score by timestamp (not duration) so the same
 * time-based eviction works — but the duration itself is encoded into the
 * member string ("<ts>-<rand>-<durationMs>") since a sorted set can only
 * hold one numeric score per member. Percentiles are computed by pulling
 * all members in a window and parsing the duration back out, then sorting
 * locally. (Scoring by duration directly would make eviction-by-time
 * impossible, since a request's duration has no relationship to how old
 * the request is — that was the original bug found while implementing
 * this fix.)
 *
 * Falls back to the original in-memory behavior if Redis is disabled or
 * unreachable, so SLO tracking still works in dev/test without Redis.
 */

const redis = require('./redis');
const logger = require('./logger');

const SLO_TARGETS = {
  availability: 99.5,
  p95LatencyMs: 2000,
  p99LatencyMs: 5000,
  errorRatePercent: 5,
};

const WINDOW_1H_MS  = 60 * 60 * 1000;
const WINDOW_24H_MS = 24 * 60 * 60 * 1000;

const KEYS = {
  total1h:    'slo:total:1h',
  errors1h:   'slo:errors:1h',
  latency1h:  'slo:latency:1h',
  total24h:   'slo:total:24h',
  errors24h:  'slo:errors:24h',
  latency24h: 'slo:latency:24h',
};

// ── In-memory fallback (used when Redis is disabled/unreachable) ───────────
// Time-bound, unlike the old entry-count-bound version, so behavior matches
// the Redis path even when running without Redis.
const fallback = { requests: [] };

function fallbackRecord(statusCode, durationMs) {
  const now = Date.now();
  fallback.requests.push({ ts: now, status: statusCode, duration: durationMs });
  const cutoff = now - WINDOW_24H_MS;
  fallback.requests = fallback.requests.filter((r) => r.ts > cutoff);
}

function fallbackWindow(windowMs) {
  const cutoff = Date.now() - windowMs;
  const window = fallback.requests.filter((r) => r.ts > cutoff);
  const total  = window.length;
  const errors = window.filter((r) => r.status >= 500).length;
  const durations = window.map((r) => r.duration).sort((a, b) => a - b);
  return { total, errors, durations };
}

// ── Redis-backed implementation ─────────────────────────────────────────────

async function redisRecord(statusCode, durationMs) {
  const client = redis.getClient();
  const now    = Date.now();
  const member = `${now}-${Math.random().toString(36).slice(2, 8)}`;
  const isError = statusCode >= 500;

  const cutoff1h  = now - WINDOW_1H_MS;
  const cutoff24h = now - WINDOW_24H_MS;

  const pipe = client.pipeline();

  pipe.zadd(KEYS.total1h, now, member);
  pipe.zremrangebyscore(KEYS.total1h, '-inf', cutoff1h);
  pipe.expire(KEYS.total1h, 3660);

  pipe.zadd(KEYS.total24h, now, member);
  pipe.zremrangebyscore(KEYS.total24h, '-inf', cutoff24h);
  pipe.expire(KEYS.total24h, 86460);

  if (isError) {
    pipe.zadd(KEYS.errors1h, now, member);
    pipe.zremrangebyscore(KEYS.errors1h, '-inf', cutoff1h);
    pipe.expire(KEYS.errors1h, 3660);

    pipe.zadd(KEYS.errors24h, now, member);
    pipe.zremrangebyscore(KEYS.errors24h, '-inf', cutoff24h);
    pipe.expire(KEYS.errors24h, 86460);
  }

  // Latency entries must be evictable by TIME (like the other sets), but we
  // also need to recover the DURATION later to compute percentiles. A sorted
  // set only has one numeric score per member, so it can't hold both.
  //
  // Fix: score = timestamp (so ZREMRANGEBYSCORE evicts old entries exactly
  // like the other windows), and the duration is encoded into the member
  // string ("<ts>-<rand>-<durationMs>"). Duration is parsed back out of the
  // member string when computing percentiles.
  const latencyMember = `${member}-${durationMs}`;

  pipe.zadd(KEYS.latency1h, now, latencyMember);
  pipe.zremrangebyscore(KEYS.latency1h, '-inf', cutoff1h);
  pipe.expire(KEYS.latency1h, 3660);

  pipe.zadd(KEYS.latency24h, now, latencyMember);
  pipe.zremrangebyscore(KEYS.latency24h, '-inf', cutoff24h);
  pipe.expire(KEYS.latency24h, 86460);

  await pipe.exec();
}

async function redisWindow(totalKey, errorKey, latencyKey) {
  const client = redis.getClient();
  const [total, errors, latencyMembers] = await Promise.all([
    client.zcard(totalKey),
    client.zcard(errorKey),
    // Latency members are scored by timestamp, not duration (see redisRecord),
    // so we pull every member and parse the encoded duration back out, then
    // sort by duration ourselves to compute percentiles.
    client.zrange(latencyKey, 0, -1),
  ]);

  let p95 = 0;
  let p99 = 0;
  let avg = 0;

  if (latencyMembers.length > 0) {
    const durations = latencyMembers
      .map((m) => {
        const lastDash = m.lastIndexOf('-');
        const parsed = parseFloat(m.slice(lastDash + 1));
        return Number.isFinite(parsed) ? parsed : null;
      })
      .filter((d) => d !== null)
      .sort((a, b) => a - b);

    if (durations.length > 0) {
      const p95Idx = Math.max(0, Math.ceil(durations.length * 0.95) - 1);
      const p99Idx = Math.max(0, Math.ceil(durations.length * 0.99) - 1);
      p95 = durations[p95Idx];
      p99 = durations[p99Idx];
      avg = durations.reduce((a, b) => a + b, 0) / durations.length;
    }
  }

  return { total, errors, p95, p99, avg };
}

// ── Public API ─────────────────────────────────────────────────────────────

async function recordRequest(statusCode, durationMs) {
  try {
    if (redis.isEnabled()) {
      await redisRecord(statusCode, durationMs);
      return;
    }
  } catch (err) {
    logger.warn({ err }, 'SLO Redis write failed — falling back to in-memory for this request');
  }
  fallbackRecord(statusCode, durationMs);
}

async function getWindowStats(windowMs) {
  try {
    if (redis.isEnabled()) {
      const isHourly = windowMs <= WINDOW_1H_MS;
      const totalKey   = isHourly ? KEYS.total1h   : KEYS.total24h;
      const errorKey   = isHourly ? KEYS.errors1h  : KEYS.errors24h;
      const latencyKey = isHourly ? KEYS.latency1h : KEYS.latency24h;
      const stats = await redisWindow(totalKey, errorKey, latencyKey);
      return {
        total: stats.total,
        errors: stats.errors,
        availability: stats.total > 0 ? ((stats.total - stats.errors) / stats.total) * 100 : 100,
        errorRatePercent: stats.total > 0 ? (stats.errors / stats.total) * 100 : 0,
        p95LatencyMs: stats.p95,
        p99LatencyMs: stats.p99,
        avgLatencyMs: stats.avg,
      };
    }
  } catch (err) {
    logger.warn({ err }, 'SLO Redis read failed — falling back to in-memory');
  }

  const { total, errors, durations } = fallbackWindow(windowMs);
  if (total === 0) return null;
  const p95Idx = Math.max(0, Math.ceil(total * 0.95) - 1);
  const p99Idx = Math.max(0, Math.ceil(total * 0.99) - 1);
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

async function checkSLOViolations() {
  const hourly = await getWindowStats(WINDOW_1H_MS);
  const daily  = await getWindowStats(WINDOW_24H_MS);

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

async function sloReportHandler(_req, res) {
  try {
    const hourly = await getWindowStats(WINDOW_1H_MS);
    const daily  = await getWindowStats(WINDOW_24H_MS);
    const violations = await checkSLOViolations();

    res.json({
      targets: SLO_TARGETS,
      windows: {
        hourly: hourly || { total: 0, availability: 100, errorRatePercent: 0 },
        daily:  daily  || { total: 0, availability: 100, errorRatePercent: 0 },
      },
      violations,
      backend: redis.isEnabled() ? 'redis' : 'in-memory-fallback',
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    logger.error({ err }, 'Failed to generate SLO report');
    res.status(500).json({ error: 'slo_report_failed' });
  }
}

module.exports = { recordRequest, checkSLOViolations, sloReportHandler };