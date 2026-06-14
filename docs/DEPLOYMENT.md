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
cp .env.compose.example .env
# Edit .env: SUPABASE_*, FIREBASE_PROJECT_ID, NOTIFICATION_BACKEND_SECRET, INTERNAL_SECRET
mkdir -p keys && cp /path/to/firebase-adminsdk.json keys/

export GOOGLE_APPLICATION_CREDENTIALS="/abs/path/to/keys/firebase-adminsdk.json"
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
# Tag a known-good image before each release:
docker tag bloodconnect-api:ci bloodconnect-api:stable

# Roll back to the last tagged image:
docker compose down
docker tag bloodconnect-api:stable bloodconnect-api:latest
docker compose up -d --no-build
```

## CI/CD Pipeline

| Workflow | File | When |
|----------|------|------|
| CI | `.github/workflows/ci.yml` | Every push/PR |
| CD | `.github/workflows/cd.yml` | After CI passes on `main`, or manual |

The CI pipeline runs:

1. **Flutter** — analyze, 330+ tests, coverage
2. **API Backend** — syntax check, 50 tests, E2E smoke
3. **Notification Backend** — syntax check, 8 tests
4. **AI Service** — pytest unit tests
5. **Docker** — build all service images
6. **Compose** — validate docker-compose files
7. **Secret Scan** — gitleaks full history scan

CD publishes images to GHCR and triggers Render/Fly deploy hooks. See [CD Guide](CD.md).

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
