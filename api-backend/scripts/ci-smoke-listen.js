/**
 * Lightweight HTTP listener for CI E2E smoke tests.
 * Uses NODE_ENV=test so Firebase/DB startup checks are skipped; routes still respond.
 */
process.env.NODE_ENV = 'test';

const http = require('http');
const app = require('../src/server');

const port = parseInt(process.env.PORT || '8090', 10);
const host = process.env.HOST || '127.0.0.1';

const server = http.createServer(app).listen(port, host, () => {
  console.log(`CI smoke server listening on http://${host}:${port}`);
});

function shutdown(signal) {
  console.log(`Shutting down CI smoke server (${signal})`);
  server.close(() => process.exit(0));
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
