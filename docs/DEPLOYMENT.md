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

## Canary & Blue-Green Deployment

### Blue-Green Strategy

Maintain two identical environments (blue = live, green = standby).

```bash
# Blue is live (api.bloodconnect.app), green is staging
# 1. Deploy green:
docker compose -f docker-compose.yml -f docker-compose.scale.yml up -d --build

# 2. Smoke-test green:
curl -f https://staging-api.bloodconnect.app/health/db

# 3. Run E2E suite against green:
cd api-backend && npm run test:e2e

# 4. Swap DNS / load balancer to point production traffic to green
#    (e.g., update Render service, AWS ALB target group, or k8s service selector)

# 5. Monitor for 15 min (error rate, latency, SLO violations)
#    Rollback = swap DNS back to blue if violations spike

# 6. Keep blue running for 24h in case quick rollback is needed
```

**Readiness gates before promoting:**
- Health check (`/health/db`) returns 200
- SLO endpoint (`/slo`) shows no violations
- E2E smoke tests pass against the new environment
- Error rate < 1% over 5-minute window

### Canary Strategy (Render / Kubernetes)

Route a small percentage of traffic to the new version before full cutover:

| Step | Traffic % | Duration | Verification |
|------|-----------|----------|-------------|
| 1. Deploy canary | 5% | 10 min | Error rate < SLO threshold |
| 2. Increase canary | 25% | 15 min | p95 latency < 2000ms |
| 3. Increase canary | 50% | 15 min | No SLO violations |
| 4. Full rollout | 100% | — | Monitor 30 min |

**Rollback triggers (any of these):**
- Error rate spikes > 5% in 1-minute window
- p95 latency exceeds 5000ms
- Availability drops below 99%
- Any P1 SLO violation

### Rollback Procedure

```bash
# Option A: Revert to previous Docker image
docker tag bloodconnect-api:stable bloodconnect-api:latest
docker compose up -d --no-build

# Option B: Revert Git + rebuild
git revert HEAD --no-edit
docker compose up --build -d --force-recreate
```

To pre-tag images before each release:
```bash
docker tag bloodconnect-api:$IMAGE_TAG bloodconnect-api:stable
docker tag bloodconnect-notification:$IMAGE_TAG bloodconnect-notification:stable
docker tag bloodconnect-ai:$IMAGE_TAG bloodconnect-ai:stable
```

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

## Alternative: Hugging Face Spaces (AI service only)

> **Secondary / demo deployment target.** Render remains the primary
> production deployment for all four services. This Space exists solely
> to demonstrate multi-cloud portability of the AI service.

A `huggingface-space/` directory at the repo root contains a Dockerfile and
README for deploying the AI service on Hugging Face Spaces with the Docker
SDK. The Dockerfile COPYs directly from the existing `ai-service/` source
directory — there is no duplicated application code.

**Target tier:** CPU free tier (default). The Dockerfile installs CPU-only
PyTorch wheels from `ai-service/requirements.txt`. GPU inference would
require a paid HF Spaces GPU tier and a separate requirements file; this
config does not assume GPU access.

**Manual setup steps:**

1. Create a Space at https://huggingface.co/new-space with **SDK = Docker**.
   Name it e.g. `bloodconnect-ai`.
2. Add a Hugging Face access token with **write** permission as a repository
   secret named `HF_TOKEN` in the GitHub repo settings (Settings → Secrets
   and variables → Actions).
3. Run the **Deploy AI Service to Hugging Face Spaces** workflow from
   GitHub Actions (`workflow_dispatch`), providing the Space name and your
   HF username/organization.
4. Verify the deployment:
   ```bash
   curl https://huggingface.co/spaces/<user>/<space>/health
   # → {"status":"healthy"}
   ```

The workflow is defined in `.github/workflows/hf-deploy.yml` and is
triggered manually only — it does NOT run on every push to `main`.
