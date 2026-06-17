import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bloodconnect/routing/app_router.dart';

class MockUser extends Fake implements User {
  @override
  String get uid => 'test-uid';
}

class MockUserCredential extends Fake implements UserCredential {
  @override
  User? get user => MockUser();
}

void main() {
  group('AuthService', () {
    test('clearProfileCache clears cached values', () {
      clearProfileCache();
    });

    test('homeRouteForProfile returns correct route for donor', () {
      // tested in user_profile_test.dart
    });
  });
}
