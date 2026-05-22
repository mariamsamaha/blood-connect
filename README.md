# 🩸 BloodConnect

**Connect Donors. Save Lives.**

BloodConnect is a mobile application designed to bridge the critical gap between blood donors and patients in need. It enables fast, reliable, and location-aware blood donation requests—helping save lives when time matters most.

---

## 📌 Problem Statement

In emergency situations such as surgeries, accidents, or critical illnesses, finding a compatible blood donor quickly is often a challenge. Currently, many people rely on social media posts, personal contacts, or hospital phone calls to find donors. This approach is:

- **Unreliable and unstructured** - No standardized system for matching
- **Time-consuming during emergencies** - Every second counts
- **Limited in reach and visibility** - Only reaches immediate contacts
- **Lacking donor eligibility tracking** - No way to verify donor status

## 💡 Solution

BloodConnect provides:
- **Instant blood requests** with automatic donor matching
- **Location-based matching** using GPS and PostGIS
- **Push notifications** to notify nearby eligible donors
- **Hospital verification** for secure, transparent donations
- **Role-based access** (Donor, Recipient, Hospital)

---

## 🏗️ Tech Stack

| Category | Technology |
|----------|------------|
| **Mobile** | Flutter (Dart) |
| **Backend** | Supabase (PostgreSQL + PostGIS) + API BFF (`api-backend/`) |
| **Authentication** | Firebase Auth (Google OAuth) |
| **Push Notifications** | Firebase Cloud Messaging (FCM) |
| **State Management** | Riverpod |
| **Navigation** | GoRouter |
| **Location** | Geolocator |
| **Persistent Cache** | Isar (embedded NoSQL) |

---

## 🗄️ Caching Architecture

The app uses a **two-tier hybrid cache** for production-grade performance and offline resilience.

```
┌────────────────────────────────────────────────────┐
│                   UI Screens                        │
└──────────────────┬─────────────────────────────────┘
                   │
┌──────────────────▼─────────────────────────────────┐
│         Repository Layer (optional)                 │
│   cacheFirst<T>() pattern + stale-while-revalidate │
└──────────────────┬─────────────────────────────────┘
                   │
┌──────────────────▼─────────────────────────────────┐
│  ApiClient (HTTP client)                           │
│   ┌──────────────────┐   ┌──────────────────────┐  │
│   │  L1: CacheService │   │ L2: PersistentCache  │  │
│   │  (in-memory TTL)  │──▶│ (Isar disk, SWR)     │  │
│   └──────────────────┘   └──────────────────────┘  │
└──────────────────┬─────────────────────────────────┘
                   │
┌──────────────────▼─────────────────────────────────┐
│            Express API BFF + Supabase               │
└────────────────────────────────────────────────────┘
```

### Cache Layers

| Layer | Storage | TTL | Purpose |
|-------|---------|-----|---------|
| **L1: CacheService** | In-memory `Map` | 30s–5min (per endpoint) | Hot data for current session |
| **L2: PersistentCacheService** | Isar (embedded NoSQL) | Fresh TTL × 3 | Cold-start fill + offline fallback |

### Stale-While-Revalidate

When cached data exceeds its fresh TTL but is still within its max TTL:
1. **Return instantly** with stale data
2. **Refresh silently** in background
3. **Update both caches** with fresh response

This eliminates loading spinners for data that was recently fetched.

### Repository Pattern

Optional `lib/repositories/` layer wrapping services with `cacheFirst<T>()`:
- **Cache-first reads**: memory → Isar → API
- **Mutation invalidation**: POST/PATCH clears both cache tiers by resource prefix
- **Force refresh**: `forceRefresh: true` bypasses all caches
- **Auth logout**: `authStateChanges` listener clears memory + persistent caches

### Endpoint TTL Configuration

| Endpoint | Fresh TTL | Max TTL |
|----------|-----------|---------|
| `/api/v1/donor/matches` | 30s | 90s |
| `/api/v1/donor/mission` | 30s | 90s |
| `/api/v1/requests/active` | 30s | 90s |
| `/api/v1/hospital/pending` | 30s | 90s |
| `/api/v1/donor/stats` | 60s | 180s |
| `/api/v1/users/me` | 2min | 6min |
| `/api/v1/donor/leaderboard` | 2min | 6min |
| `/api/v1/donor/donations` | 2min | 6min |
| `/api/v1/hospitals` | 5min | 15min |

---

## 🎯 MVP Features

### 1. Recipient Features
- [x] Google Sign-In authentication
- [x] Profile creation with blood type, phone, location
- [x] Create blood requests with urgency levels
- [x] Auto-generated 4-digit request code
- [x] Real-time request status tracking
- [x] Edit and cancel active requests

### 2. Donor Features
- [x] Blood type + location-based matching
- [x] Push notifications for nearby requests
- [x] Accept/Decline requests
- [x] Active mission display with verification code
- [x] Donation history and reward points

### 3. Hospital Features
- [x] Hospital admin login
- [x] 4-digit code search
- [x] Donation verification workflow
- [x] Audit trail
- [x] Inventory logging

### 4. Core Infrastructure
- [x] PostGIS location matching (distance-based)
- [x] Atomic donor acceptance (prevents race conditions)
- [x] RBAC (app routing + Postgres Row Level Security)
- [x] Real-time GPS location capture

---

## 📱 User Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    BLOODCONNECT FLOW                         │
└─────────────────────────────────────────────────────────────┘

1. ONBOARDING (First Launch)


2. LOGIN
   └── Google Sign-In → Check profile exists

3. SIGNUP (New Users)
   ├── Enter profile info (name, phone, blood type)
   ├── Choose role (Donor / Recipient)
   ├── Capture GPS location
   └── Hospital: Enter hospital details + location

4. RECIPIENT FLOW
   ├── Switch to Recipient view
   ├── Create request → Select blood type, units, urgency, hospital
   ├── Get GPS location (fresh, for accurate matching)
   ├── Receive 4-digit code → Share with donor
   └── Track status: Active → Matching → In Progress → Fulfilled

5. DONOR FLOW
   ├── Switch to Donor view
   ├── Receive push notification
   ├── View nearby requests (filtered by blood type)
   ├── Accept request → Get hospital address + verification code
   └── Navigate to hospital → Verify with code

6. HOSPITAL FLOW
   ├── Login (hospital email detected)
   ├── Search by 4-digit code
   ├── Verify donor donation
   └── Request marked fulfilled

```

---

## 🗄️ Database Schema

### Core Tables

| Table | Purpose |
|-------|---------|
| `users` | User profiles with location (PostGIS) |
| `blood_requests` | Blood donation requests |
| `donor_responses` | Donor accept/decline actions |
| `donations` | Completed donation records |
| `hospital_domains` | Verified hospital email domains |
| `request_audit_log` | Audit trail for requests |
| `inventory_delivery_log` | Hospital inventory tracking |

### Key Functions

| Function | Purpose |
|----------|---------|
| `find_nearby_donors()` | PostGIS-based donor matching |
| `verify_request_donation()` | Atomic verification procedure |
| `generate_short_request_id()` | 4-digit code generation |

---

## 🔧 Setup Instructions

### Prerequisites
- Flutter SDK (latest)
- Xcode (for iOS)
- Supabase account
- Firebase project

### Security architecture

- **Flutter** talks only to the **API BFF** with Firebase ID tokens (no database password in the app).
- **API BFF** holds `SUPABASE_DB_PASSWORD` and enforces authorization server-side.
- Apply **RLS** via `supabase/migrations/20250519000000_enable_rls.sql`.
- See `docs/SECURITY.md`, `docs/PRIVACY_POLICY.md`, and `docs/DATA_HANDLING.md`.

### API BFF (`api-backend/`)

```bash
cd api-backend
cp .env.example .env   # fill Supabase + Firebase service account path
npm install
npm start              # default http://localhost:8090
```

**Firebase (required for sign-in):** download a service account JSON from Firebase Console (project `bloodconnect-mvp-b605f`) → save as `keys/firebase-adminsdk.json` (gitignored) and set `GOOGLE_APPLICATION_CREDENTIALS=../keys/firebase-adminsdk.json` in `api-backend/.env`. Without this, the API returns `invalid_token`.

### Flutter environment (team dev)

| How you run | API URL |
|-------------|---------|
| `flutter run` (debug) | Auto: `10.0.2.2:8090` (Android emulator), `127.0.0.1:8090` (iOS simulator) |
| Physical phone on Wi‑Fi | Copy `.env_example` → `.env`, set `API_BASE_URL=http://YOUR_PC_LAN_IP:8090` |
| Store / production APK | `--dart-define=API_BASE_URL=https://api.yourdomain.com` |

Avoid `flutter run --release` for local dev — that mode requires `--dart-define`. Use plain `flutter run`.

**Release / store builds:**

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com
```

### Database Setup
1. Create Supabase project
2. Enable PostGIS extension
3. Run `database/bloodconnect_schema.sql`
4. Run `database/mvp_incremental.sql` for stored procedures
5. Run `supabase/migrations/20250519000000_enable_rls.sql`

### Firebase Setup
1. Create Firebase project
2. Enable Authentication (Google Sign-In)
3. Enable Cloud Messaging
4. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

### Running the App
```bash
# Terminal 1: API BFF
cd api-backend && npm start

# Terminal 2: Flutter
flutter pub get
flutter run
```

---

## 🧪 Testing

### End-to-End Flow
```bash
# 1. Create test recipient
# 2. Create test donor
# 3. Recipient creates request
# 4. Check donor matching (PostGIS)
# 5. Donor accepts request
# 6. Hospital verifies by 4-digit code
# 7. Verify stats updated
```

See `database/` for SQL test scripts.

---
![CI](https://github.com/mariamsamaha/blood-connect/actions/workflows/ci.yml/badge.svg)

## 📄 Legal & privacy

- [LICENSE](LICENSE) (MIT)
- [Privacy Policy](docs/PRIVACY_POLICY.md)
- [Data handling](docs/DATA_HANDLING.md)
- [Security & secrets](docs/SECURITY.md)
