const pino = require('pino');

const isProduction = process.env.NODE_ENV === 'production';
const LOG_LEVEL = process.env.LOG_LEVEL || (isProduction ? 'info' : 'debug');

const logger = pino({
  level: LOG_LEVEL,
  transport: isProduction
    ? undefined
    : {
        target: 'pino-pretty',
        options: {
          colorize: true,
          translateTime: 'SYS:yyyy-mm-dd HH:MM:ss.l',
          ignore: 'pid,hostname',
        },
      },
  redact: {
    paths: ['req.headers.authorization', 'req.headers["x-internal-secret"]'],
    censor: '[REDACTED]',
  },
});

module.exports = logger;
