import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('isDevBuild is true in test mode', () {
      expect(AppConfig.isDevBuild, isTrue);
    });

    test('defaultLocalApiBaseUrl returns localhost for non-android', () {
      final url = AppConfig.defaultLocalApiBaseUrl();
      expect(url, anyOf(contains('localhost'), contains('127.0.0.1'), contains('10.0.2.2')));
    });

    test('defaultLocalAiServiceUrl returns localhost for non-android', () {
      final url = AppConfig.defaultLocalAiServiceUrl();
      expect(url, contains('8000'));
    });

    test('load does not throw', () async {
      await AppConfig.load();
    });
  });
}
