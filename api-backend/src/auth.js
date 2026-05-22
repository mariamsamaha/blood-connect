const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

/** Must match Flutter `firebase_options.dart` / google-services.json */
const DEFAULT_PROJECT_ID = 'bloodconnect-mvp-b605f';

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
  const repoRoot = path.resolve(apiRoot, '..');
  candidates.push(
    path.join(apiRoot, 'firebase-adminsdk.json'),
    path.join(repoRoot, 'keys', 'firebase-adminsdk.json'),
    path.join(repoRoot, 'secrets', 'firebase-adminsdk.json'),
  );

  return candidates.find((p) => p && fs.existsSync(p));
}

function initializeFirebaseAdmin() {
  if (admin.apps.length) return;

  const credPath = resolveCredentialPath();
  const projectId = process.env.FIREBASE_PROJECT_ID || DEFAULT_PROJECT_ID;

  if (!credPath) {
    console.error(`
╔══════════════════════════════════════════════════════════════════╗
║  Firebase Admin credentials required for api-backend             ║
╠══════════════════════════════════════════════════════════════════╣
║  1. Firebase Console → Project settings → Service accounts       ║
║  2. Generate new private key (JSON)                              ║
║  3. Save as keys/firebase-adminsdk.json (gitignored)             ║
║  4. In api-backend/.env set:                                     ║
║     GOOGLE_APPLICATION_CREDENTIALS=../keys/bloodconnect-mvp-b605f-firebase-adminsdk-fbsvc-c292f56d04.json║
║     FIREBASE_PROJECT_ID=bloodconnect-mvp-b605f                   ║
╚══════════════════════════════════════════════════════════════════╝
`);
    throw new Error('firebase_admin_credentials_missing');
  }

  const serviceAccount = JSON.parse(fs.readFileSync(credPath, 'utf8'));
  const resolvedProject = serviceAccount.project_id || projectId;

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: resolvedProject,
  });

  console.log(`Firebase Admin ready (project: ${resolvedProject}, key: ${credPath})`);
}

if (process.env.NODE_ENV !== 'test') {
  initializeFirebaseAdmin();
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

  try {
    req.firebaseUser = await admin.auth().verifyIdToken(token);
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

module.exports = { admin, requireFirebaseAuth, DEFAULT_PROJECT_ID };
