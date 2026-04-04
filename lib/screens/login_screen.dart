// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/routing/app_router.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.read(authServiceProvider);
    final userService = ref.read(userServiceProvider);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'BloodConnect',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'You are routed by role '
                '(donor / recipient / hospital).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Sign in with Google'),
              onPressed: () async {
                final cred = await authService.signInWithGoogle();
                if (!context.mounted) return;
                if (cred?.user == null) return;

                final profile = await userService.getProfileByFirebaseUid(
                  cred!.user!.uid,
                );
                if (!context.mounted) return;

                if (profile == null) {
                  context.go('/signup');
                } else {
                  context.go(homeRouteForProfile(profile));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
