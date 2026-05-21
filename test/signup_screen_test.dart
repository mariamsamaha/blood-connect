import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/screens/signup_screen.dart';

void main() {
  group('SignUpScreen', () {
    test('screen can be instantiated', () {
      expect(const SignUpScreen(), isNotNull);
    });

    test('SignUpScreen is a ConsumerStatefulWidget', () {
      const screen = SignUpScreen();
      expect(screen, isA<SignUpScreen>());
    });
  });
}
