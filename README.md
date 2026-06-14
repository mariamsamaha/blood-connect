# BloodConnect

**Connect Donors. Save Lives.**

BloodConnect is a mobile application that bridges the gap between blood donors and patients in need — enabling fast, location-aware blood donation requests with real-time matching and hospital verification.

---

## Problem

In emergencies (surgeries, accidents, critical illnesses), finding a compatible blood donor quickly is a challenge. Current approaches rely on social media, personal contacts, or hospital phone calls — all unreliable, slow, and limited in reach.

## Solution

BloodConnect provides instant blood requests with automatic donor matching via PostGIS, push notifications to nearby eligible donors, hospital verification for secure donations, and role-based access (Donor, Recipient, Hospital).

---

## Architecture

```
┌──────────────┐     HTTP      ┌──────────────────┐     SQL      ┌──────────────┐
│  Flutter App  │ ──────────▶  │  api-backend BFF  │ ──────────▶  │   Supabase   │
│  (Mobile)     │ ◀──────────  │  (Express.js)     │ ◀──────────  │  (PostgreSQL)│
└──────────────┘              └────────┬─────────┘              └──────────────┘
                                       │
                                       │ HTTP (internal secret)
                                       ▼
                              ┌──────────────────┐      ┌──────────────────┐
                              │ notification-     │      │   ai-service     │
                              │ backend (FCM)     │      │  (FastAPI)       │
                              └──────────────────┘      └──────────────────┘
```

| Component | Role | Tech | Port |
|-----------|------|------|------|
| **Flutter App** | Mobile UI, offline cache, push registration | Dart / Riverpod | — |
| **api-backend** | Auth, validation, business logic, metrics, health | Node.js / Express | 8090 |
| **notification-backend** | FCM push dispatch with circuit breaker | Node.js / Express | 8080 |
| **ai-service** | Donor deferral prediction (AI) | Python / FastAPI | 8000 |
| **Supabase** | Data storage, PostGIS, RLS, stored procedures | PostgreSQL | 5432 |

See [Architecture](docs/ARCHITECTURE.md) for design decisions, trade-offs, failure modes, bottlenecks, and transaction handling.

---

## Tech Stack

| Category | Technology |
|----------|------------|
| **Mobile** | Flutter (Dart), Riverpod, GoRouter |
| **API Backend** | Node.js, Express, pg, pino, prom-client |
| **Notification Backend** | Node.js, Express, firebase-admin |
| **AI Service** | Python, FastAPI, scikit-learn, OpenRouter |
| **Database** | Supabase (PostgreSQL + PostGIS) |
| **Auth** | Firebase Auth (Google OAuth) |
| **Push** | Firebase Cloud Messaging |
| **Cache** | Isar (embedded NoSQL), in-memory TTL |
| **Infrastructure** | Docker Compose, GitHub Actions |

---

## Features

### Roles

| Role | Capabilities |
|------|-------------|
| **Donor** | View nearby requests by blood type + location, accept/decline, active mission with verification code, donation history, leaderboard, reward badges |
| **Recipient** | Create requests with urgency levels, auto-generated 4-digit code, real-time status tracking, edit/cancel requests |
| **Hospital** | Admin login via email domain, 4-digit code search, donation verification, audit trail, inventory logging |

### Core flows

```
Onboarding → Sign-in (Google) → Role selection
  ├── Recipient: Create request → GPS → 4-digit code → Share with donor
  ├── Donor: Receive push → View nearby → Accept → Verify at hospital
  └── Hospital: Search by code → Verify donation → Mark fulfilled
```

See [User Flow](#user-flow) for the full diagram.

---

## Project Structure

```
blood-connect/
├── lib/                    # Flutter app
│   ├── screens/            # UI screens (donor, recipient, hospital)
│   ├── services/           # API client, cache, sync, mutation queue
│   ├── repositories/       # cacheFirst<T> repository layer
│   ├── models/             # Data models
│   ├── widgets/            # Reusable widgets
│   ├── routing/            # GoRouter + role-based routing
│   └── theme/              # App theme, colors, spacing
├── api-backend/            # Express API BFF
│   ├── src/
│   │   ├── server.js       # Main server (routes, middleware, startup)
│   │   ├── cluster.js      # Multi-core cluster launcher
│   │   ├── db.js           # PostgreSQL pool + query with metrics
│   │   ├── logger.js       # Pino structured logger
│   │   ├── metrics.js      # Prometheus metrics
│   │   ├── circuit-breaker.js  # Circuit breaker for FCM
│   │   ├── swagger.js      # OpenAPI 3.0 spec
│   │   ├── trace.js        # Distributed tracing middleware
│   │   ├── slo.js          # SLO monitoring
│   │   └── auth.js         # Firebase auth middleware
│   └── tests/              # Jest test suites
├── notification-backend/   # FCM notification service
├── ai-service/             # FastAPI AI prediction service
├── load-tests/             # k6 + Node.js benchmark scripts
├── database/               # SQL schema, migrations, functions
├── docs/                   # All documentation
├── docker-compose.yml      # One-command startup
└── test/                   # Flutter test files
```

---

## Production-Grade Features

### Observability

| Feature | Endpoint / Tool | Description |
|---------|----------------|-------------|
| **Metrics** | `GET /metrics` | Prometheus: request count/duration/in-flight, DB query duration, pool size, circuit breaker state |
| **SLO** | `GET /slo` | Rolling 1h/24h windows: availability, p95/p99 latency, error rate, violation alerts |
| **Health** | `GET /` and `GET /health/db` | Service status + DB connectivity check |
| **Logging** | pino (JSON) | Structured logs with `traceId`/`spanId` bindings per request, secret redaction |
| **Tracing** | `x-trace-id` / `x-span-id` | Trace propagation across services |
| **API Docs** | `GET /api/docs/` and `GET /api/docs.json` | OpenAPI 3.0 interactive documentation |

### Reliability

| Feature | Description |
|---------|-------------|
| **Circuit breaker** | Trips on repeated FCM failures, falls back to logging, auto-recovers |
| **Retry with backoff** | 3 retries, exponential backoff + jitter for notification dispatch |
| **Cluster mode** | Forks one worker per CPU in production, auto-restarts dead workers |
| **Rate limiting** | 200 req/min global, 60 req/min per authenticated user |
| **Graceful shutdown** | Drains HTTP connections, closes DB pool on SIGTERM/SIGINT, 10s timeout |
| **DB timeouts** | Statement 10s, query 12s, connection 5s — prevents hung requests |

### Performance

| Metric | Single worker | Cluster (4 workers, estimated) |
|--------|---------------|-------------------------------|
| Health check RPS | 695 | ~2500-2800 |
| Metrics RPS | 495 | ~2000 |
| OpenAPI JSON RPS | 1427 | ~5000-6000 |
| p95 latency (health) | 41ms | — |
| p99 latency (health) | 46ms | — |

Full benchmark results in [Benchmark](docs/BENCHMARK.md).

### API Versioning

URL path versioning (`/api/v1/`). Backward-compatible changes don't bump versions. Breaking changes get a new path; old versions deprecated for 90+ days. See [API Versioning](docs/API_VERSIONING.md).

---

## Testing

| Test suite | Count | How to run |
|-----------|-------|------------|
| API backend (Jest) | 32 | `cd api-backend && npm test` |
| Notification backend (Jest) | 8 | `cd notification-backend && npm test` |
| Flutter (Dart) | 311 | `flutter test` |
| E2E | 20+ | `cd api-backend && npx jest tests/e2e/` |
| Edge cases | 14 | `cd api-backend && npx jest tests/edge-cases.test.js` |
| Load (k6) | — | `k6 run load-tests/health-check.js` |
| Load (Node) | — | `node load-tests/benchmark.js` |

Coverage includes: unit, integration, E2E, edge cases (large payload, SQL injection, path traversal, malformed JSON, invalid blood types, negative coordinates), failure cases (DB down, FCM down, circuit breaker open), and load/performance.

---

## Setup

### Prerequisites

- Flutter SDK (latest stable)
- Node.js 20+
- Supabase project (free tier)
- Firebase project (free tier)
- Docker (optional, for Compose)

### Quick start (Docker)

```bash
cp api-backend/.env.example api-backend/.env
# fill in SUPABASE_HOST, SUPABASE_USERNAME, SUPABASE_DB_PASSWORD, FIREBASE_PROJECT_ID
docker compose up --build -d
```

### Manual start

```bash
# Terminal 1: API backend
cd api-backend
cp .env.example .env   # fill in credentials
npm install
npm start               # http://localhost:8090

# Terminal 2: Notification backend
cd notification-backend
npm install
npm start               # http://localhost:8080

# Terminal 3: Flutter app
flutter pub get
flutter run
```

See [Deployment](docs/DEPLOYMENT.md) for production deployment and rollback procedures.

### Firebase setup

1. Create Firebase project, enable Google Sign-In and Cloud Messaging
2. Download service account JSON → save as `keys/firebase-adminsdk.json` and set `GOOGLE_APPLICATION_CREDENTIALS` in `.env`
3. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) into the Flutter project

### Database setup

1. Create Supabase project, enable PostGIS extension
2. Run `database/bloodconnect_schema.sql` → `database/mvp_incremental.sql` → `supabase/migrations/20250519000000_enable_rls.sql`

---

## Documentation

| Document | Contents |
|----------|----------|
| [Architecture](docs/ARCHITECTURE.md) | Design decisions, trade-offs, component responsibilities, failure modes, bottlenecks, optimizations |
| [API Versioning](docs/API_VERSIONING.md) | Versioning strategy, deprecation policy, migration guide |
| [Deployment](docs/DEPLOYMENT.md) | Deployment steps, rollback strategy, configuration table, health check verification |
| [CD Pipeline](docs/CD.md) | GitHub Actions CD, GHCR images, Render/Fly deploy hooks, secrets setup |
| [SLA & Metrics](docs/SLA.md) | Target availability (99.5%), latency SLOs, error budget, incident response, alert thresholds |
| [Cost Analysis](docs/COST_ANALYSIS.md) | Monthly cost estimates by usage tier ($30–200/mo), most expensive components |
| [Benchmark](docs/BENCHMARK.md) | Measured RPS, p50/p95/p99 latency per endpoint, scaling estimates |
| [Security](docs/SECURITY.md) | Secrets management, RLS policies, auth architecture |
| [Data Handling](docs/DATA_HANDLING.md) | Data inventory, PII fields, retention, third-party data sharing, RLS testing |
| [Privacy Policy](docs/PRIVACY_POLICY.md) | End-user privacy policy |

---

## CI/CD

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| [BloodConnect CI](.github/workflows/ci.yml) | Push/PR to `main`, `develop` | Flutter (330+ tests), API (50 tests), E2E smoke, Docker builds, secret scan |
| [BloodConnect CD](.github/workflows/cd.yml) | After CI passes on `main`, or manual | Publish images to GHCR, deploy via Render/Fly hooks |

GitHub Actions CI runs on every push:
1. **Flutter** — analyze, 330+ tests, coverage
2. **API Backend** — syntax check, 50 tests, E2E smoke (no secrets required)
3. **API E2E live** — optional, runs when Supabase/Firebase secrets are configured
4. **Notification Backend** — syntax check, 8 tests
5. **AI Service** — pytest unit tests
6. **Docker** — matrix build for all 4 service images
7. **Compose** — validate docker-compose files
8. **Secret scan** — gitleaks full history scan

CD publishes Docker images and triggers deployment. See [CD Guide](docs/CD.md) for required secrets and Render/Fly setup.

---

## Cost Awareness

| Tier | Monthly cost | Peak users |
|------|-------------|------------|
| Low usage | ~$30/mo | 500 |
| Medium usage | ~$80/mo | 5,000 |
| High usage | ~$200/mo | 50,000 |

Most expensive component: AI GPU instance ($50-150/mo). Full breakdown in [Cost Analysis](docs/COST_ANALYSIS.md).

---

## Security

- **Flutter** → **API BFF** only (no database password in the mobile app)
- **API BFF** holds `SUPABASE_DB_PASSWORD` and enforces authorization server-side
- Firebase ID tokens verified on every API request via Firebase Admin SDK
- Row-Level Security (RLS) on all Supabase tables
- Secrets stored in `.env` files, never committed (gitignored)
- Internal endpoints protected with shared secret (`NOTIFICATION_BACKEND_SECRET`)

---

## License & Legal

- [MIT License](LICENSE)
- [Privacy Policy](docs/PRIVACY_POLICY.md)
- [Data Handling](docs/DATA_HANDLING.md)
- [Security & Secrets](docs/SECURITY.md)

[![CI](https://github.com/mariamsamaha/blood-connect/actions/workflows/ci.yml/badge.svg)](https://github.com/mariamsamaha/blood-connect/actions/workflows/ci.yml)
