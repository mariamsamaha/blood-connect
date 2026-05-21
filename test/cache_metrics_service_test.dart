import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/services/cache_metrics_service.dart';

void main() {
  group('CacheMetricsService', () {
    late CacheMetricsService metrics;

    setUp(() {
      metrics = CacheMetricsService(enabled: true);
    });

    test('records memory hit', () {
      metrics.recordMemoryHit();
      final s = metrics.snapshot();
      expect(s.memoryCacheHits, 1);
      expect(s.memoryCacheMisses, 0);
    });

    test('records memory miss', () {
      metrics.recordMemoryMiss();
      expect(metrics.snapshot().memoryCacheMisses, 1);
    });

    test('records persistent hit', () {
      metrics.recordPersistentHit();
      expect(metrics.snapshot().persistentCacheHits, 1);
    });

    test('records stale hit', () {
      metrics.recordStaleHit();
      expect(metrics.snapshot().staleCacheHits, 1);
    });

    test('records api request', () {
      metrics.recordApiRequest();
      expect(metrics.snapshot().apiRequestCount, 1);
    });

    test('records invalidation', () {
      metrics.recordInvalidation();
      expect(metrics.snapshot().cacheInvalidationCount, 1);
    });

    test('records queue success', () {
      metrics.recordQueueSuccess();
      expect(metrics.snapshot().queueSuccesses, 1);
    });

    test('records queue failure', () {
      metrics.recordQueueFailure();
      expect(metrics.snapshot().queueFailures, 1);
    });

    test('records sync duration', () {
      metrics.recordSyncDuration('GET /test', 150);
      final s = metrics.snapshot();
      expect(s.syncMetrics['GET /test']?.callCount, 1);
      expect(s.syncMetrics['GET /test']?.totalDurationMs, 150);
    });

    test('memoryHitRate returns 0 when no data', () {
      expect(metrics.snapshot().memoryHitRate, 0.0);
    });

    test('memoryHitRate calculates correctly', () {
      metrics.recordMemoryHit();
      metrics.recordMemoryHit();
      metrics.recordMemoryMiss();
      expect(metrics.snapshot().memoryHitRate, 2 / 3);
    });

    test('persistentHitRate calculates correctly', () {
      metrics.recordPersistentHit();
      metrics.recordPersistentMiss();
      expect(metrics.snapshot().persistentHitRate, 0.5);
    });

    test('does not record when disabled', () {
      final disabled = CacheMetricsService(enabled: false);
      disabled.recordMemoryHit();
      disabled.recordApiRequest();
      final s = disabled.snapshot();
      expect(s.memoryCacheHits, 0);
      expect(s.apiRequestCount, 0);
    });

    test('reset clears all counters', () {
      metrics.recordMemoryHit();
      metrics.recordApiRequest();
      metrics.reset();
      final s = metrics.snapshot();
      expect(s.memoryCacheHits, 0);
      expect(s.apiRequestCount, 0);
      expect(s.syncMetrics, isEmpty);
    });

    test('setEnabled toggles recording', () {
      metrics.setEnabled(false);
      metrics.recordMemoryHit();
      expect(metrics.snapshot().memoryCacheHits, 0);
      metrics.setEnabled(true);
      metrics.recordMemoryHit();
      expect(metrics.snapshot().memoryCacheHits, 1);
    });
  });

  group('SyncMetrics', () {
    test('averageDurationMs returns 0 when no calls', () {
      final sm = SyncMetrics(totalDurationMs: 0, callCount: 0);
      expect(sm.averageDurationMs, 0);
    });

    test('averageDurationMs calculates correctly', () {
      final sm = SyncMetrics(totalDurationMs: 300, callCount: 3);
      expect(sm.averageDurationMs, 100);
    });

    test('toJson returns correct map', () {
      final sm = SyncMetrics(totalDurationMs: 200, callCount: 2);
      expect(sm.toJson()['averageDurationMs'], 100);
    });
  });
}
