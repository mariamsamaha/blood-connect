import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime configuration.
/// - Debug/profile: `.env` → platform default (emulator-friendly).
/// - Release/store: `--dart-define=API_BASE_URL=...` required.
class AppConfig {
  AppConfig._();

  static bool _loaded = false;
  static bool _dotenvLoaded = false;

  /// True for day-to-day dev (`flutter run`, emulators, team devices on LAN).
  static bool get isDevBuild => !kReleaseMode;

  static Future<void> load() async {
    if (_loaded) return;
    if (isDevBuild) {
      try {
        await dotenv.load(fileName: '.env');
        _dotenvLoaded = true;
      } catch (_) {
        _dotenvLoaded = false;
        debugPrint(
          'No .env file — using platform defaults. '
          'For a physical phone, copy .env_example → .env and set API_BASE_URL to your PC LAN IP.',
        );
      }
    }
    _loaded = true;
    if (isDevBuild) {
      debugPrint('BloodConnect API: $apiBaseUrl');
    }
  }

  static String? _env(String key) {
    if (!_dotenvLoaded) return null;
    return dotenv.env[key];
  }

  static String _fromDefineOrEnv(String defineKey, String envKey) {
    final fromDefine = String.fromEnvironment(defineKey);
    if (fromDefine.isNotEmpty) return fromDefine.trim();
    if (isDevBuild) {
      final fromEnv = _env(envKey);
      if (fromEnv != null && fromEnv.trim().isNotEmpty) return fromEnv.trim();
    }
    return '';
  }

  /// Default API host for local dev when `.env` is missing.
  /// Android emulator → host machine via 10.0.2.2; iOS simulator → localhost.
  /// Physical phones must set API_BASE_URL in `.env` to your computer's LAN IP.
  static String defaultLocalApiBaseUrl() {
    if (kIsWeb) return 'http://localhost:8090';
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8090';
    }
    return 'http://127.0.0.1:8090';
  }

  static String defaultLocalAiServiceUrl() {
    if (kIsWeb) return 'http://localhost:8000';
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  /// BloodConnect API BFF (Firebase-authenticated).
  static String get apiBaseUrl {
    final url = _fromDefineOrEnv('API_BASE_URL', 'API_BASE_URL');
    if (url.isNotEmpty) return url.replaceAll(RegExp(r'/$'), '');
    if (isDevBuild) {
      return defaultLocalApiBaseUrl();
    }
    throw StateError(
      'API_BASE_URL is required for release builds.\n'
      'Dev: run with `flutter run` (not --release) and start api-backend, or copy .env_example to .env\n'
      'Physical device: set API_BASE_URL=http://YOUR_PC_LAN_IP:8090 in .env\n'
      'Store build: flutter build apk --dart-define=API_BASE_URL=https://your-api.example.com',
    );
  }

  static String get notificationBackendUrl =>
      _fromDefineOrEnv('NOTIFICATION_BACKEND_URL', 'NOTIFICATION_BACKEND_URL');

  static String get notificationBackendSecret =>
      _fromDefineOrEnv('NOTIFICATION_BACKEND_SECRET', 'NOTIFICATION_BACKEND_SECRET');

  static String get aiServiceUrl {
    final url = _fromDefineOrEnv('AI_SERVICE_URL', 'AI_SERVICE_URL');
    if (url.isNotEmpty) return url;
    if (isDevBuild) return defaultLocalAiServiceUrl();
    return '';
  }
}
