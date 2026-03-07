import 'package:go_router/go_router.dart';
import 'package:bloodconnect/services/auth_service.dart';
import 'package:bloodconnect/services/user_service.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/screens/login_screen.dart';
import 'package:bloodconnect/screens/signup_screen.dart';
import 'package:bloodconnect/screens/donor_home_screen.dart';
import 'package:bloodconnect/screens/recipient_home_screen.dart';
import 'package:bloodconnect/screens/hospital_dashboard_screen.dart';
import 'package:bloodconnect/screens/create_request_screen.dart';
import 'package:bloodconnect/screens/profile_screen.dart';

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
      GoRoute(
        path: '/create-request',
        builder: (ctx, state) => const CreateRequestScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (ctx, state) => const ProfileScreen(),
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

      if (profile == null) return '/signup';

      // Redirect from root, login, and signup - FORCE to home based on capabilities
      if (state.matchedLocation == '/' ||
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup') {
        // Always go to home, let home screen decide what to show
        return _getHomeForUser(profile);
      }

      return null;
    },
  );
}

String _getHomeForUser(UserProfile profile) {
  if (profile.accountType == AccountType.hospital) {
    return '/hospital/dashboard';
  }
  // Route by role chosen at signup (active_mode)
  if (profile.activeMode == ActiveMode.recipient_view) {
    return '/recipient/home';
  }
  return '/donor/home';
}