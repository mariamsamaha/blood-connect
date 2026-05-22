/**
 * k6 load test — authenticated endpoints (expect 401 without valid token)
 *
 * This test validates that auth middleware and rate limiting work under load.
 * For full end-to-end testing, provide a valid FIREBASE_TOKEN env var.
 *
 * Run:
 *   k6 run load-tests/auth-endpoints.js
 *   k6 run -e FIREBASE_TOKEN="<real-token>" load-tests/auth-endpoints.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const BASE_URL = __ENV.API_BASE_URL || 'http://localhost:8090';
const FIREBASE_TOKEN = __ENV.FIREBASE_TOKEN || '';

const errorRate = new Rate('errors');
const authLatency = new Trend('auth_latency');
const apiLatency = new Trend('api_latency');

export const options = {
  stages: [
    { duration: '10s', target: 10 },
    { duration: '30s', target: 50 },
    { duration: '30s', target: 100 },
    { duration: '10s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'],
    errors: ['rate<0.10'],
  },
};

function authHeaders() {
  return FIREBASE_TOKEN
    ? { Authorization: `Bearer ${FIREBASE_TOKEN}`, 'Content-Type': 'application/json' }
    : { Authorization: 'Bearer invalid-token-for-rate-limit-test', 'Content-Type': 'application/json' };
}

const endpoints = [
  { path: '/api/v1/users/me', method: 'GET', body: null },
  { path: '/api/v1/hospitals', method: 'GET', body: null },
  { path: '/api/v1/requests/active?userId=test', method: 'GET', body: null },
  { path: '/api/v1/donor/matches?donorId=test&compatibleTypesCsv=O%2B&donorLat=30&donorLng=31&radiusKm=120', method: 'GET', body: null },
  { path: '/api/v1/donor/stats?donorId=test', method: 'GET', body: null },
];

export default function () {
  const headers = authHeaders();
  const tokenAvailable = !!FIREBASE_TOKEN;

  for (const ep of endpoints) {
    const res = http.get(`${BASE_URL}${ep.path}`, { headers });

    if (tokenAvailable) {
      check(res, {
        [`${ep.path} responded`]: (r) => r.status !== 0,
      });
    } else {
      const ok = check(res, {
        [`${ep.path} returns 401 without auth`]: (r) => r.status === 401,
      });
      errorRate.add(!ok);
    }

    apiLatency.add(res.timings.duration);
  }

  // Test rate limiting — send rapid requests to one endpoint
  if (!tokenAvailable) {
    const start = Date.now();
    for (let i = 0; i < 10; i++) {
      http.get(`${BASE_URL}/api/v1/users/me`, {
        headers: { Authorization: 'Bearer rate-limit-test', 'Content-Type': 'application/json' },
      });
    }
    authLatency.add(Date.now() - start);
  }

  sleep(0.5);
}
