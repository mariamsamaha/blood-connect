const Redis = require('ioredis');

const REDIS_URL = process.env.REDIS_URL || '';
const TOKEN_CACHE_TTL_SEC = parseInt(process.env.TOKEN_CACHE_TTL_SEC || '1800', 10); // 30 min default

let client = null;
let enabled = false;

function createClient() {
  if (!REDIS_URL) {
    console.log('Redis: disabled (no REDIS_URL configured)');
    return null;
  }

  const c = new Redis(REDIS_URL, {
    maxRetriesPerRequest: 3,
    retryStrategy(times) {
      if (times > 3) return null;
      return Math.min(times * 200, 2000);
    },
    lazyConnect: true,
  });

  c.on('connect', () => {
    console.log('Redis: connected');
    enabled = true;
  });

  c.on('error', (err) => {
    console.error('Redis: error', err.message);
    enabled = false;
  });

  c.on('close', () => {
    enabled = false;
  });

  return c;
}

async function init() {
  if (client) return client;
  client = createClient();
  if (client) {
    try {
      await client.connect();
    } catch (err) {
      console.error('Redis: connection failed, running without cache', err.message);
      enabled = false;
    }
  }
  return client;
}

function isEnabled() {
  return enabled && client !== null;
}

async function getCachedToken(token) {
  if (!isEnabled()) return null;
  try {
    const val = await client.get(`fb:token:${token}`);
    if (val) return JSON.parse(val);
    return null;
  } catch {
    return null;
  }
}

async function setCachedToken(token, firebaseUser) {
  if (!isEnabled()) return;
  try {
    await client.setex(`fb:token:${token}`, TOKEN_CACHE_TTL_SEC, JSON.stringify(firebaseUser));
  } catch {
    // non-critical
  }
}

async function close() {
  if (client) {
    await client.quit();
    client = null;
    enabled = false;
  }
}

module.exports = {
  init,
  close,
  isEnabled,
  getCachedToken,
  setCachedToken,
};
