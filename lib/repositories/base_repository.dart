import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/cache_service.dart';
import 'package:bloodconnect/services/invalidation_service.dart';
import 'package:bloodconnect/services/persistent_cache_service.dart';

abstract class BaseRepository {
  final ApiClient apiClient;
  final CacheService? cacheService;
  final PersistentCacheService? persistentCacheService;
  final InvalidationService? invalidationService;

  BaseRepository({
    required this.apiClient,
    this.cacheService,
    this.persistentCacheService,
    this.invalidationService,
  });

  Future<T> cacheFirst<T>({
    required String cacheKey,
    required Future<T> Function() fetch,
    Duration? freshTtl,
    Duration? maxTtl,
  }) async {
    if (cacheService != null) {
      final cached = cacheService!.get<T>(cacheKey);
      if (cached != null) return cached;
    }

    if (persistentCacheService != null) {
      final result = await persistentCacheService!.getWithStaleness(cacheKey);
      if (result != null) {
        cacheService?.set(cacheKey, result.data as T);
        if (result.isStale) {
          _backgroundRefresh(cacheKey, fetch, freshTtl, maxTtl);
        }
        return result.data as T;
      }
    }

    final data = await fetch();
    cacheService?.set(cacheKey, data);
    return data;
  }

  Future<void> _backgroundRefresh<T>(
    String cacheKey,
    Future<T> Function() fetch,
    Duration? freshTtl,
    Duration? maxTtl,
  ) async {
    try {
      final data = await fetch();
      cacheService?.set(cacheKey, data);
    } catch (_) {}
  }

  Future<void> invalidatePrefix(String prefix) async {
    cacheService?.removeByPrefix(prefix);
    await persistentCacheService?.removeByPrefix(prefix);
  }

  Future<void> invalidateEntity(String entityId) async {
    await invalidationService?.invalidateEntity(entityId);
  }

  Future<void> invalidateTag(String tag) async {
    await invalidationService?.invalidateTag(tag);
  }

  Future<void> invalidateTags(Iterable<String> tags) async {
    await invalidationService?.invalidateTags(tags);
  }

  void registerEntityTag(String entityId, String cacheKeyPrefix) {
    invalidationService?.registerEntity(entityId, cacheKeyPrefix);
  }

  void registerTag(String tag, String cacheKeyPrefix) {
    invalidationService?.registerTag(tag, cacheKeyPrefix);
  }
}
