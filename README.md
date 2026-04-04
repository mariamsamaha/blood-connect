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
| **Backend** | Supabase (PostgreSQL + PostGIS) |
| **Authentication** | Firebase Auth (Google OAuth) |
| **Push Notifications** | Firebase Cloud Messaging (FCM) |
| **State Management** | Riverpod |
| **Navigation** | GoRouter |
| **Location** | Geolocator |

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
- [x] Role toggle (Donor/Recipient view)
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
- [x] RBAC (Role-Based Access Control)
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

### Environment Variables (.env)
```env
SUPABASE_HOST=your_supabase_host
SUPABASE_PORT=6543
SUPABASE_DATABASE=postgres
SUPABASE_USERNAME=postgres.xxxxxx
SUPABASE_PASSWORD=your_password
```

### Database Setup
1. Create Supabase project
2. Enable PostGIS extension
3. Run `database/bloodconnect_schema.sql`
4. Run `database/mvp_incremental.sql` for stored procedures

### Firebase Setup
1. Create Firebase project
2. Enable Authentication (Google Sign-In)
3. Enable Cloud Messaging
4. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

### Running the App
```bash
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


## 📄 License

MIT License
