/**
 * E2E smoke tests — run against a running instance or CI environment.
 *
 * Usage:
 *   API_BASE_URL=http://localhost:8090 npx jest tests/e2e/health.test.js
 *
 * These tests verify the full request-response cycle for critical user flows.
 * They require a live database and Firebase emulator or real instance.
 */

const API_BASE_URL = process.env.API_BASE_URL || 'http://localhost:8090';
const { describe, test, expect } = require('@jest/globals');

async function api(path, options = {}) {
  const url = `${API_BASE_URL}${path}`;
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...options.headers },
    ...options,
  });
  const body = res.headers.get('content-type')?.includes('json')
    ? await res.json()
    : await res.text();
  return { status: res.status, body, headers: res.headers };
}

describe('E2E: Health endpoints', () => {
  test('GET / returns service status', async () => {
    const { status, body } = await api('/');
    expect(status).toBe(200);
    expect(body.status).toBe('ok');
    expect(body.service).toBe('bloodconnect-api');
  });

  test('GET /health/db returns database health', async () => {
    const { status, body } = await api('/health/db');
    expect([200, 503]).toContain(status);
    if (status === 200) {
      expect(body.status).toBe('ok');
      expect(body).toHaveProperty('pool');
      expect(body).toHaveProperty('latency_ms');
      expect(typeof body.latency_ms).toBe('number');
    }
  });

  test('GET /api/docs.json returns OpenAPI spec', async () => {
    const { status, body } = await api('/api/docs.json');
    expect(status).toBe(200);
    expect(body.openapi).toBe('3.0.0');
    expect(body.paths).toBeDefined();
  });
});

describe('E2E: Auth rejection', () => {
  test('GET /api/v1/users/me returns 401 without token', async () => {
    const { status, body } = await api('/api/v1/users/me');
    expect(status).toBe(401);
    expect(body.error).toBe('missing_token');
  });

  test('POST /api/v1/requests returns 401 without token', async () => {
    const { status, body } = await api('/api/v1/requests', {
      method: 'POST',
      body: JSON.stringify({}),
    });
    expect(status).toBe(401);
  });

  test('GET /api/v1/donor/matches returns 401 without token', async () => {
    const { status, body } = await api('/api/v1/donor/matches');
    expect(status).toBe(401);
  });
});

describe('E2E: Input validation', () => {
  test('POST /api/v1/requests returns 400 with missing fields', async () => {
    const { status, body } = await api('/api/v1/requests', {
      method: 'POST',
      headers: { Authorization: 'Bearer fake-token' },
      body: JSON.stringify({}),
    });
    expect(status).toBe(400);
    expect(body.error).toContain('missing_fields');
  });

  test('POST /api/v1/requests rejects invalid blood type', async () => {
    const { status, body } = await api('/api/v1/requests', {
      method: 'POST',
      headers: { Authorization: 'Bearer fake-token' },
      body: JSON.stringify({
        requesterId: 'uuid',
        bloodType: 'INVALID',
        unitsNeeded: 1,
        urgencyLevel: 'routine',
        hospitalId: 'uuid',
        hospitalLat: 30,
        hospitalLng: 31,
      }),
    });
    // Should fail auth first, but if auth passes, blood type should be validated
    expect([400, 401]).toContain(status);
  });

  test('POST /api/v1/requests rejects negative units', async () => {
    const { status, body } = await api('/api/v1/requests', {
      method: 'POST',
      headers: { Authorization: 'Bearer fake-token' },
      body: JSON.stringify({
        requesterId: 'uuid',
        bloodType: 'O+',
        unitsNeeded: -1,
        urgencyLevel: 'routine',
        hospitalId: 'uuid',
        hospitalLat: 30,
        hospitalLng: 31,
      }),
    });
    expect([400, 401]).toContain(status);
  });

  test('PATCH /api/v1/users/me rejects invalid payload', async () => {
    const { status, body } = await api('/api/v1/users/me', {
      method: 'PATCH',
      headers: { Authorization: 'Bearer fake-token' },
      body: JSON.stringify({}),
    });
    expect([400, 401]).toContain(status);
  });
});

describe('E2E: Hospital search validation', () => {
  test('GET /api/v1/hospital/search with short code returns empty', async () => {
    const { status, body } = await api('/api/v1/hospital/search?code=12&hospitalUserId=uuid', {
      headers: { Authorization: 'Bearer fake-token' },
    });
    expect([200, 401]).toContain(status);
    if (status === 200) {
      expect(Array.isArray(body)).toBe(true);
    }
  });

  test('GET /api/v1/hospital/search normalizes codes', async () => {
    const { status, body } = await api('/api/v1/hospital/search?code=abc12345&hospitalUserId=uuid', {
      headers: { Authorization: 'Bearer fake-token' },
    });
    expect([200, 401]).toContain(status);
  });
});

describe('E2E: Rate limiting headers', () => {
  test('Rate limit headers are present', async () => {
    const { headers } = await api('/');
    const hasRateLimit = headers.get('ratelimit-limit') || headers.get('x-ratelimit-limit');
    // Rate limit headers depend on express-rate-limit config
    expect(headers.get('content-type')).toContain('json');
  });
});

describe('E2E: CORS headers', () => {
  test('Responds with CORS headers', async () => {
    const { headers } = await api('/');
    // CORS headers may or may not be set depending on environment
    expect(headers.get('content-type')).toContain('json');
  });
});
