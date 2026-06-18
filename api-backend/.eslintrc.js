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
  plugins: [
    'security',
    'node',
  ],
  extends: [
    'eslint:recommended',
    'plugin:security/recommended-legacy',
    'plugin:node/recommended',
  ],
  rules: {
    // ── Security ──────────────────────────────────────────────────────────
    'security/detect-object-injection':        'off',
    'security/detect-non-literal-regexp':      'error',
    'security/detect-non-literal-require':     'error',
    'security/detect-possible-timing-attacks': 'warn',
    'security/detect-child-process':           'error',
    'security/detect-eval-with-expression':    'error',
    'security/detect-pseudoRandomBytes':       'error',
    'security/detect-unsafe-regex':            'error',
    'security/detect-new-buffer':              'error',
    'security/detect-non-literal-fs-filename': 'off',

    // ── Node.js ───────────────────────────────────────────────────────────
    'node/no-deprecated-api':     'error',
    'node/no-extraneous-require': 'error',
    'node/no-missing-require':    'error',
    'no-process-exit':            'error',

    // ── Code quality ──────────────────────────────────────────────────────
    'no-unused-vars': ['error', {
      argsIgnorePattern: '^_',
      varsIgnorePattern: '^_',
    }],
    'no-console':          ['warn', { allow: ['error', 'warn'] }],
    'handle-callback-err': 'error',
    'eqeqeq':              ['error', 'smart'],
    'no-var':              'error',
    'prefer-const':        'error',
    'require-await':       'warn',
    'no-dupe-keys':        'error',
    'no-unreachable':      'error',
  },

  overrides: [
    {
      files: ['src/cluster.js', 'src/server.js', 'database/migrate.js'],
      rules: {
        'no-process-exit': 'off',
      },
    },
    {
      files: ['src/routes/*.js'],
      rules: {
        'node/no-unsupported-features/es-syntax': 'off',
      },
    },
    {
      files: ['tests/**/*.js'],
      rules: {
        'security/detect-non-literal-require': 'off',
        'security/detect-object-injection':    'off',
        'no-console':                          'off',
        'no-unused-vars':                      'off',
        'node/no-extraneous-require':          'off',
        'node/no-unpublished-require':         'off',
        'require-await':                       'off',
      },
    },
    {
      files: ['scripts/**/*.js'],
      rules: {
        'no-console':      'off',
        'no-process-exit': 'off',
      },
    },
  ],

  ignorePatterns: [
    'node_modules/',
    'coverage/',
    'dist/',
  ],
};
