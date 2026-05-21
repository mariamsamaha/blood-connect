import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:bloodconnect/models/pending_mutation.dart';
import 'package:bloodconnect/services/cache_metrics_service.dart';
import 'package:bloodconnect/services/cache_service.dart';
import 'package:bloodconnect/services/sync_manager.dart';

typedef MutationExecutor = Future<void> Function(
  String endpoint,
  String method,
  Map<String, dynamic>? payload,
);

class MutationQueueService {
  final MutationExecutor _executor;
  final SyncManager _syncManager;
  final File _queueFile;
  final CacheService? _cacheService;
  final CacheMetricsService? _metrics;
  List<PendingMutation> _queue = [];
  bool _isProcessing = false;
  Timer? _retryTimer;
  final StreamController<void> _queueChangedController =
      StreamController<void>.broadcast();

  static const int _maxRetries = 5;
  static const Duration _baseRetryDelay = Duration(seconds: 5);
  static const int _maxQueueSize = 200;
  static const Duration _retryJitter = Duration(milliseconds: 1000);

  Stream<void> get onQueueChanged => _queueChangedController.stream;
  List<PendingMutation> get pendingMutations =>
      _queue.where((m) => m.status == 'pending').toList();
  List<PendingMutation> get deadLetterMutations =>
      _queue.where((m) => m.status == 'dead_letter').toList();
  int get pendingCount =>
      _queue.where((m) => m.status == 'pending').length;

  MutationQueueService({
    required MutationExecutor executor,
    required SyncManager syncManager,
    required String storagePath,
    CacheService? cacheService,
    CacheMetricsService? metrics,
  })  : _executor = executor,
        _syncManager = syncManager,
        _cacheService = cacheService,
        _metrics = metrics,
        _queueFile = File('$storagePath/mutation_queue.json');

  Future<void> initialize() async {
    await _loadQueue();
    _syncManager.onStatusChanged.listen((status) {
      if (status == ConnectivityStatus.online) {
        _processQueue();
      }
    });
    if (_syncManager.isOnline) {
      _processQueue();
    }
  }

  Future<void> enqueue({
    required String endpoint,
    required String method,
    Map<String, dynamic>? payload,
    Map<String, String>? headers,
    int priority = 0,
    String? optimisticCacheKey,
    Map<String, dynamic>? optimisticData,
  }) async {
    _queue.removeWhere(
      (m) =>
          m.endpoint == endpoint &&
          m.method == method &&
          m.status == 'pending' &&
          _equalPayload(m.payload, payload),
    );

    if (_queue.length >= _maxQueueSize) {
      _queue.sort((a, b) => a.priority.compareTo(b.priority));
      _queue.removeAt(0);
    }

    final mutation = PendingMutation(
      endpoint: endpoint,
      method: method,
      payload: payload,
      headers: headers,
      priority: priority,
      optimisticCacheKey: optimisticCacheKey,
      optimisticData: optimisticData,
    );
    _queue.add(mutation);
    await _persist();
    _queueChangedController.add(null);

    if (_syncManager.isOnline) {
      _processQueue();
    }
  }

  Future<void> retryDeadLetters() async {
    for (final m in _queue) {
      if (m.status == 'dead_letter') {
        m.status = 'pending';
        m.retryCount = 0;
      }
    }
    await _persist();
    _queueChangedController.add(null);
    if (_syncManager.isOnline) {
      _processQueue();
    }
  }

  Future<void> clearAll() async {
    _queue.clear();
    await _persist();
    _queueChangedController.add(null);
  }

  Future<void> clearDeadLetters() async {
    _queue.removeWhere((m) => m.status == 'dead_letter');
    await _persist();
    _queueChangedController.add(null);
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      while (_queue.any((m) => m.status == 'pending')) {
        final mutations = _queue
            .where((m) => m.status == 'pending')
            .toList()
          ..sort((a, b) => b.priority.compareTo(a.priority));

        for (final mutation in mutations) {
          mutation.status = 'processing';
          await _persist();

          try {
            await _executor(mutation.endpoint, mutation.method, mutation.payload);
            _rollbackOptimistic(mutation);
            mutation.status = 'completed';
            _queue.remove(mutation);
            _metrics?.recordQueueSuccess();
          } catch (e) {
            debugPrint('Mutation failed (${mutation.id}): $e');
            mutation.retryCount++;
            if (mutation.retryCount >= _maxRetries) {
              mutation.status = 'dead_letter';
              _metrics?.recordQueueFailure();
              debugPrint(
                'Mutation ${mutation.id} moved to dead-letter queue',
              );
            } else {
              mutation.status = 'pending';
              _scheduleRetry();
            }
          }
          await _persist();
          _queueChangedController.add(null);
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  void _rollbackOptimistic(PendingMutation mutation) {
    if (mutation.optimisticCacheKey != null &&
        mutation.optimisticData != null) {
      _cacheService?.remove(mutation.optimisticCacheKey!);
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final minRetry = _queue
        .where((m) => m.status == 'pending' && m.retryCount > 0)
        .fold<int>(_maxRetries, (min, m) => m.retryCount < min ? m.retryCount : min);

    final exponentialDelay =
        _baseRetryDelay * pow(2, minRetry - 1).toInt();
    final jitter = Duration(
      milliseconds: Random().nextInt(_retryJitter.inMilliseconds),
    );
    final totalDelay = exponentialDelay + jitter;

    _retryTimer = Timer(totalDelay, _processQueue);
  }

  Future<void> _loadQueue() async {
    try {
      if (await _queueFile.exists()) {
        final content = await _queueFile.readAsString();
        if (content.trim().isEmpty) {
          _queue = [];
          return;
        }
        final list = jsonDecode(content) as List;
        _queue = list
            .map((e) =>
                PendingMutation.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((m) => m.status != 'completed')
            .toList();
      }
    } catch (e) {
      debugPrint('Failed to load mutation queue: $e');
      _queue = [];
    }
  }

  Future<void> _persist() async {
    try {
      final active = _queue.where((m) => m.status != 'completed').toList();
      final content = jsonEncode(active.map((e) => e.toJson()).toList());
      await _queueFile.writeAsString(content, flush: true);
    } catch (e) {
      debugPrint('Failed to persist mutation queue: $e');
    }
  }

  bool _equalPayload(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    return a.entries.every((e) => b[e.key] == e.value);
  }

  void dispose() {
    _retryTimer?.cancel();
    _queueChangedController.close();
  }
}
