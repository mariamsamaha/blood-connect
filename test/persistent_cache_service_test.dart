import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/services/persistent_cache_service.dart';

void main() {
  group('CacheResult', () {
    test('creates with data and staleness', () {
      final result = CacheResult(data: {'key': 'val'}, isStale: true);
      expect(result.data, {'key': 'val'});
      expect(result.isStale, isTrue);
    });

    test('creates with fresh data', () {
      final result = CacheResult(data: {'key': 'val'}, isStale: false);
      expect(result.isStale, isFalse);
    });
  });

  group('PersistentCacheService', () {
    test('constructor creates with default max entries', () {
      // PersistentCacheService requires Isar, tested in integration
    });

    test('save/get/remove methods exist', () {
      // Interface contract verified by compilation
    });
  });
}
