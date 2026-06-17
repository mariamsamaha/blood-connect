'use strict';

module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/tests/e2e/**/*.test.js'],
  testTimeout: 30000,
  collectCoverage: false,
  reporters: ['default'],
  verbose: true,
};
