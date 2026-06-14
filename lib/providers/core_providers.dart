import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/cache_metrics_service.dart';
import 'package:bloodconnect/services/cache_service.dart';
import 'package:bloodconnect/services/notification_service.dart';
import 'package:bloodconnect/services/persistent_cache_service.dart';
import 'package:bloodconnect/services/sync_manager.dart';

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
      '/api/v1/hospital/inventory/history': const Duration(minutes: 1),
      '/api/v1/hospital/inventory': const Duration(seconds: 30),
      '/api/v1/hospital/low-inventory/alerts': const Duration(seconds: 30),
      '/api/v1/feedback/hospital': const Duration(minutes: 2),
      '/api/v1/feedback/recipient': const Duration(minutes: 2),
      '/api/v1/feedback/mine': const Duration(minutes: 2),
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

final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError('isarProvider must be overridden');
});

final persistentCacheServiceProvider = Provider<PersistentCacheService>((ref) {
  final isar = ref.watch(isarProvider);
  return PersistentCacheService(isar);
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

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final api = ref.watch(apiClientProvider);
  return NotificationService(api);
});
