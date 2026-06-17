# Team roles & responsibilities

## Contributors

| Person | Role | Areas |
|--------|------|-------|
| @mariamsamaha | Lead Developer | Architecture, API backend, Flutter, AI service, deployment |
| @MME517 | Developer | Flutter UI, notification backend, testing |
| @retalali16 | Developer | API backend, AI service, database, matching logic |

## Responsibilities

| Area | Primary | Secondary |
|------|---------|-----------|
| Flutter app (`lib/`, `test/`) | @mariamsamaha | @MME517 |
| API backend (`api-backend/`) | @mariamsamaha | @retalali16 |
| AI service (`ai-service/`) | @retalali16 | @mariamsamaha |
| Notification backend (`notification-backend/`) | @MME517 | @mariamsamaha |
| Database (`database/`, `supabase/`) | @mariamsamaha | @retalali16 |
| Infrastructure (Docker, CI/CD) | @mariamsamaha | — |
| Gateway (`gateway/`) | @mariamsamaha | — |
| Documentation (`docs/`) | @mariamsamaha | All |

## Code review expectations

- Every PR needs at least one approval from a secondary owner of the area
- Infrastructure changes require @mariamsamaha review
- No direct pushes to `main` — all changes via PR

## Communication

- Issues and PRs for all technical discussion
- Tag the relevant primary owner for each area
- For urgent production issues, contact the primary on-call (rotating weekly)
