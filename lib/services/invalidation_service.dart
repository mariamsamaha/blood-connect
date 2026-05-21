import 'package:bloodconnect/services/cache_service.dart';
import 'package:bloodconnect/services/persistent_cache_service.dart';

class InvalidationService {
  final CacheService? _cache;
  final PersistentCacheService? _persistentCache;
  final Map<String, Set<String>> _entityIndex = {};
  final Map<String, Set<String>> _tagIndex = {};

  InvalidationService({
    CacheService? cache,
    PersistentCacheService? persistentCache,
  })  : _cache = cache,
        _persistentCache = persistentCache;

  void registerEntity(String entityId, String cacheKeyPrefix) {
    _entityIndex.putIfAbsent(entityId, () => {}).add(cacheKeyPrefix);
  }

  void registerTag(String tag, String cacheKeyPrefix) {
    _tagIndex.putIfAbsent(tag, () => {}).add(cacheKeyPrefix);
  }

  void unregister(String cacheKeyPrefix) {
    for (final set in _entityIndex.values) {
      set.remove(cacheKeyPrefix);
    }
    for (final set in _tagIndex.values) {
      set.remove(cacheKeyPrefix);
    }
    _entityIndex.removeWhere((_, set) => set.isEmpty);
    _tagIndex.removeWhere((_, set) => set.isEmpty);
  }

  Future<void> invalidateEntity(String entityId) async {
    final prefixes = _entityIndex[entityId];
    if (prefixes == null || prefixes.isEmpty) return;
    for (final prefix in prefixes) {
      _cache?.removeByPrefix(prefix);
      await _persistentCache?.removeByPrefix(prefix);
    }
  }

  Future<void> invalidateTag(String tag) async {
    final prefixes = _tagIndex[tag];
    if (prefixes == null || prefixes.isEmpty) return;
    for (final prefix in prefixes) {
      _cache?.removeByPrefix(prefix);
      await _persistentCache?.removeByPrefix(prefix);
    }
  }

  Future<void> invalidateTags(Iterable<String> tags) async {
    for (final tag in tags) {
      await invalidateTag(tag);
    }
  }

  Future<void> invalidateEntities(Iterable<String> entityIds) async {
    for (final id in entityIds) {
      await invalidateEntity(id);
    }
  }
}
