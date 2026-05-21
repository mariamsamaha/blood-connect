import 'package:bloodconnect/services/local_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloodconnect/routing/app_router.dart';
import 'package:bloodconnect/routing/router_refresh.dart';
import 'package:bloodconnect/services/audit_log_service.dart';
import 'package:bloodconnect/services/user_service.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/auth_service.dart';
import 'package:bloodconnect/services/request_service.dart';
import 'package:bloodconnect/services/notification_service.dart';
import 'package:bloodconnect/services/location_service.dart';
import 'package:bloodconnect/services/donor_service.dart';
import 'package:bloodconnect/services/hospital_service.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/config/app_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:bloodconnect/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Background message: ${message.notification?.title}');
}

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final userServiceProvider = Provider<UserService>((ref) {
  return UserService(ref.watch(apiClientProvider));
});

final auditLogServiceProvider = Provider<AuditLogService>((ref) {
  return AuditLogService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final requestServiceProvider = Provider<RequestService>((ref) {
  return RequestService(
    ref.watch(apiClientProvider),
    notificationService: ref.watch(notificationServiceProvider),
    audit: ref.watch(auditLogServiceProvider),
  );
});

final donorServiceProvider = Provider<DonorService>((ref) {
  return DonorService(
    ref.watch(apiClientProvider),
    audit: ref.watch(auditLogServiceProvider),
  );
});

final hospitalServiceProvider = Provider<HospitalService>((ref) {
  return HospitalService(ref.watch(apiClientProvider));
});

final routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {
  final n = RouterRefreshNotifier();
  ref.onDispose(n.dispose);
  return n;
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);
  final userService = ref.watch(userServiceProvider);
  final refresh = ref.watch(routerRefreshProvider);
  return buildRouter(
    authService: authService,
    userService: userService,
    refreshListenable: refresh,
  );
});

final fcmProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();

  if (AppConfig.notificationBackendUrl.isEmpty) {
    debugPrint(
      'WARNING: NOTIFICATION_BACKEND_URL is not set — push notifications require the API BFF.',
    );
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseMessaging.instance.requestPermission();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await LocalNotificationService.init();
  } catch (e) {
    debugPrint('Local notifications init failed: $e');
  }

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  runApp(const ProviderScope(child: BloodConnectApp()));
}

class BloodConnectApp extends ConsumerStatefulWidget {
  const BloodConnectApp({super.key});

  @override
  ConsumerState<BloodConnectApp> createState() => _BloodConnectAppState();
}

class _BloodConnectAppState extends ConsumerState<BloodConnectApp> {
  @override
  void initState() {
    super.initState();
    _setupFcmToken();
    _setupFcmListeners();
  }

  Future<void> _setupFcmToken() async {
    final authService = ref.read(authServiceProvider);
    final userService = ref.read(userServiceProvider);

    final user = authService.currentUser;
    if (user != null) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        await userService.updateFcmToken(user.uid, token);
      } catch (e) {
        debugPrint('FCM token error (may be normal on iOS simulator): $e');
      }
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final user = authService.currentUser;
      if (user != null) {
        try {
          await userService.updateFcmToken(user.uid, newToken);
        } catch (e) {
          debugPrint('FCM token refresh error: $e');
        }
      }
    });

    authService.onAuthStateChanged.listen((user) async {
      if (user != null) {
        try {
          final token = await FirebaseMessaging.instance.getToken();
          await userService.updateFcmToken(user.uid, token);
        } catch (e) {
          debugPrint('FCM token on auth change error: $e');
        }
      }
    });
  }

  Future<void> _setupFcmListeners() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        debugPrint('Foreground message: ${notification.title}');
        LocalNotificationService.show(
          title: notification.title ?? '',
          body: notification.body ?? '',
        );
      }
      debugPrint('New request notification - pull to refresh');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final requestId = message.data['request_id'] ?? '';
      if (requestId.isNotEmpty) {
        debugPrint('Notification tapped: $requestId');
        final router = ref.read(routerProvider);
        router.go('/donor/home');
      }
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      final requestId = initial.data['request_id'] ?? '';
      if (requestId.isNotEmpty) {
        debugPrint('Opened from terminated: $requestId');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final router = ref.read(routerProvider);
          router.go('/donor/home');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'BloodConnect',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
