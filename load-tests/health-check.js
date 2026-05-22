/**
 * k6 load test — health endpoints (unauthenticated)
 *
 * Run:
 *   k6 run load-tests/health-check.js
 *
 * Or with output:
 *   k6 run --out json=load-tests/results.json load-tests/health-check.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const BASE_URL = __ENV.API_BASE_URL || 'http://localhost:8090';

const errorRate = new Rate('errors');
const healthLatency = new Trend('health_latency');
const dbHealthLatency = new Trend('db_health_latency');

export const options = {
  stages: [
    { duration: '30s', target: 20 },   // Ramp up to 20 users
    { duration: '1m', target: 50 },     // Ramp to 50 users
    { duration: '2m', target: 100 },    // Ramp to 100 users
    { duration: '1m', target: 100 },    // Stay at 100
    { duration: '30s', target: 0 },     // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests under 2s
    errors: ['rate<0.05'],              // Error rate under 5%
  },
};

export default function () {
  // Health check
  {
    const res = http.get(`${BASE_URL}/`);
    const ok = check(res, {
      'health status is 200': (r) => r.status === 200,
      'health body has status ok': (r) => r.json('status') === 'ok',
    });
    errorRate.add(!ok);
    healthLatency.add(res.timings.duration);
  }

  // DB health check
  {
    const res = http.get(`${BASE_URL}/health/db`);
    const ok = check(res, {
      'db health returns 200 or 503': (r) => r.status === 200 || r.status === 503,
    });
    errorRate.add(!ok);
    dbHealthLatency.add(res.timings.duration);
  }

  sleep(1);
}
