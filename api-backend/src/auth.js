const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const redis = require('./redis');
const logger = require('./logger');
const { query } = require('./db');

function resolveCredentialPath() {
  const envPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const candidates = [];

  if (envPath) {
    candidates.push(
      path.isAbsolute(envPath) ? envPath : path.resolve(process.cwd(), envPath),
    );
    candidates.push(
      path.isAbsolute(envPath) ? envPath : path.resolve(__dirname, '..', envPath),
    );
  }

  const apiRoot = path.resolve(__dirname, '..');
  candidates.push(
    path.join(apiRoot, 'firebase-adminsdk.json'),
  );

  return candidates.find((p) => p && fs.existsSync(p));
}

function resolveCredentials() {
  const credPath = resolveCredentialPath();
  if (credPath) {
    return { serviceAccount: JSON.parse(fs.readFileSync(credPath, 'utf8')), source: credPath };
  }
  const jsonEnv = process.env.FIREBASE_CREDENTIALS_JSON;
  if (jsonEnv) {
    return { serviceAccount: JSON.parse(jsonEnv), source: 'FIREBASE_CREDENTIALS_JSON' };
  }
  return null;
}

function initializeFirebaseAdmin() {
  if (admin.apps.length) return;

  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    throw new Error('FIREBASE_PROJECT_ID environment variable is required');
  }

  const resolved = resolveCredentials();
  if (!resolved) {
    console.error(`
╔══════════════════════════════════════════════════════════════════╗
║  Firebase Admin credentials required for api-backend             ║
╠══════════════════════════════════════════════════════════════════╣
║  Option 1 — Set GOOGLE_APPLICATION_CREDENTIALS pointing to       ║
║            a Firebase Admin SDK JSON file                        ║
║  Option 2 — Set FIREBASE_CREDENTIALS_JSON to the full JSON       ║
║            string (for platforms like Render w/o a filesystem)   ║
╚══════════════════════════════════════════════════════════════════╝
`);
    throw new Error('firebase_admin_credentials_missing');
  }

  const resolvedProject = resolved.serviceAccount.project_id || projectId;

  admin.initializeApp({
    credential: admin.credential.cert(resolved.serviceAccount),
    projectId: resolvedProject,
  });

  logger.info(`Firebase Admin ready (project: ${resolvedProject}, source: ${resolved.source})`);
}

if (process.env.NODE_ENV !== 'test') {
  initializeFirebaseAdmin();
  // Initialize Redis (non-blocking if unavailable)
  redis.init().catch(() => {});
}

async function requireFirebaseAuth(req, res, next) {
  const header = req.headers.authorization || '';
  if (!header.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'missing_token' });
  }
  const token = header.slice(7).trim();
  if (!token) {
    return res.status(401).json({ error: 'missing_token' });
  }

  // Check Redis session cache first
  if (redis.isEnabled()) {
    try {
      const cached = await redis.getCachedToken(token);
      if (cached) {
        req.firebaseUser = cached;
        return next();
      }
    } catch {
      // cache miss — fall through to verification
    }
  }

  try {
    req.firebaseUser = await admin.auth().verifyIdToken(token);
    // Cache the verified result in Redis
    if (redis.isEnabled()) {
      redis.setCachedToken(token, req.firebaseUser).catch(() => {});
    }
    return next();
  } catch (err) {
    console.error(
      'Firebase token verification failed:',
      err.code || 'unknown',
      err.message,
    );
    const isDev = process.env.NODE_ENV !== 'production';
    return res.status(401).json({
      error: 'invalid_token',
      ...(isDev && {
        detail: err.message,
        hint:
          'Ensure GOOGLE_APPLICATION_CREDENTIALS points to the same Firebase project as the Flutter app (bloodconnect-mvp-b605f).',
      }),
    });
  }
}

function requireRole(...allowedRoles) {
  return async (req, res, next) => {
    if (!req.firebaseUser) {
      return res.status(401).json({ error: 'missing_token' });
    }
    try {
      const rows = await query(
        'SELECT id, role FROM users WHERE firebase_uid = $1',
        [req.firebaseUser.uid],
      );
      if (rows.length === 0) {
        return res.status(404).json({ error: 'user_not_found' });
      }
      const { id, role } = rows[0];
      if (!allowedRoles.includes(role)) {
        return res.status(403).json({ error: 'forbidden_role' });
      }
      req.appUser = { id, role };
      return next();
    } catch (err) {
      logger.error({ err }, 'requireRole query failed');
      return res.status(500).json({ error: 'internal_error' });
    }
  };
}

module.exports = { admin, requireFirebaseAuth, requireRole };
