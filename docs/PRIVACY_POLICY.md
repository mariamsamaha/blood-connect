# BloodConnect Privacy Policy

**Last updated:** May 2026  
**Contact:** privacy@bloodconnect.app

## Overview

BloodConnect connects blood donors, recipients, and hospitals. This policy describes what we collect, why, and your choices.

## Data we collect

| Data | Purpose | Stored where |
|------|---------|--------------|
| Name, email, phone | Account and contact for donations | PostgreSQL (Supabase) |
| Google account (via Firebase Auth) | Sign-in; `firebase_uid` links your profile | Firebase + our database |
| Blood type, donor/recipient role | Matching requests | PostgreSQL |
| GPS location (with permission) | Nearby hospitals and donor matching | PostgreSQL (PostGIS) |
| FCM device token | Push notifications for nearby requests | PostgreSQL |
| Hospital affiliation & verification | Hospital admin workflows | PostgreSQL |
| Donation / request history, audit logs | Safety, verification, compliance | PostgreSQL |
| AI eligibility inputs (optional feature) | Model inference only; not a medical diagnosis | AI service (if enabled) |

## How we use data

- Match recipients with hospitals and eligible donors by location and blood type.
- Send push notifications to donors who opted in and are within their notification radius.
- Allow hospitals to verify donations using request codes.
- Maintain an audit trail for hospital accountability.

We do **not** sell personal data.

## Who can see your data

| Role | Access |
|------|--------|
| You | Your profile, requests, donation history, badges |
| Donors | Active requests in range (hospital name, blood type, urgency—not full recipient medical records unless shared in the request) |
| Recipients | Their own requests and status |
| Hospitals | Requests at their facility, assigned donor contact when a donor has accepted, inventory and audit for their hospital |
| Operators | Server logs and database access restricted to infrastructure admins |

Access is enforced in the API layer and by database Row Level Security policies.

## Retention

- Active accounts: data retained while the account is used.
- Cancelled requests: status updated; audit entries may be retained for operational records.
- FCM tokens: cleared when invalid or on sign-out (best effort).
- **Recommended:** define account deletion in product policy (e.g. 30 days after deletion request); implement via support until automated erasure is available.

## Your rights

Depending on your region you may request access, correction, or deletion of your data. Contact us at the address above.

## Location

Location is collected only when you grant permission and is used for matching. You can disable location in device settings; some features may not work.

## Children

BloodConnect is not directed at children under 13 (or applicable local age). Do not register if you are under the required age.

## Changes

We may update this policy; material changes will be noted in the app or repository.
