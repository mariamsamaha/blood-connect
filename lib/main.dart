import 'dart:async';

import 'package:bloodconnect/services/local_notification_service.dart';
import 'package:bloodconnect/services/mutation_queue_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:bloodconnect/routing/app_router.dart';
import 'package:bloodconnect/routing/router_refresh.dart';
import 'package:bloodconnect/services/audit_log_service.dart';
import 'package:bloodconnect/services/user_service.dart';
import 'package:bloodconnect/services/cache_service.dart';
import 'package:bloodconnect/services/cache_metrics_service.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/auth_service.dart';
import 'package:bloodconnect/services/request_service.dart';
import 'package:bloodconnect/services/notification_service.dart';
import 'package:bloodconnect/services/location_service.dart';
import 'package:bloodconnect/services/donor_service.dart';
import 'package:bloodconnect/services/hospital_service.dart';
import 'package:bloodconnect/services/persistent_cache_service.dart';
import 'package:bloodconnect/services/sync_manager.dart';
import 'package:bloodconnect/services/invalidation_service.dart';
import 'package:bloodconnect/models/cache_entry.dart';
import 'package:bloodconnect/repositories/user_repository.dart';
import 'package:bloodconnect/repositories/donor_repository.dart';
import 'package:bloodconnect/repositories/request_repository.dart';
import 'package:bloodconnect/repositories/hospital_repository.dart';
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

final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService(
    ttlOverrides: {
      '/api/v1/donor/matches': const Duration(seconds: 30),
      '/api/v1/donor/mission': const Duration(seconds: 30),
      '/api/v1/requests/active': const Duration(seconds: 30),
      '/api/v1/hospital/pending': const Duration(seconds: 30),
      '/api/v1/hospitals': const Duration(minutes: 5),
      '/api/v1/donor/leaderboard': const Duration(minutes: 2),
      '/api/v1/users/me/badges': const Duration(minutes: 2),
      '/api/v1/donor/donations': const Duration(minutes: 2),
      '/api/v1/users/me': const Duration(minutes: 2),
    },
  );
});

final cacheMetricsServiceProvider = Provider<CacheMetricsService>((ref) {
  return CacheMetricsService();
});

final syncManagerProvider = Provider<SyncManager>((ref) {
  final manager = SyncManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

final connectivityStatusProvider = StreamProvider<ConnectivityStatus>((ref) {
  final syncManager = ref.watch(syncManagerProvider);
  return syncManager.onStatusChanged;
});

final isarProvider = FutureProvider<Isar>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  return Isar.open(
    [CacheEntrySchema],
    directory: dir.path,
    inspector: false,
  );
});

final persistentCacheServiceProvider = Provider<PersistentCacheService>((ref) {
  final isarAsync = ref.watch(isarProvider);
  final isar = isarAsync.value;
  if (isar == null) {
    throw StateError('Isar not initialized');
  }
  return PersistentCacheService(isar);
});

final invalidationServiceProvider = Provider<InvalidationService>((ref) {
  return InvalidationService(
    cache: ref.watch(cacheServiceProvider),
    persistentCache: ref.watch(persistentCacheServiceProvider),
  );
});

final deferredEnqueueMutationProvider =
    Provider<DeferredEnqueueMutation>((ref) {
  return DeferredEnqueueMutation();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final cache = ref.watch(cacheServiceProvider);
  final persistentCache = ref.watch(persistentCacheServiceProvider);
  final syncManager = ref.watch(syncManagerProvider);
  final metrics = ref.watch(cacheMetricsServiceProvider);
  final enqueueMutation = ref.watch(deferredEnqueueMutationProvider);
  return ApiClient(
    cache: cache,
    persistentCache: persistentCache,
    syncManager: syncManager,
    metrics: metrics,
    enqueueMutation: enqueueMutation,
  );
});

final mutationQueueServiceProvider = FutureProvider<MutationQueueService>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final syncManager = ref.watch(syncManagerProvider);
  final cacheService = ref.watch(cacheServiceProvider);
  final metrics = ref.watch(cacheMetricsServiceProvider);
  final deferredEnqueue = ref.watch(deferredEnqueueMutationProvider);
  final dir = await getApplicationDocumentsDirectory();

  final executor = (String endpoint, String method, Map<String, dynamic>? payload) async {
    if (!syncManager.isOnline) {
      throw Exception('Cannot execute mutation while offline');
    }
    switch (method.toUpperCase()) {
      case 'POST':
        await apiClient.postJson(endpoint, body: payload);
      case 'PATCH':
        await apiClient.patchJson(endpoint, body: payload);
      case 'DELETE':
        await apiClient.deleteJson(endpoint, body: payload);
    }
  };

  final service = MutationQueueService(
    executor: executor,
    syncManager: syncManager,
    storagePath: dir.path,
    cacheService: cacheService,
    metrics: metrics,
  );
  await service.initialize();

  deferredEnqueue.bind(
    ({
      required String endpoint,
      required String method,
      Map<String, dynamic>? payload,
      Map<String, String>? headers,
      int priority = 0,
      String? optimisticCacheKey,
      Map<String, dynamic>? optimisticData,
    }) async {
      await service.enqueue(
        endpoint: endpoint,
        method: method,
        payload: payload,
        headers: headers,
        priority: priority,
        optimisticCacheKey: optimisticCacheKey,
        optimisticData: optimisticData,
      );
    },
  );

  ref.onDispose(() => service.dispose());
  return service;
});

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

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    apiClient: ref.watch(apiClientProvider),
    userService: ref.watch(userServiceProvider),
    cacheService: ref.watch(cacheServiceProvider),
    persistentCacheService: ref.watch(persistentCacheServiceProvider),
    invalidationService: ref.watch(invalidationServiceProvider),
  );
});

final donorRepositoryProvider = Provider<DonorRepository>((ref) {
  return DonorRepository(
    apiClient: ref.watch(apiClientProvider),
    donorService: ref.watch(donorServiceProvider),
    cacheService: ref.watch(cacheServiceProvider),
    persistentCacheService: ref.watch(persistentCacheServiceProvider),
    invalidationService: ref.watch(invalidationServiceProvider),
  );
});

final requestRepositoryProvider = Provider<RequestRepository>((ref) {
  return RequestRepository(
    apiClient: ref.watch(apiClientProvider),
    requestService: ref.watch(requestServiceProvider),
    cacheService: ref.watch(cacheServiceProvider),
    persistentCacheService: ref.watch(persistentCacheServiceProvider),
    invalidationService: ref.watch(invalidationServiceProvider),
  );
});

final hospitalRepositoryProvider = Provider<HospitalRepository>((ref) {
  return HospitalRepository(
    apiClient: ref.watch(apiClientProvider),
    hospitalService: ref.watch(hospitalServiceProvider),
    cacheService: ref.watch(cacheServiceProvider),
    persistentCacheService: ref.watch(persistentCacheServiceProvider),
    invalidationService: ref.watch(invalidationServiceProvider),
  );
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
  late final Timer _cleanupTimer;
  late final Timer _metricsLogTimer;

  @override
  void initState() {
    super.initState();
    _setupFcmToken();
    _setupFcmListeners();
    _initMutationQueue();
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _runPeriodicCleanup(),
    );
    _metricsLogTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _logMetrics(),
    );
  }

  void _initMutationQueue() {
    ref.read(mutationQueueServiceProvider);
  }

  @override
  void dispose() {
    _cleanupTimer.cancel();
    _metricsLogTimer.cancel();
    super.dispose();
  }

  Future<void> _runPeriodicCleanup() async {
    try {
      final persistent = ref.read(persistentCacheServiceProvider);
      await persistent.removeExpired();
      await persistent.trim();
      final memory = ref.read(cacheServiceProvider);
      memory.evictExpired();
      memory.evictLRU();
    } catch (e) {
      debugPrint('Periodic cache cleanup error: $e');
    }
  }

  void _logMetrics() {
    ref.read(cacheMetricsServiceProvider).logSummary();
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
