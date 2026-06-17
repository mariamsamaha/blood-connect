import 'package:flutter/material.dart';
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
import 'package:bloodconnect/screens/donor_mission_screen.dart';
import 'package:bloodconnect/screens/donation_history_screen.dart';
import 'package:bloodconnect/screens/badges_screen.dart';
import 'package:bloodconnect/screens/leaderboard_screen.dart';
import 'package:bloodconnect/screens/settings_screen.dart';
import 'package:bloodconnect/screens/create_request_screen.dart';
import 'package:bloodconnect/screens/profile_screen.dart';
import 'package:bloodconnect/screens/ai_prediction_screen.dart';
import 'package:bloodconnect/screens/stories_screen.dart';
import 'package:bloodconnect/screens/coupons_screen.dart';
import 'package:bloodconnect/screens/map_discover_screen.dart';
import 'package:bloodconnect/screens/notification_center_screen.dart';
import 'package:bloodconnect/screens/inventory_management_screen.dart';
import 'package:bloodconnect/screens/donor_feedback_submission_screen.dart';
import 'package:bloodconnect/screens/hospital_feedback_analytics_screen.dart';
import 'package:bloodconnect/screens/hospital_profile_screen.dart';
import 'package:bloodconnect/widgets/app_shell.dart';

final _inFlightProfileFetches = <String, Future<UserProfile?>>{};

void clearProfileCache() {
  _inFlightProfileFetches.clear();
}

String homeRouteForProfile(UserProfile profile) {
  return profile.homeRoute;
}

Page<void> _slideTransition(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.03, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
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
      GoRoute(
        path: '/',
        redirect: (ctx, s) => '/onboarding',
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (ctx, s) => _slideTransition(const OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (ctx, s) => _slideTransition(const LoginScreen()),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (ctx, s) => _slideTransition(const SignUpScreen()),
      ),

      // ── Shell with persistent bottom nav ──────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/donor/home',
                builder: (ctx, state) => const DonorHomeScreen(),
              ),
              GoRoute(
                path: '/recipient/home',
                builder: (ctx, state) => const RecipientHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map-discover',
                builder: (ctx, state) => const MapDiscoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stories',
                builder: (ctx, state) => const StoriesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coupons',
                builder: (ctx, state) => const CouponsScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Standalone routes (no bottom nav) ─────────────────────────────
      GoRoute(
        path: '/hospital/dashboard',
        pageBuilder: (ctx, s) =>
            _slideTransition(const HospitalDashboardScreen()),
      ),
      GoRoute(
        path: '/hospital/profile',
        pageBuilder: (ctx, s) =>
            _slideTransition(const HospitalProfileScreen()),
      ),
      GoRoute(
        path: '/donor/mission',
        pageBuilder: (ctx, s) => _slideTransition(const DonorMissionScreen()),
      ),
      GoRoute(
        path: '/donation-history',
        pageBuilder: (ctx, s) =>
            _slideTransition(const DonationHistoryScreen()),
      ),
      GoRoute(
        path: '/badges',
        pageBuilder: (ctx, s) => _slideTransition(const BadgesScreen()),
      ),
      GoRoute(
        path: '/leaderboard',
        pageBuilder: (ctx, s) => _slideTransition(const LeaderboardScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (ctx, s) => _slideTransition(const SettingsScreen()),
      ),
      GoRoute(
        path: '/create-request',
        pageBuilder: (ctx, s) =>
            _slideTransition(const CreateRequestScreen()),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (ctx, s) => _slideTransition(const ProfileScreen()),
      ),
      GoRoute(
        path: '/ai-check',
        pageBuilder: (ctx, s) =>
            _slideTransition(const AiPredictionScreen()),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (ctx, s) =>
            _slideTransition(const NotificationCenterScreen()),
      ),
      GoRoute(
        path: '/hospital/inventory',
        pageBuilder: (ctx, s) =>
            _slideTransition(const InventoryManagementScreen()),
      ),
      GoRoute(
        path: '/hospital/feedback',
        pageBuilder: (ctx, s) => _slideTransition(
          HospitalFeedbackAnalyticsScreen(
            hospitalId: s.uri.queryParameters['hospitalId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/feedback/submit',
        pageBuilder: (ctx, s) => _slideTransition(
          DonorFeedbackSubmissionScreen(
            donationId: s.uri.queryParameters['donationId'] ?? '',
            donorId: s.uri.queryParameters['donorId'] ?? '',
            feedbackType: s.uri.queryParameters['feedbackType'] ?? '',
            targetId: s.uri.queryParameters['targetId'] ?? '',
            targetName: s.uri.queryParameters['targetName'] ?? '',
          ),
        ),
      ),
    ],
    redirect: (context, state) async {
      if (state.matchedLocation == '/signup') {
        if (authService.currentUser == null) return '/login';
        return null;
      }

      final firebaseUser = authService.currentUser;
      if (firebaseUser == null) {
        if (state.matchedLocation == '/login' ||
            state.matchedLocation == '/') {
          return null;
        }
        return '/login';
      }

      UserProfile? profile;

      final inFlight = _inFlightProfileFetches[firebaseUser.uid];
      if (inFlight != null) {
        profile = await inFlight;
      } else {
        final fetch = userService.getProfileByFirebaseUid(firebaseUser.uid);
        _inFlightProfileFetches[firebaseUser.uid] = fetch;
        try {
          profile = await fetch;
        } catch (e) {
          _inFlightProfileFetches.remove(firebaseUser.uid);
          debugPrint('Profile fetch error: $e');
          return '/login';
        }
        _inFlightProfileFetches.remove(firebaseUser.uid);
      }
      if (profile == null) return '/signup';

      final loc = state.matchedLocation;

      if (profile.accountType == AccountType.hospital) {
        if (loc == '/profile') return '/hospital/profile';
        if (loc == '/settings' ||
            loc == '/notifications' ||
            loc.startsWith('/hospital/')) return null;
        return '/hospital/dashboard';
      }

      if (loc.startsWith('/hospital/')) {
        return homeRouteForProfile(profile);
      }

      if (loc == '/donor/home') {
        if (profile.role != UserRole.donor) {
          return '/recipient/home';
        }
        return null;
      }

      if (loc == '/map-discover') {
        if (profile.role != UserRole.donor) return homeRouteForProfile(profile);
        return null;
      }

      if (loc == '/recipient/home' || loc == '/create-request') {
        if (profile.role != UserRole.recipient) {
          return '/donor/home';
        }
        return null;
      }

      if (loc == '/profile') return null;

      if (loc == '/donor/mission' ||
          loc == '/donation-history' ||
          loc == '/badges' ||
          loc == '/leaderboard') {
        if (profile.role != UserRole.donor) return homeRouteForProfile(profile);
        return null;
      }

      if (loc == '/' || loc == '/login') {
        return homeRouteForProfile(profile);
      }

      if (loc == '/ai-check' || loc == '/stories' || loc == '/notifications' || loc == '/feedback/submit') return null;

      if (loc == '/coupons') {
        if (profile.role != UserRole.donor) return homeRouteForProfile(profile);
        return null;
      }

      return null;
    },
  );
}
