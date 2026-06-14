# Load Test Guide

Run these against a **running** API (local or deployed) and save output for your graduation evidence.

## Prerequisites

- API running at `http://localhost:8090` or your deployed URL
- Optional: valid Firebase ID token for authenticated benchmarks
- Optional: [k6](https://k6.io/docs/get-started/installation/) for VU-based load tests

## 1. Baseline (unauthenticated)

```bash
node load-tests/benchmark.js
```

Measures: `GET /`, `/metrics`, `/slo`, `/api/docs.json`

**Documented results:** see `docs/BENCHMARK.md` §1 (695 RPS health, p95 41ms).

## 2. k6 concurrency (100 virtual users)

```bash
API_BASE_URL=http://localhost:8090 k6 run load-tests/health-check.js \
  --out json=load-tests/results-health.json
```

Thresholds: p95 &lt; 2s, error rate &lt; 5%.

## 3. Authenticated bottleneck isolation

```bash
FIREBASE_TOKEN="<your-firebase-id-token>" node load-tests/benchmark-bottleneck.js
```

## 4. End-to-end user flow latency

```bash
FIREBASE_TOKEN="<your-firebase-id-token>" node load-tests/benchmark-e2e.js
```

Flow: create request → donor matches → accept → hospital verify.

## 5. Horizontal scaling (3 replicas)

```bash
docker compose -f docker-compose.yml -f docker-compose.gateway.yml -f docker-compose.scale.yml up -d
node load-tests/benchmark-scale.js
```

## After running

1. Copy measured RPS/p95 values into `docs/BENCHMARK.md` (replace `—` placeholders)
2. Commit `load-tests/results-*.json` or paste a summary table in the benchmark doc
3. Use numbers in your demo — see `docs/DEMO.md` Part 4
