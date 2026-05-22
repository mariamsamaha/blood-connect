# Service Level Agreement (SLA) & Production Metrics

## Target Availability (SLO)

| Component | Target Availability | Monthly Allowed Downtime |
|-----------|-------------------|------------------------|
| API Backend | 99.5% (two nines) | ~3.6 hours/month |
| Notification Backend | 99.0% | ~7.3 hours/month |
| AI Service | 95.0% | ~36 hours/month |
| Database (Supabase) | 99.9% (upstream) | ~43 minutes/month |

## Acceptable Latency

| Endpoint Category | p50 Target | p95 Target | p99 Target |
|-------------------|-----------|-----------|-----------|
| Health checks (`/`, `/health/db`) | <100ms | <500ms | <1s |
| Authenticated reads (users, hospitals) | <200ms | <1s | <2s |
| Authenticated writes (create request) | <500ms | <2s | <3s |
| Donor matching (PostGIS query) | <300ms | <1.5s | <3s |
| AI prediction | <10s | <30s | <60s |
| Push notification dispatch | <2s | <5s | <10s |

## Error Budget (Monthly)

Based on 99.5% API availability:
- **Total requests:** ~500,000 (estimated)
- **Allowed errors:** ~2,500 (0.5%)
- **Budget consumed by:** 5xx errors, timeouts, infrastructure failures

## Monitoring & Alerting

### Health Check Endpoints
- `GET /` — basic service health
- `GET /health/db` — database connectivity + pool stats
- `GET /health` (AI service) — model loaded status

### Key Metrics to Collect
- **Request rate** (RPS per endpoint)
- **Error rate** (5xx / total)
- **Latency percentiles** (p50, p95, p99)
- **Database pool stats** (total, idle, waiting connections)
- **Cache hit rates** (memory L1, persistent L2, stale hits)
- **Mutation queue** (pending, dead-letter count)
- **AI prediction** (success/fail rate, processing time)

### Alert Thresholds (Suggested)
- Error rate > 5% over 5 minutes → P1 alert
- p95 latency > 3s over 5 minutes → P2 alert
- Database pool exhaustion (>80% utilized) → P2 alert
- AI service unreachable for > 1 minute → P2 alert
- Notification backend unreachable for > 1 minute → P3 alert

## Downtime & Degradation Handling

### Partial Failure (one component down)
- **AI service down:** App shows "AI Service unavailable" banner and suggests manual eligibility check. Core blood request flow continues.
- **Notification backend down:** Requests are created but push notifications are queued or skipped. Logged for investigation.
- **Database degraded:** API returns 503 with latency info. Retry mechanism on client.

### Full Outage
1. **Detect:** Health check monitoring + user reports
2. **Respond:** Rollback last deployment, scale up instances
3. **Communicate:** Status page update, notify team
4. **Resolve:** Fix root cause, deploy fix, verify health
5. **Post-mortem:** Document incident, add regression test

## Incident Response

| Severity | Response Time | Resolution Time | Example |
|----------|--------------|----------------|---------|
| P1 (Critical) | <15 min | <1 hour | API down, data loss |
| P2 (High) | <30 min | <4 hours | High error rate, slow responses |
| P3 (Medium) | <2 hours | <24 hours | Non-critical feature broken |
| P4 (Low) | <1 week | Next sprint | Cosmetic issues, tech debt |

## Rollback Procedure

1. **Docker Compose:** `docker compose down && git checkout <previous-tag> && docker compose up --build -d`
2. **Database:** Run `database/migrations/rollback/<version>.sql` (if applicable)
3. **Verify:** Check health endpoints, run smoke tests, monitor error rate
