import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:bloodconnect/services/auth_service.dart';
import 'package:bloodconnect/services/user_service.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/screens/login_screen.dart';
import 'package:bloodconnect/screens/signup_screen.dart';
import 'package:bloodconnect/screens/onboarding_screen.dart';
import 'package:bloodconnect/screens/donor_home_screen.dart';
import 'package:bloodconnect/screens/recipient_home_screen.dart';
import 'package:bloodconnect/screens/hospital_dashboard_screen.dart';
import 'package:bloodconnect/screens/create_request_screen.dart';
import 'package:bloodconnect/screens/profile_screen.dart';

UserProfile? _cachedProfile;
String? _cachedUid;
bool _isFetchingProfile = false;

void clearProfileCache() {
  _cachedProfile = null;
  _cachedUid = null;
  _isFetchingProfile = false;
}

/// Call this after role switch to clear cached profile
void onRoleSwitched() {
  clearProfileCache();
}

/// Post-login home route for this profile (MVP role routing).
String homeRouteForProfile(UserProfile profile) {
  if (profile.accountType == AccountType.hospital) {
    return '/hospital/dashboard';
  }
  if (profile.activeMode == ActiveMode.recipient_view) {
    return '/recipient/home';
  }
  return '/donor/home';
}

GoRouter buildRouter({
  required AuthService authService,
  required UserService userService,
  required Listenable refreshListenable,
}) {
  return GoRouter(
    initialLocation: '/onboarding',
    refreshListenable: refreshListenable,
    routes: [
      GoRoute(path: '/', redirect: (ctx, s) => '/onboarding'),
      GoRoute(
        path: '/onboarding',
        builder: (ctx, s) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (ctx, s) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (ctx, s) => const SignUpScreen()),
      GoRoute(
        path: '/donor/home',
        builder: (ctx, s) => const DonorHomeScreen(),
      ),
      GoRoute(
        path: '/recipient/home',
        builder: (ctx, s) => const RecipientHomeScreen(),
      ),
      GoRoute(
        path: '/hospital/dashboard',
        builder: (ctx, s) => const HospitalDashboardScreen(),
      ),
      GoRoute(
        path: '/create-request',
        builder: (ctx, s) => const CreateRequestScreen(),
      ),
      GoRoute(path: '/profile', builder: (ctx, s) => const ProfileScreen()),
    ],
    redirect: (context, state) async {
      if (state.matchedLocation == '/signup') {
        if (authService.currentUser == null) return '/login';
        return null;
      }

      final firebaseUser = authService.currentUser;
      if (firebaseUser == null) {
        if (state.matchedLocation == '/login' || state.matchedLocation == '/') {
          return null;
        }
        return '/login';
      }

      UserProfile? profile;

      if (_cachedProfile != null && _cachedUid == firebaseUser.uid) {
        profile = _cachedProfile;
      } else {
        if (_isFetchingProfile) return null;

        _isFetchingProfile = true;

        try {
          profile = await userService.getProfileByFirebaseUid(firebaseUser.uid);

          _cachedProfile = profile;
          _cachedUid = firebaseUser.uid;
        } catch (e) {
          debugPrint('Profile fetch error: $e');
          _isFetchingProfile = false;
          return '/login'; // fallback
        }

        _isFetchingProfile = false;
      }
      if (profile == null) return '/signup';

      final loc = state.matchedLocation;

      // Hospital admin: dashboard + profile only (MVP RBAC).
      if (profile.accountType == AccountType.hospital) {
        if (loc == '/profile' || loc.startsWith('/hospital/')) return null;
        return '/hospital/dashboard';
      }

      if (loc.startsWith('/hospital/')) {
        return homeRouteForProfile(profile);
      }

      if (loc == '/donor/home') {
        if (profile.activeMode != ActiveMode.donor_view) {
          return '/recipient/home';
        }
        return null;
      }

      if (loc == '/recipient/home' || loc == '/create-request') {
        if (profile.activeMode != ActiveMode.recipient_view) {
          return '/donor/home';
        }
        return null;
      }

      if (loc == '/profile') return null;

      if (loc == '/' || loc == '/login') {
        return homeRouteForProfile(profile);
      }

      return null;
    },
  );
}
