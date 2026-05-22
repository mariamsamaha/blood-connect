# Deployment Guide

## Architecture

```
Flutter App → API BFF (Express) → Supabase (PostgreSQL + PostGIS)
          ↕                         ↕
    Notification Backend      Firebase Auth/FCM
          ↕
    AI Service (FastAPI)
```

## Deploying the Backends

### Docker Compose (Local / Single Server)

```bash
export NOTIFICATION_BACKEND_SECRET="your-secret"
export GOOGLE_APPLICATION_CREDENTIALS="/abs/path/to/firebase-adminsdk.json"
export SUPABASE_HOST="db.supabase.co"
export SUPABASE_USERNAME="postgres"
export SUPABASE_DB_PASSWORD="your-password"

docker compose up --build -d
```

### Individual Services

```bash
# API Backend
cd api-backend
npm ci
npm start

# Notification Backend
cd notification-backend
npm ci
npm start

# AI Service
cd ai-service
pip install -r requirements.txt
python main.py
```

## Configuration

All configuration is via environment variables:

| Variable | Component | Required | Description |
|----------|-----------|----------|-------------|
| `DATABASE_URL` | API | Yes* | Postgres connection string |
| `SUPABASE_HOST` | API | Yes* | Supabase host |
| `SUPABASE_USERNAME` | API | Yes* | Database user |
| `SUPABASE_DB_PASSWORD` | API | Yes* | Database password |
| `FIREBASE_PROJECT_ID` | API, Notif | Yes | Firebase project ID |
| `GOOGLE_APPLICATION_CREDENTIALS` | API, Notif | Yes | Path to Firebase SA JSON |
| `NOTIFICATION_BACKEND_SECRET` | API, Notif | Yes | Shared secret for internal auth |
| `NOTIFICATION_BACKEND_URL` | API | Yes | URL for notification service |
| `AI_ASSISTANT_API_KEY` | AI | No | OpenRouter API key |
| `CORS_ORIGINS` | AI | No | Comma-separated allowed origins |
| `LOG_LEVEL` | All | No | debug/info/warn/error |
| `TLS_KEY_PATH` | API, Notif | No | Path to TLS private key |
| `TLS_CERT_PATH` | API, Notif | No | Path to TLS certificate |

*Either `DATABASE_URL` or all `SUPABASE_*` vars are required.

## Rollback Strategy

### Standard Rollback (Code)

```bash
# 1. Identify the previous working version
git log --oneline -10

# 2. Rollback
git revert HEAD
# or
git checkout <previous-stable-tag>
docker compose up --build -d --force-recreate

# 3. Verify
curl http://localhost:8090/health/db
curl http://localhost:8090/
```

### Database Rollback

```bash
# 1. Restore from Supabase point-in-time recovery (if enabled)
# 2. Or run a rollback migration:
psql "$DATABASE_URL" -f database/migrations/rollback/<version>.sql
```

### Emergency Rollback (if deployment is broken)

```bash
# Pull the last known good image
docker pull bloodconnect-api:stable
docker compose -f docker-compose.rollback.yml up -d
```

## CI/CD Pipeline

The GitHub Actions CI pipeline runs:

1. **Flutter** — analyze, codegen check, 46+ tests, coverage
2. **API Backend** — syntax check, 10+ tests
3. **Notification Backend** — syntax check, 8 tests
4. **AI Service** — pytest unit tests (skipping model-dependent)
5. **Secret Scan** — gitleaks full history scan

## Environment-Specific Config

| Environment | API URL | Database | Notes |
|------------|---------|----------|-------|
| Development | `http://localhost:8090` | Local / Supabase dev | Docker Compose, debug logging |
| Staging | `https://staging-api.bloodconnect.app` | Supabase staging | Mirrors production |
| Production | `https://api.bloodconnect.app` | Supabase production | TLS required, minimal logging |

## Health Checks

After deployment, verify:

```bash
# Basic health
curl http://localhost:8090/
# → {"status":"ok","service":"bloodconnect-api"}

# Database health
curl http://localhost:8090/health/db
# → {"status":"ok","latency_ms":5,"pool":{...}}

# API documentation
curl http://localhost:8090/api/docs.json
# → OpenAPI 3.0 spec

# Notification backend
curl http://localhost:8080/
# → "Notification backend is running"
```
