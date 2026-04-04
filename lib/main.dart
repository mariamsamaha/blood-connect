import 'package:bloodconnect/services/local_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloodconnect/routing/app_router.dart';
import 'package:bloodconnect/routing/router_refresh.dart';
import 'package:bloodconnect/services/audit_log_service.dart';
import 'package:bloodconnect/services/user_service.dart';
import 'package:bloodconnect/services/database_service.dart';
import 'package:bloodconnect/services/auth_service.dart';
import 'package:bloodconnect/services/request_service.dart';
import 'package:bloodconnect/services/notification_service.dart';
import 'package:bloodconnect/services/location_service.dart';
import 'package:bloodconnect/services/donor_service.dart';
import 'package:bloodconnect/services/hospital_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background message: ${message.notification?.title}');
}

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
GlobalKey<ScaffoldMessengerState>();

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService(
    host: dotenv.env['SUPABASE_HOST']!,
    port: int.parse(dotenv.env['SUPABASE_PORT']!),
    database: dotenv.env['SUPABASE_DATABASE']!,
    username: dotenv.env['SUPABASE_USERNAME']!,
    password: dotenv.env['SUPABASE_PASSWORD']!,
    requireSsl: true,
  );
});


final userServiceProvider = Provider<UserService>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return UserService(db);
});

final auditLogServiceProvider = Provider<AuditLogService>((ref) {
  return AuditLogService(ref.watch(databaseServiceProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return NotificationService(db);
});

final requestServiceProvider = Provider<RequestService>((ref) {
  final db = ref.watch(databaseServiceProvider);
  final notifier = ref.watch(notificationServiceProvider);
  final audit = ref.watch(auditLogServiceProvider);
  return RequestService(db, notificationService: notifier, audit: audit);
});

final donorServiceProvider = Provider<DonorService>((ref) {
  final db = ref.watch(databaseServiceProvider);
  final audit = ref.watch(auditLogServiceProvider);
  return DonorService(db, audit: audit);
});

final hospitalServiceProvider = Provider<HospitalService>((ref) {
  return HospitalService(ref.watch(databaseServiceProvider));
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
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  await FirebaseMessaging.instance.requestPermission();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await LocalNotificationService.init();
  await FirebaseMessaging.instance
      .setForegroundNotificationPresentationOptions(
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

    // Save token for currently logged-in user
    final user = authService.currentUser;
    if (user != null) {
      final token = await FirebaseMessaging.instance.getToken();
      await userService.updateFcmToken(user.uid, token);
    }

    // Also save whenever token refreshes
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final user = authService.currentUser;
      if (user != null) {
        await userService.updateFcmToken(user.uid, newToken);
      }
    });

    // Also listen for auth state changes to save token on login
    authService.onAuthStateChanged.listen((user) async {
      if (user != null) {
        final token = await FirebaseMessaging.instance.getToken();
        await userService.updateFcmToken(user.uid, token);
      }
    });
  }

  Future<void> _setupFcmListeners() async {
    // Single onMessage listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        print('Foreground message: ${notification.title}');

        // Show system banner
        LocalNotificationService.show(
          title: notification.title ?? '',
          body: notification.body ?? '',
        );
      }
    });

    // Background tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification tapped: ${message.data}');
    });

    // Terminated tap
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      print('Opened from terminated: ${initial.data}');
    }
  }
  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'BloodConnect',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}