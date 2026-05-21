import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/repositories/base_repository.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:bloodconnect/services/cache_service.dart';
import 'package:bloodconnect/services/invalidation_service.dart';

class _MockFirebaseAuth extends Fake implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() => const Stream.empty();
}

class _TestRepository extends BaseRepository {
  _TestRepository({
    required super.apiClient,
    super.cacheService,
    super.invalidationService,
  });
}

void main() {
  group('BaseRepository', () {
    late CacheService cacheService;
    late ApiClient apiClient;

    setUp(() {
      cacheService = CacheService(maxSize: 10);
      apiClient = ApiClient(auth: _MockFirebaseAuth());
    });

    test('cacheFirst returns cached value from memory', () async {
      final repo = _TestRepository(apiClient: apiClient, cacheService: cacheService);
      cacheService.set('test-key', 'cached-value');
      int fetchCalls = 0;
      final result = await repo.cacheFirst<String>(
        cacheKey: 'test-key',
        fetch: () async {
          fetchCalls++;
          return 'fresh-value';
        },
      );
      expect(result, 'cached-value');
      expect(fetchCalls, 0);
    });

    test('cacheFirst calls fetch when cache misses', () async {
      final repo = _TestRepository(apiClient: apiClient, cacheService: cacheService);
      int fetchCalls = 0;
      final result = await repo.cacheFirst<String>(
        cacheKey: 'missing-key',
        fetch: () async {
          fetchCalls++;
          return 'fresh-value';
        },
      );
      expect(result, 'fresh-value');
      expect(fetchCalls, 1);
    });

    test('invalidatePrefix removes cache entries', () async {
      final repo = _TestRepository(apiClient: apiClient, cacheService: cacheService);
      cacheService.set('/api/v1/test/1', 'data');
      cacheService.set('/api/v1/test/2', 'data');
      cacheService.set('/api/v1/other', 'data');
      await repo.invalidatePrefix('/api/v1/test');
      expect(cacheService.get<String>('/api/v1/test/1'), isNull);
      expect(cacheService.get<String>('/api/v1/test/2'), isNull);
      expect(cacheService.get<String>('/api/v1/other'), 'data');
    });

    test('invalidateEntity and invalidateTag delegates to invalidation service', () async {
      final invalidation = InvalidationService(cache: cacheService);
      final repo = _TestRepository(
        apiClient: apiClient,
        cacheService: cacheService,
        invalidationService: invalidation,
      );
      repo.registerEntityTag('entity-1', '/api/v1/test');
      cacheService.set('/api/v1/test/key', 'data');
      await repo.invalidateEntity('entity-1');
      expect(cacheService.get<String>('/api/v1/test/key'), isNull);
    });

    test('invalidateTags delegates to invalidation service', () async {
      final invalidation = InvalidationService(cache: cacheService);
      final repo = _TestRepository(
        apiClient: apiClient,
        cacheService: cacheService,
        invalidationService: invalidation,
      );
      repo.registerTag('tag-a', '/api/v1/a');
      repo.registerTag('tag-b', '/api/v1/b');
      cacheService.set('/api/v1/a/key', 'data-a');
      cacheService.set('/api/v1/b/key', 'data-b');
      await repo.invalidateTags(['tag-a', 'tag-b']);
      expect(cacheService.get<String>('/api/v1/a/key'), isNull);
      expect(cacheService.get<String>('/api/v1/b/key'), isNull);
    });

    test('registerEntityTag and registerTag bind prefixes', () async {
      final invalidation = InvalidationService(cache: cacheService);
      final repo = _TestRepository(
        apiClient: apiClient,
        cacheService: cacheService,
        invalidationService: invalidation,
      );
      repo.registerEntityTag('e1', '/prefix/e1');
      repo.registerTag('t1', '/prefix/t1');
      cacheService.set('/prefix/e1/data', 'val');
      cacheService.set('/prefix/t1/data', 'val');
      await repo.invalidateEntity('e1');
      await repo.invalidateTag('t1');
      expect(cacheService.get<String>('/prefix/e1/data'), isNull);
      expect(cacheService.get<String>('/prefix/t1/data'), isNull);
    });
  });
}
