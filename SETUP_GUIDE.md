# 🩸 BloodConnect - Teammate Setup Guide

## 📋 Project Overview
BloodConnect is a real-time blood donation platform connecting donors, recipients, and hospitals. This guide will help you continue development from the current state.

## 🚀 Quick Start (30 minutes)

### 1. Environment Setup
```bash
# Clone the repository
git clone <repository-url>
cd blood-connect

# Install Flutter dependencies
flutter pub get

# Start PostgreSQL (make sure it's running)
brew services start postgresql  # macOS
# or
sudo systemctl start postgresql  # Linux

# Create database
createdb bloodconnect_dev

# Run schema (see Database Setup section below)
psql -d bloodconnect_dev -f database/bloodconnect_schema.sql
```

### 2. Firebase Setup
1. Create Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable Google Sign-In authentication
3. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS/macOS)
4. Place files in respective directories:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
   - `macos/Runner/GoogleService-Info.plist`

### 3. Run the App
```bash
flutter run
```

## 🗄️ Database Setup

### Required Files to Push
```
database/
├── bloodconnect_schema.sql          # ✅ COMPLETE - 567 lines
├── hospital_domains_data.sql        # ✅ COMPLETE - Sample data
└── stored_procedures.sql            # ✅ COMPLETE - Matching logic

lib/
├── services/
│   ├── database_service.dart         # ✅ COMPLETE - PostgreSQL connection
│   ├── user_service.dart            # ✅ COMPLETE - User CRUD operations
│   └── auth_service.dart            # ✅ COMPLETE - Firebase integration
├── models/
│   └── user_profile.dart            # ✅ COMPLETE - 3-concept user model
├── routing/
│   └── app_router.dart              # ✅ COMPLETE - GoRouter with auth guards
└── screens/
    ├── login_screen.dart            # ✅ COMPLETE - Google OAuth
    ├── signup_screen.dart           # ✅ COMPLETE - Hospital/Regular forms
    ├── onboarding_screen.dart       # ✅ COMPLETE - 3-page intro
    └── donor_home_screen.dart       # ✅ COMPLETE - Main dashboard
```

### Database Schema (Already Complete)
The database is **fully implemented** with:
- **11 tables** including users, blood_requests, donations, notifications
- **PostGIS integration** for geospatial donor matching
- **Stored procedures** for donor matching and hospital verification
- **Triggers** for status updates and audit trails

### Your Teammate Needs to Run:
```bash
# 1. Create database
createdb bloodconnect_dev

# 2. Create user (optional, can use existing)
psql -d bloodconnect_dev -c "CREATE USER bloodconnect_user WITH PASSWORD 'bloodconnect123';"

# 3. Grant permissions
psql -d bloodconnect_dev -c "GRANT ALL PRIVILEGES ON DATABASE bloodconnect_dev TO bloodconnect_user;"

# 4. Run schema (this creates ALL tables)
psql -d bloodconnect_dev -f database/bloodconnect_schema.sql

# 5. Insert sample data
psql -d bloodconnect_dev -f database/hospital_domains_data.sql
```

## 🏗️ Architecture Review

### Authentication Flow (✅ COMPLETE)
```
Google OAuth → Firebase Auth → PostgreSQL Profile → GoRouter → App Screens
```

**Key Features:**
- **Hospital Email Detection**: Queries `hospital_domains` table dynamically
- **Dual Signup Forms**: Separate flows for hospitals vs regular users
- **3-Concept User Model**: `account_type` (permanent), `is_donor` (capability), `active_mode` (UI screen)

### Routing & State Management (✅ COMPLETE)
**GoRouter Implementation:**
- **Auth Guards**: Redirects unauthenticated users to `/login`
- **Profile Guards**: Redirects users without PostgreSQL profile to `/onboarding`
- **Role-Based Routing**: Hospitals → `/hospital/dashboard`, Regular → `/donor/home`
- **Screen Restrictions**: Based on `account_type` and `active_mode`

### Service Layer (✅ COMPLETE)
```
DatabaseService → PostgreSQL connection
UserService → User CRUD + profile management
AuthService → Firebase Google Sign-In
```

## 📱 Current Implementation Status

### ✅ COMPLETE Features
1. **Authentication System**
   - Google OAuth integration
   - Hospital email detection
   - Dual signup flows (hospital/regular)
   - Profile creation with validation

2. **User Management**
   - 3-concept user model (account_type, is_donor, active_mode)
   - Role-based routing
   - Profile CRUD operations
   - Hospital domain verification

3. **Basic UI Screens**
   - Login screen with Google Sign-In
   - Onboarding (3-page intro)
   - Signup screens (hospital + regular forms)
   - Donor home dashboard

4. **Database Infrastructure**
   - Complete PostgreSQL schema (11 tables)
   - PostGIS geospatial support
   - Stored procedures for matching
   - Hospital domains table

### 🚧 INCOMPLETE Features (Your Tasks)
1. **Blood Request System** (Priority 1)
   - Create request screen
   - Request status tracking
   - 4-digit ID generation
   - Request CRUD operations

2. **Location Services** (Priority 2)
   - GPS integration for user location
   - Geospatial donor matching
   - Distance calculations

3. **Hospital Dashboard** (Priority 3)
   - Request verification interface
   - 4-digit code search
   - Donation confirmation workflow

4. **Recipient Home Screen** (Priority 4)
   - Request status tracking
   - Donor notifications
   - Request management

## 🎯 Professor MVP Alignment

### ✅ ALIGNED WITH MVP
1. **Story 1 - Recipient Creates Request**: ✅ User can create requests from donor home
2. **Story 2 - Donor Accepts & Navigates**: ✅ Donor home has "Create Request" button
3. **Story 3 - Hospital Verifies**: ✅ Hospital routing and domain detection

### 🎯 SCREEN RESTRICTIONS & EDGE CASES

**Current Logic:**
- **Account Type**: Permanent (regular/hospital) - determines which screens are accessible
- **Active Mode**: UI screen (donor_view/recipient_view/hospital_view) - determines current view
- **Capabilities**: `is_donor`/`is_recipient` - determine what user can do

**Screen Access Rules:**
```dart
// Hospitals can ONLY access hospital screens
if (accountType == 'hospital') {
  accessibleScreens = ['/hospital/dashboard'];
}

// Regular users can access donor/recipient screens
if (accountType == 'regular') {
  accessibleScreens = ['/donor/home', '/recipient/home'];
  // Can switch between views freely
}
```

**Edge Cases Handled:**
1. **Partial Signup**: Router checks PostgreSQL profile, not just Firebase auth
2. **Hospital Email Detection**: Dynamic database query with fallback
3. **Role Switching**: Users can freely switch between donor/recipient views
4. **Duplicate Prevention**: Firebase UID UNIQUE constraint in database

## 🔄 Next Development Tasks

### Priority 1: Blood Request System
**Files to Create/Modify:**
```
lib/screens/create_request_screen.dart     # NEW
lib/screens/recipient_home_screen.dart     # NEW  
lib/services/request_service.dart          # NEW
lib/models/blood_request.dart              # NEW
lib/routing/app_router.dart                # ADD routes
```

**Implementation Steps:**
1. Create `BloodRequest` model
2. Implement `RequestService` with CRUD operations
3. Build `CreateRequestScreen` with form validation
4. Add 4-digit ID generation logic
5. Update router with new routes

### Priority 2: Location Services
**Files to Modify:**
```
lib/services/location_service.dart       # NEW
lib/screens/signup_screen.dart            # ADD GPS
lib/services/user_service.dart            # ADD location storage
```

### Priority 3: Hospital Dashboard
**Files to Create/Modify:**
```
lib/screens/hospital_dashboard_screen.dart # ENHANCE
lib/screens/verify_donation_screen.dart    # NEW
lib/services/donation_service.dart         # NEW
```

## 🧪 Testing Checklist

### Before Starting Development:
- [ ] PostgreSQL is running and accessible
- [ ] Database schema is loaded (`bloodconnect_schema.sql`)
- [ ] Firebase project is configured
- [ ] App launches without errors
- [ ] Google Sign-In works
- [ ] Hospital email detection works (test with `admin@cairo.general.eg`)

### During Development:
- [ ] All new screens follow existing UI patterns
- [ ] Error handling is consistent with existing code
- [ ] Database operations use proper transactions
- [ ] Routes are properly protected by auth guards

## 📁 File Structure (Current)

```
blood-connect/
├── android/
│   └── app/google-services.json          # ✅ Firebase config
├── ios/
│   └── Runner/GoogleService-Info.plist   # ✅ Firebase config
├── database/
│   ├── bloodconnect_schema.sql            # ✅ Complete schema
│   └── hospital_domains_data.sql          # ✅ Sample data
├── lib/
│   ├── main.dart                          # ✅ App entry point
│   ├── models/
│   │   └── user_profile.dart              # ✅ User model
│   ├── services/
│   │   ├── auth_service.dart              # ✅ Firebase auth
│   │   ├── database_service.dart         # ✅ PostgreSQL
│   │   └── user_service.dart             # ✅ User CRUD
│   ├── screens/
│   │   ├── login_screen.dart              # ✅ Google OAuth
│   │   ├── signup_screen.dart             # ✅ Dual forms
│   │   ├── onboarding_screen.dart         # ✅ 3-page intro
│   │   └── donor_home_screen.dart         # ✅ Main dashboard
│   └── routing/
│       └── app_router.dart                # ✅ GoRouter + auth
└── pubspec.yaml                           # ✅ Dependencies
```

## 🔧 Development Guidelines

### Code Patterns to Follow:
1. **Service Layer**: All database operations go through services
2. **Error Handling**: Use try-catch with user-friendly messages
3. **State Management**: Use Riverpod for dependency injection
4. **Navigation**: Use GoRouter with proper auth guards
5. **UI Consistency**: Follow existing screen patterns and styling

### Database Best Practices:
1. **Always use transactions** for multi-table operations
2. **Validate inputs** before database operations
3. **Handle null values** properly in Dart models
4. **Use parameterized queries** to prevent SQL injection

## 🚨 Important Notes

### Firebase + PostgreSQL Integration:
- **Firebase**: Handles authentication only (email, name, UID)
- **PostgreSQL**: Stores complete user profiles and application data
- **Link**: `firebase_uid` field connects both systems

### Hospital Email Detection:
- **Primary**: Query `hospital_domains` table dynamically
- **Fallback**: Basic domain matching if database fails
- **Test Email**: `admin@cairo.general.eg` should work with existing data

### User Model (3-Concept Design):
```dart
class UserProfile {
  final AccountType accountType;    // PERMANENT: regular/hospital
  final bool isDonor;               // CAPABILITY: can receive alerts
  final bool isRecipient;           // CAPABILITY: has active request
  final ActiveMode activeMode;     // UI SCREEN: donor/recipient/hospital view
}
```

Good luck! 🩸