import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/services/cache_service.dart';
import 'package:bloodconnect/services/invalidation_service.dart';

class _MockCacheService extends Fake implements CacheService {
  final List<String> removedPrefixes = [];

  @override
  void removeByPrefix(String prefix) {
    removedPrefixes.add(prefix);
  }
}

void main() {
  group('InvalidationService', () {
    late _MockCacheService cache;
    late InvalidationService service;

    setUp(() {
      cache = _MockCacheService();
      service = InvalidationService(cache: cache);
    });

    test('registerEntity stores prefix for entity', () async {
      service.registerEntity('entity-1', '/api/v1/requests');
      await service.invalidateEntity('entity-1');
      expect(cache.removedPrefixes, contains('/api/v1/requests'));
    });

    test('registerTag stores prefix for tag', () async {
      service.registerTag('tag-1', '/api/v1/users');
      await service.invalidateTag('tag-1');
      expect(cache.removedPrefixes, contains('/api/v1/users'));
    });

    test('invalidateEntity does nothing for unknown entity', () async {
      await service.invalidateEntity('nonexistent');
      expect(cache.removedPrefixes, isEmpty);
    });

    test('invalidateTag does nothing for unknown tag', () async {
      await service.invalidateTag('nonexistent');
      expect(cache.removedPrefixes, isEmpty);
    });

    test('unregister removes prefix from indices', () async {
      service.registerEntity('e1', '/prefix');
      service.registerTag('t1', '/prefix');
      service.unregister('/prefix');
      await service.invalidateEntity('e1');
      await service.invalidateTag('t1');
      expect(cache.removedPrefixes, isEmpty);
    });

    test('invalidateTags processes multiple tags', () async {
      service.registerTag('a', '/a');
      service.registerTag('b', '/b');
      await service.invalidateTags(['a', 'b']);
      expect(cache.removedPrefixes, containsAll(['/a', '/b']));
    });

    test('invalidateEntities processes multiple entities', () async {
      service.registerEntity('e1', '/e1');
      service.registerEntity('e2', '/e2');
      await service.invalidateEntities(['e1', 'e2']);
      expect(cache.removedPrefixes, containsAll(['/e1', '/e2']));
    });
  });
}
