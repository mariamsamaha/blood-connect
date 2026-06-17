'use strict';

module.exports = {
  env: {
    node: true,
    es2022: true,
    jest: true,
  },
  parserOptions: {
    ecmaVersion: 2022,
    sourceType: 'commonjs',
  },
  extends: ['eslint:recommended'],
  rules: {
    'no-unused-vars': ['error', {
      argsIgnorePattern: '^_',
      varsIgnorePattern: '^_',
    }],
    'no-console': ['warn', { allow: ['error', 'warn'] }],
    'eqeqeq': ['error', 'smart'],
    'no-var': 'error',
    'prefer-const': 'error',
    'no-dupe-keys': 'error',
    'no-unreachable': 'error',
  },
  ignorePatterns: ['node_modules/', 'coverage/'],
};
