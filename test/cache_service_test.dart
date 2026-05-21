import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/services/cache_service.dart';

void main() {
  group('CacheService', () {
    late CacheService cache;

    setUp(() {
      cache = CacheService(maxSize: 5);
    });

    group('set and get', () {
      test('stores and retrieves a value', () {
        cache.set('key1', 'value1');
        expect(cache.get<String>('key1'), 'value1');
      });

      test('returns null for missing key', () {
        expect(cache.get<String>('nonexistent'), isNull);
      });

      test('returns null for expired entry', () {
        cache.set('key1', 'value1', ttl: Duration(milliseconds: -1));
        expect(cache.get<String>('key1'), isNull);
      });

      test('supports complex types', () {
        cache.set('map', {'a': 1});
        cache.set('list', [1, 2, 3]);
        expect(cache.get<Map>('map'), {'a': 1});
        expect(cache.get<List>('list'), [1, 2, 3]);
      });
    });

    group('remove', () {
      test('removes a key', () {
        cache.set('key1', 'value1');
        cache.remove('key1');
        expect(cache.get<String>('key1'), isNull);
      });

      test('no-op for missing key', () {
        cache.remove('nonexistent');
        expect(cache.size, 0);
      });
    });

    group('removeByPrefix', () {
      test('removes all keys with given prefix', () {
        cache.set('api/v1/users/me', 'data1');
        cache.set('api/v1/users/me/badges', 'data2');
        cache.set('api/v1/hospitals', 'data3');
        cache.removeByPrefix('api/v1/users');
        expect(cache.get<String>('api/v1/users/me'), isNull);
        expect(cache.get<String>('api/v1/users/me/badges'), isNull);
        expect(cache.get<String>('api/v1/hospitals'), 'data3');
      });
    });

    group('clear', () {
      test('removes all entries', () {
        cache.set('a', 1);
        cache.set('b', 2);
        cache.clear();
        expect(cache.size, 0);
      });
    });

    group('evictExpired', () {
      test('removes only expired entries', () {
        cache.set('fresh', 'ok', ttl: Duration(hours: 1));
        cache.set('stale', 'bad', ttl: Duration(milliseconds: -1));
        cache.evictExpired();
        expect(cache.get<String>('fresh'), 'ok');
        expect(cache.get<String>('stale'), isNull);
      });
    });

    group('evictLRU', () {
      test('evicts oldest entries', () {
        cache.set('a', 1);
        cache.set('b', 2);
        cache.set('c', 3);
        cache.set('d', 4);
        cache.set('e', 5);
        cache.evictLRU(3);
        expect(cache.size, 3);
      });
    });

    group('maxSize enforcement', () {
      test('evicts entries when exceeding max size', () {
        for (int i = 0; i < 10; i++) {
          cache.set('key$i', i);
        }
        expect(cache.size <= cache.maxSize, isTrue);
      });
    });

    group('TTL overrides', () {
      test('uses default TTL for unmatching keys', () {
        cache.set('unknown/path', 'val');
        expect(cache.get<String>('unknown/path'), 'val');
      });

      test('uses custom TTL from overrides map', () {
        final custom = CacheService(ttlOverrides: {
          '/api/v1/hospitals': Duration(minutes: 5),
        }, maxSize: 200);
        custom.set('/api/v1/hospitals', 'val');
        expect(custom.get<String>('/api/v1/hospitals'), 'val');
      });
    });
  });
}
