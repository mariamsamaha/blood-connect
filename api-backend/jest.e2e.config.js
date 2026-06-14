/** Jest config for E2E smoke tests (live HTTP, not supertest mocks). */
module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/tests/e2e/**/*.test.js'],
  testPathIgnorePatterns: [],
  collectCoverage: false,
};
