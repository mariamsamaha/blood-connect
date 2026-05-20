# Data handling reference (engineering)

## Data inventory

### `users`
- **PII:** name, email, phone, location (geography), `fcm_token`
- **Sensitivity:** blood type, role, donor status
- **Retention:** life of account
- **Deletion:** remove row by `firebase_uid` on account deletion request; null `fcm_token` on sign-out

### `blood_requests`
- **PII:** patient name, contact phone, description (optional), requester/recipient locations
- **Retention:** historical requests kept for audit; cancel sets `status = cancelled`
- **Visibility:** requester, assigned hospital, donors see active matches in radius

### `donor_responses`
- Links donor to request; hospital sees donor name/phone after accept
- **Retention:** kept with request lifecycle

### `donations`
- Confirmed donations after hospital verification
- **Visibility:** donor (own history), verifying hospital

### `request_audit_log`
- Event type, detail text, actor user id, timestamp
- **Retention:** recommend ≥ 1 year for hospital compliance; document in ops runbook

### `hospital_inventory` / `inventory_delivery_log`
- Hospital operational data; not end-user PII except hospital staff actions in logs

## Processing flows

```
Sign-in (Firebase) → API BFF (Firebase ID token) → Postgres
Location update → PATCH /users/me/location → users.location
Create request → POST /requests → blood_requests + server-triggered FCM via notification-backend
```

Push notifications: API BFF queries eligible `fcm_token` values server-side; tokens are never exposed to other clients.

## Third parties

| Provider | Data shared |
|----------|-------------|
| Firebase Auth | Email, name, Google ID |
| Firebase Cloud Messaging | Device token, notification payload |
| Supabase | All application data at rest (Postgres) |
| Google Sign-In | OAuth tokens (handled by Firebase) |

## RLS testing checklist

After applying `supabase/migrations/20250519000000_enable_rls.sql`:

1. **Donor** cannot `SELECT` another user's row (except leaderboard policy).
2. **Recipient** cannot update another user's `blood_requests`.
3. **Hospital** cannot verify requests for a different `hospital_id`.
4. **Anonymous** role has no direct table access (API uses service role).

Test with Supabase SQL using `SET request.jwt.claims` or via API integration tests.

## Incident response

1. Rotate `SUPABASE_DB_PASSWORD` and `INTERNAL_SECRET`.
2. Revoke compromised Firebase service account keys.
3. Invalidate sessions (Firebase) if auth breach suspected.
4. Review `request_audit_log` for affected request IDs.
