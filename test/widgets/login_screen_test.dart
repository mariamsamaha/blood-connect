import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/screens/login_screen.dart';
import 'package:bloodconnect/services/auth_service.dart';
import 'package:bloodconnect/services/user_service.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';

class _MockAuthService extends Fake implements AuthService {
  @override
  User? get currentUser => null;

  @override
  Future<UserCredential?> signInWithGoogle() async {
    // Simulate a delayed sign-in to let loading state render
    await Future.delayed(const Duration(seconds: 1));
    return null;
  }
}

class _MockUserService extends Fake implements UserService {
  @override
  Future<UserProfile?> getProfileByFirebaseUid(String firebaseUid) async {
    return null;
  }
}

Widget _buildTestApp() {
  final mockAuth = _MockAuthService();
  final mockUser = _MockUserService();

  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const Scaffold(body: Text('SignUp'))),
      GoRoute(path: '/donor/home', builder: (_, __) => const Scaffold(body: Text('DonorHome'))),
      GoRoute(path: '/recipient/home', builder: (_, __) => const Scaffold(body: Text('RecipientHome'))),
      GoRoute(path: '/hospital/dashboard', builder: (_, __) => const Scaffold(body: Text('HospitalDash'))),
    ],
  );

  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(mockAuth),
      userServiceProvider.overrideWithValue(mockUser),
    ],
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('renders app title and tagline', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('BloodConnect'), findsOneWidget);
      expect(find.text('Save Lives, One Donation at a Time'), findsOneWidget);
    });

    testWidgets('renders Welcome Back card', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign in to continue saving lives'), findsOneWidget);
    });

    testWidgets('renders sign in with Google button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('renders feature badges', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Find Nearby'), findsOneWidget);
      expect(find.text('Instant Alert'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('tapping Google button shows loading indicator', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Google'));
      // Pump past the setState to show loading state
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Connecting...'), findsOneWidget);

      // Complete the delayed sign-in to clean up timers
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
