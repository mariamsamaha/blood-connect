# Continuous Deployment (CD)

BloodConnect CD publishes Docker images to **GitHub Container Registry (GHCR)** and optionally triggers deploy hooks on **Render** or **Fly.io**.

## Pipeline overview

```
Push/merge to main
       │
       ▼
  BloodConnect CI  ──(must pass)──▶  BloodConnect CD
                                         │
                    ┌────────────────────┼────────────────────┐
                    ▼                    ▼                    ▼
              Build & push           Deploy hooks         Post-deploy
              4 images to GHCR       (Render/Fly)         health checks
```

Manual deploy: **Actions → BloodConnect CD → Run workflow**

## Published images

After a successful CD run, images are available at:

| Service | Image |
|---------|-------|
| API BFF | `ghcr.io/<owner>/bloodconnect-api:<sha>` |
| Notification | `ghcr.io/<owner>/bloodconnect-notification:<sha>` |
| AI service | `ghcr.io/<owner>/bloodconnect-ai:<sha>` |
| Gateway | `ghcr.io/<owner>/bloodconnect-gateway:<sha>` |

Tags:
- `<git-sha>` — immutable, always set
- `staging` or `production` — environment tag
- `latest` — only on production deploys

Make packages public (for graduation demos): **GitHub → Packages → bloodconnect-api → Package settings → Change visibility**.

## GitHub configuration

### Repository secrets (Settings → Secrets and variables → Actions)

| Secret | Required | Purpose |
|--------|----------|---------|
| `RENDER_DEPLOY_HOOK_API` | No | Render deploy hook URL for API service |
| `RENDER_DEPLOY_HOOK_NOTIFICATION` | No | Render deploy hook for notification backend |
| `RENDER_DEPLOY_HOOK_AI` | No | Render deploy hook for AI service |
| `FLY_API_TOKEN` | No | Fly.io API token for `flyctl deploy` |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | No | Full JSON for optional CI live E2E job |
| `SUPABASE_HOST` | No | Staging DB host for CI live E2E |
| `SUPABASE_USERNAME` | No | Staging DB user |
| `SUPABASE_DB_PASSWORD` | No | Staging DB password |
| `SUPABASE_DATABASE` | No | Default `postgres` |
| `FIREBASE_PROJECT_ID` | No | Firebase project for CI live E2E |

### Repository variables (Settings → Secrets and variables → Actions → Variables)

| Variable | Example | Purpose |
|----------|---------|---------|
| `DEPLOYED_API_URL` | `https://bloodconnect-api.onrender.com` | Post-deploy smoke checks |
| `FLY_APP_API` | `bloodconnect-api` | Fly.io app name (if using Fly) |

### Environments (recommended)

Create two environments under **Settings → Environments**:

1. **staging** — auto-deploy from `main` after CI
2. **production** — require manual approval before deploy

Assign the `deploy` job environment in `cd.yml` already uses `${{ needs.gate.outputs.environment }}`.

## Render setup (recommended for graduation)

1. Create three **Web Services** on [Render](https://render.com):
   - API — Docker, context `api-backend/`
   - Notification — Docker, context `notification-backend/`
   - AI — Docker, context `ai-service/`

2. Or use the blueprint:

```bash
# In Render Dashboard → New → Blueprint → connect repo
# Uses render.yaml at repo root
```

3. Set environment variables on each service (from `.env.compose.example`).

4. Copy each service's **Deploy Hook** URL into GitHub secrets:
   - `RENDER_DEPLOY_HOOK_API`
   - `RENDER_DEPLOY_HOOK_NOTIFICATION`
   - `RENDER_DEPLOY_HOOK_AI`

5. Set `DEPLOYED_API_URL` variable to your API service URL.

## Fly.io setup (alternative)

```bash
# One-time per service
cd api-backend && fly launch --no-deploy
fly secrets set SUPABASE_HOST=... SUPABASE_DB_PASSWORD=... FIREBASE_PROJECT_ID=...
```

Set `FLY_API_TOKEN` secret and `FLY_APP_API` variable in GitHub.

## Manual deploy

```bash
# Images only (no hosting hooks)
gh workflow run cd.yml -f environment=staging -f skip_deploy_hooks=true

# Full staging deploy
gh workflow run cd.yml -f environment=staging

# Production (requires environment approval if configured)
gh workflow run cd.yml -f environment=production
```

## Rollback

```bash
# Redeploy a previous image tag
docker pull ghcr.io/<owner>/bloodconnect-api:<previous-sha>
# Trigger Render rollback in dashboard, or:
gh workflow run cd.yml -f environment=production
# after reverting main to the previous commit
```

## CI enhancements (same repo)

The updated `ci.yml` also includes:

| Job | What it does |
|-----|----------------|
| `api-e2e-smoke` | Runs E2E tests against a local smoke server (no secrets) |
| `api-e2e-live` | Optional E2E against real Supabase when secrets are set |
| `docker-build` | Matrix build for all 4 Docker images |
| `compose-validate` | Validates all docker-compose files |
| `ci-success` | Gate job — all required checks must pass |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| CD doesn't run after merge | Ensure CI workflow name is exactly `BloodConnect CI` and branch is `main` |
| GHCR push denied | Check `packages: write` permission in `cd.yml`; repo must allow GITHUB_TOKEN package write |
| Deploy hook 404 | Regenerate hook URL in Render dashboard |
| Post-deploy health fails | Set `DEPLOYED_API_URL` without trailing slash; verify Supabase env on host |
| Live E2E skipped | Add `SUPABASE_HOST` + `FIREBASE_SERVICE_ACCOUNT_JSON` secrets |
