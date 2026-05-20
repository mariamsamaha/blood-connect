# Security & secrets handling

## Architecture

| Component | Credentials | Notes |
|-----------|-------------|--------|
| Flutter app | Firebase client config, `API_BASE_URL` (public) | No database password in the APK |
| API BFF (`api-backend/`) | `SUPABASE_DB_PASSWORD`, Firebase Admin | Server-only; never commit |
| Notification backend | `INTERNAL_SECRET`, Firebase service account JSON | Server-only |
| AI service | Optional API keys | Dev-only HTTP; production HTTPS |

## Release builds (Flutter)

Do **not** bundle `.env` in release assets. Pass non-secret and public endpoints via CI:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=AI_SERVICE_URL=https://ai.yourdomain.com
```

Debug builds may load `.env` from the project root for local development.

## Secret rotation

| Secret | Where used | Rotation steps |
|--------|------------|----------------|
| `SUPABASE_DB_PASSWORD` | API BFF only | Supabase Dashboard → Database → reset password → update BFF env → redeploy |
| `NOTIFICATION_BACKEND_SECRET` / `INTERNAL_SECRET` | Flutter (optional legacy), API BFF, notification-backend | Generate new value → update all services → redeploy → old secret invalid immediately |
| Firebase service account | notification-backend, API BFF (if used) | Firebase Console → Service accounts → new key → update `GOOGLE_APPLICATION_CREDENTIALS` → delete old key |
| Firebase Web API keys | Client apps | Restrict by package/bundle ID in Google Cloud Console |

## Local development

1. Copy `api-backend/.env.example` → `api-backend/.env`
2. Copy `.env_example` → `.env` (debug only, gitignored)
3. Start API: `cd api-backend && npm install && npm start`
4. Run Flutter with emulator host: default `http://10.0.2.2:8090` (Android) or set `API_BASE_URL`

## HTTPS

Production API and notification services must be served over TLS (reverse proxy or `TLS_KEY_PATH` / `TLS_CERT_PATH` on the API). Mobile apps block cleartext HTTP in release builds; debug allows local HTTP.
