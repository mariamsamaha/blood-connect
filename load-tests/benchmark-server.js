/**
 * Benchmark server — starts api-backend without DB dependency.
 * Run: node load-tests/benchmark-server.js
 */
process.env.NODE_ENV = 'test';
process.env.SUPABASE_REQUIRE_SSL = 'false';
process.env.FIREBASE_PROJECT_ID = 'benchmark';
process.env.GOOGLE_APPLICATION_CREDENTIALS = '';
process.env.NOTIFICATION_BACKEND_URL = 'http://localhost:18080';

const app = require('../api-backend/src/server');
const http = require('http');

const PORT = parseInt(process.env.BENCHMARK_PORT || '8099', 10);
const server = http.createServer(app).listen(PORT, '127.0.0.1', () => {
  console.log(`Benchmark server listening on http://127.0.0.1:${PORT}`);
});

module.exports = server;
