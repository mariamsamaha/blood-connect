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

GoRouter buildRouter({
  required AuthService authService,
  required UserService userService,
}) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (ctx, state) => const SignUpScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (ctx, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/donor/home',
        builder: (ctx, state) => const DonorHomeScreen(),
      ),
      GoRoute(
        path: '/recipient/home',
        builder: (ctx, state) => const RecipientHomeScreen(),
      ),
      GoRoute(
        path: '/hospital/dashboard',
        builder: (ctx, state) => const HospitalDashboardScreen(),
      ),
    ],
    redirect: (context, state) async {
      final firebaseUser = authService.currentUser;

      // Allow access to signup regardless of auth state
      if (state.matchedLocation == '/signup') return null;

      if (firebaseUser == null) return '/login';

      final profile = await userService.getProfileByFirebaseUid(
        firebaseUser.uid,
      );

      if (profile == null) return '/onboarding';

      // Redirect from root, login, and onboarding - FORCE to home based on capabilities
      if (state.matchedLocation == '/' ||
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/onboarding') {
        // Always go to home, let home screen decide what to show
        return _getHomeForUser(profile);
      }

      return null;
    },
  );
}

String _homeRouteForMode(ActiveMode mode, AccountType accountType) {
  if (accountType == AccountType.hospital) return '/hospital/dashboard';
  return switch (mode) {
    ActiveMode.recipient_view => '/recipient/home',
    ActiveMode.donor_view => '/donor/home',
    ActiveMode.hospital_view => '/hospital/dashboard',
  };
}

String _getHomeForUser(UserProfile profile) {
  // Force ALL users to home - let home screen decide what to show based on their capabilities
  // This matches the professor's MVP: users can freely switch between donor/recipient views
  if (profile.accountType == AccountType.hospital) {
    return '/hospital/dashboard';
  }

  // For regular users, show the screen that makes most sense for their current state
  return '/donor/home';
}
