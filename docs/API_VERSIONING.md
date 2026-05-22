# API Versioning Strategy

## Current Version: v1

BloodConnect uses **URL path versioning** (`/api/v1/`).

## Versioning Rules

1. **Backward-compatible changes** (add field, add endpoint) — no version bump.
2. **Breaking changes** (rename field, change response shape, remove endpoint) — new version.
3. **New versions** are published at `/api/v{n+1}/`.
4. **Old versions** remain available for a minimum of **90 days** after the new version is published.

## Deprecation Policy

| Phase | Action | Timeline |
|-------|--------|----------|
| Announce | Deprecation header added to old version responses | Day 0 |
| Warning | `Sunset` header added with removal date | Day 30 |
| Soft removal | Old version returns 410 Gone for all requests | Day 90 |
| Hard removal | Old version route removed from server | Day 120 |

### Response headers during deprecation

```
Deprecation: true
Sunset: Sat, 22 Aug 2026 00:00:00 GMT
Link: </api/v2/requests>; rel="successor-version"
```

## How to Version

1. Copy the current version's route file to `routes/v{n+1}/`.
2. Update the route prefix from `/api/v1/` to `/api/v{n+1}/`.
3. Make breaking changes in the new file.
4. Add a deprecation header middleware to the old version routes.

## Request Flow

```
Client → /api/v1/users/me   → auth middleware → v1 route handler
Client → /api/v2/users/me   → auth middleware → v2 route handler
```

Both versions share the same auth middleware and database. They differ only in request/response shapes.
