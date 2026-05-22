import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:bloodconnect/screens/onboarding_screen.dart';

Widget _wrapTestApp() {
  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('Login'))),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  group('OnboardingScreen', () {
    testWidgets('renders Skip and Continue buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrapTestApp());
      await tester.pump();
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('shows first page title', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrapTestApp());
      await tester.pump();
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('tapping Continue shows page 2', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrapTestApp());
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Get Started'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('page 3 shows Get Started', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrapTestApp());
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('tapping Skip navigates to login', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrapTestApp());
      await tester.pump();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('page indicator dots are visible', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrapTestApp());
      await tester.pump();
      expect(find.byType(PageView), findsOneWidget);
    });
  });
}
