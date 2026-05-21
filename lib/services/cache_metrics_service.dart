import 'package:flutter/foundation.dart';

class CacheMetricsSnapshot {
  final int memoryCacheHits;
  final int memoryCacheMisses;
  final int persistentCacheHits;
  final int persistentCacheMisses;
  final int staleCacheHits;
  final int apiRequestCount;
  final int cacheInvalidationCount;
  final int queueSuccesses;
  final int queueFailures;
  final Map<String, SyncMetrics> syncMetrics;

  CacheMetricsSnapshot({
    required this.memoryCacheHits,
    required this.memoryCacheMisses,
    required this.persistentCacheHits,
    required this.persistentCacheMisses,
    required this.staleCacheHits,
    required this.apiRequestCount,
    required this.cacheInvalidationCount,
    required this.queueSuccesses,
    required this.queueFailures,
    required this.syncMetrics,
  });

  double get memoryHitRate {
    final total = memoryCacheHits + memoryCacheMisses;
    if (total == 0) return 0;
    return memoryCacheHits / total;
  }

  double get persistentHitRate {
    final total = persistentCacheHits + persistentCacheMisses;
    if (total == 0) return 0;
    return persistentCacheHits / total;
  }
}

class SyncMetrics {
  final int totalDurationMs;
  final int callCount;

  SyncMetrics({required this.totalDurationMs, required this.callCount});

  int get averageDurationMs =>
      callCount > 0 ? totalDurationMs ~/ callCount : 0;

  Map<String, dynamic> toJson() => {
        'totalDurationMs': totalDurationMs,
        'callCount': callCount,
        'averageDurationMs': averageDurationMs,
      };
}

class CacheMetricsService {
  int _memoryCacheHits = 0;
  int _memoryCacheMisses = 0;
  int _persistentCacheHits = 0;
  int _persistentCacheMisses = 0;
  int _staleCacheHits = 0;
  int _apiRequestCount = 0;
  int _cacheInvalidationCount = 0;
  int _queueSuccesses = 0;
  int _queueFailures = 0;
  final Map<String, int> _syncTotalDurationMs = {};
  final Map<String, int> _syncCallCounts = {};
  bool _enabled;

  CacheMetricsService({bool? enabled}) : _enabled = enabled ?? kDebugMode;

  bool get isEnabled => _enabled;

  void setEnabled(bool v) => _enabled = v;

  void recordMemoryHit() {
    if (_enabled) _memoryCacheHits++;
  }

  void recordMemoryMiss() {
    if (_enabled) _memoryCacheMisses++;
  }

  void recordPersistentHit() {
    if (_enabled) _persistentCacheHits++;
  }

  void recordPersistentMiss() {
    if (_enabled) _persistentCacheMisses++;
  }

  void recordStaleHit() {
    if (_enabled) _staleCacheHits++;
  }

  void recordApiRequest() {
    if (_enabled) _apiRequestCount++;
  }

  void recordInvalidation() {
    if (_enabled) _cacheInvalidationCount++;
  }

  void recordQueueSuccess() {
    if (_enabled) _queueSuccesses++;
  }

  void recordQueueFailure() {
    if (_enabled) _queueFailures++;
  }

  void recordSyncDuration(String endpoint, int durationMs) {
    if (!_enabled) return;
    _syncTotalDurationMs.update(
      endpoint,
      (v) => v + durationMs,
      ifAbsent: () => durationMs,
    );
    _syncCallCounts.update(endpoint, (v) => v + 1, ifAbsent: () => 1);
  }

  CacheMetricsSnapshot snapshot() {
    final syncMetrics = <String, SyncMetrics>{};
    for (final key in _syncTotalDurationMs.keys) {
      syncMetrics[key] = SyncMetrics(
        totalDurationMs: _syncTotalDurationMs[key] ?? 0,
        callCount: _syncCallCounts[key] ?? 0,
      );
    }
    return CacheMetricsSnapshot(
      memoryCacheHits: _memoryCacheHits,
      memoryCacheMisses: _memoryCacheMisses,
      persistentCacheHits: _persistentCacheHits,
      persistentCacheMisses: _persistentCacheMisses,
      staleCacheHits: _staleCacheHits,
      apiRequestCount: _apiRequestCount,
      cacheInvalidationCount: _cacheInvalidationCount,
      queueSuccesses: _queueSuccesses,
      queueFailures: _queueFailures,
      syncMetrics: syncMetrics,
    );
  }

  void reset() {
    _memoryCacheHits = 0;
    _memoryCacheMisses = 0;
    _persistentCacheHits = 0;
    _persistentCacheMisses = 0;
    _staleCacheHits = 0;
    _apiRequestCount = 0;
    _cacheInvalidationCount = 0;
    _queueSuccesses = 0;
    _queueFailures = 0;
    _syncTotalDurationMs.clear();
    _syncCallCounts.clear();
  }

  void logSummary() {
    if (!_enabled) return;
    final s = snapshot();
    debugPrint('--- Cache Metrics ---');
    debugPrint('Memory cache hit rate: ${(s.memoryHitRate * 100).toStringAsFixed(1)}%');
    debugPrint('Persistent cache hit rate: ${(s.persistentHitRate * 100).toStringAsFixed(1)}%');
    debugPrint('Stale cache hits: ${s.staleCacheHits}');
    debugPrint('API requests: ${s.apiRequestCount}');
    debugPrint('Invalidations: ${s.cacheInvalidationCount}');
    debugPrint('Queue success/fail: ${s.queueSuccesses}/${s.queueFailures}');
    debugPrint('---');
  }
}
