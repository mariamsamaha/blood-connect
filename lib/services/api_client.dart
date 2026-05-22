import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:bloodconnect/config/app_config.dart';
import 'package:bloodconnect/services/cache_metrics_service.dart';
import 'package:bloodconnect/services/cache_service.dart';
import 'package:bloodconnect/services/persistent_cache_service.dart';
import 'package:bloodconnect/services/sync_manager.dart';

typedef EnqueueMutationFn = Future<void> Function({
  required String endpoint,
  required String method,
  Map<String, dynamic>? payload,
  Map<String, String>? headers,
  int priority,
  String? optimisticCacheKey,
  Map<String, dynamic>? optimisticData,
});

class DeferredEnqueueMutation {
  EnqueueMutationFn? _impl;

  void bind(EnqueueMutationFn impl) {
    _impl = impl;
  }

  Future<void> call({
    required String endpoint,
    required String method,
    Map<String, dynamic>? payload,
    Map<String, String>? headers,
    int priority = 0,
    String? optimisticCacheKey,
    Map<String, dynamic>? optimisticData,
  }) async {
    if (_impl == null) {
      throw StateError('Mutation queue not initialized');
    }
    await _impl!(
      endpoint: endpoint,
      method: method,
      payload: payload,
      headers: headers,
      priority: priority,
      optimisticCacheKey: optimisticCacheKey,
      optimisticData: optimisticData,
    );
  }
}

class _TimeoutClient extends http.BaseClient {
  final http.Client _inner;
  final Duration timeout;

  _TimeoutClient(this._inner, {this.timeout = const Duration(seconds: 15)});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request).timeout(
        timeout,
        onTimeout: () => throw Exception('Request timed out after ${timeout.inSeconds}s'),
      );
}

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    FirebaseAuth? auth,
    CacheService? cache,
    PersistentCacheService? persistentCache,
    SyncManager? syncManager,
    CacheMetricsService? metrics,
    DeferredEnqueueMutation? enqueueMutation,
  })  : _http = httpClient != null
            ? _TimeoutClient(httpClient)
            : _TimeoutClient(http.Client()),
        _auth = auth ?? FirebaseAuth.instance,
        _cache = cache,
        _persistentCache = persistentCache,
        _syncManager = syncManager,
        _metrics = metrics,
        _enqueueMutation = enqueueMutation ?? DeferredEnqueueMutation() {
    _auth.authStateChanges().listen((user) {
      if (user == null) {
        _cache?.clear();
        _persistentCache?.clear();
      }
    });
  }

  final http.Client _http;
  final FirebaseAuth _auth;
  final CacheService? _cache;
  final PersistentCacheService? _persistentCache;
  final SyncManager? _syncManager;
  final CacheMetricsService? _metrics;
  final DeferredEnqueueMutation _enqueueMutation;

  final Map<String, Future<dynamic>> _inFlightRequests = {};

  String get _base => AppConfig.apiBaseUrl;

  Duration _freshTtl(String path) {
    if (_cache != null) return _cache!.ttlForKey(path);
    return const Duration(seconds: 60);
  }

  Duration _maxTtl(String path) {
    final fresh = _freshTtl(path);
    return Duration(seconds: fresh.inSeconds * 3);
  }

  bool get _isOffline => _syncManager != null && !_syncManager.isOnline;

  Future<Map<String, String>> _headers() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Not signed in');
    }
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw Exception('Could not obtain Firebase ID token');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>?> getJson(
    String path, {
    Map<String, String>? query,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _cacheKey(path, query);

    if (!forceRefresh) {
      if (_cache != null) {
        final cached = _cache.get<Map<String, dynamic>>(cacheKey);
        if (cached != null) {
          _metrics?.recordMemoryHit();
          return cached;
        }
      }
      _metrics?.recordMemoryMiss();

      if (_persistentCache != null) {
        final result = await _persistentCache.getWithStaleness(cacheKey);
        if (result != null) {
          _cache?.set(cacheKey, result.data);
          if (result.isStale) {
            _metrics?.recordStaleHit();
            if (!_isOffline) {
              _scheduleBackgroundRefresh(path, query, cacheKey);
            }
          } else {
            _metrics?.recordPersistentHit();
          }
          return result.data;
        }
      }
      _metrics?.recordPersistentMiss();

      if (_isOffline) {
        throw Exception('No cached data available offline');
      }
    }

    if (!forceRefresh) {
      final inFlight = _inFlightRequests[cacheKey];
      if (inFlight != null) {
        return await inFlight as Map<String, dynamic>?;
      }
    }

    final future = _fetchJson(path, query, cacheKey);
    _inFlightRequests[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inFlightRequests.remove(cacheKey);
    }
  }

  Future<List<Map<String, dynamic>>> getJsonList(
    String path, {
    Map<String, String>? query,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _cacheKey(path, query);

    if (!forceRefresh) {
      if (_cache != null) {
        final cached = _cache.get<List<Map<String, dynamic>>>(cacheKey);
        if (cached != null) {
          _metrics?.recordMemoryHit();
          return cached;
        }
      }
      _metrics?.recordMemoryMiss();

      if (_persistentCache != null) {
        final result = await _persistentCache.getWithStaleness(cacheKey);
        if (result != null) {
          final listData = _jsonToList(result.data);
          if (listData != null) {
            _cache?.set(cacheKey, listData);
            if (result.isStale) {
              _metrics?.recordStaleHit();
              if (!_isOffline) {
                _scheduleBackgroundRefresh(path, query, cacheKey);
              }
            } else {
              _metrics?.recordPersistentHit();
            }
            return listData;
          }
        }
      }
      _metrics?.recordPersistentMiss();

      if (_isOffline) {
        throw Exception('No cached data available offline');
      }
    }

    if (!forceRefresh) {
      final inFlight = _inFlightRequests[cacheKey];
      if (inFlight != null) {
        return await inFlight as List<Map<String, dynamic>>;
      }
    }

    final future = _fetchJsonList(path, query, cacheKey);
    _inFlightRequests[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inFlightRequests.remove(cacheKey);
    }
  }

  Future<Map<String, dynamic>> postJson(String path, {Object? body}) async {
    if (_isOffline) {
      await _enqueueMutation(
        endpoint: path,
        method: 'POST',
        payload: body as Map<String, dynamic>?,
      );
      return {};
    }
    await _invalidateCache(path);
    final start = DateTime.now();
    _metrics?.recordApiRequest();
    final response = await _http.post(
      Uri.parse('$_base$path'),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    final decoded = _decode(response);
    _metrics?.recordSyncDuration(
      'POST $path',
      DateTime.now().difference(start).inMilliseconds,
    );
    return decoded ?? {};
  }

  Future<void> patchJson(String path, {Object? body}) async {
    if (_isOffline) {
      await _enqueueMutation(
        endpoint: path,
        method: 'PATCH',
        payload: body as Map<String, dynamic>?,
      );
      return;
    }
    await _invalidateCache(path);
    final start = DateTime.now();
    _metrics?.recordApiRequest();
    final response = await _http.patch(
      Uri.parse('$_base$path'),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    _metrics?.recordSyncDuration(
      'PATCH $path',
      DateTime.now().difference(start).inMilliseconds,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    _throwForStatus(response);
  }

  Future<void> postEmpty(String path, {Object? body}) async {
    if (_isOffline) {
      await _enqueueMutation(
        endpoint: path,
        method: 'POST',
        payload: body as Map<String, dynamic>?,
      );
      return;
    }
    await _invalidateCache(path);
    final start = DateTime.now();
    _metrics?.recordApiRequest();
    final response = await _http.post(
      Uri.parse('$_base$path'),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    _metrics?.recordSyncDuration(
      'POST $path',
      DateTime.now().difference(start).inMilliseconds,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    _throwForStatus(response);
  }

  Future<void> deleteJson(String path, {Object? body}) async {
    if (_isOffline) {
      await _enqueueMutation(
        endpoint: path,
        method: 'DELETE',
        payload: body as Map<String, dynamic>?,
      );
      return;
    }
    await _invalidateCache(path);
    final start = DateTime.now();
    _metrics?.recordApiRequest();
    final response = await _http.delete(
      Uri.parse('$_base$path'),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    _metrics?.recordSyncDuration(
      'DELETE $path',
      DateTime.now().difference(start).inMilliseconds,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    _throwForStatus(response);
  }

  Future<void> clearCache() async {
    _cache?.clear();
    await _persistentCache?.clear();
  }

  Future<Map<String, dynamic>?> _fetchJson(
    String path,
    Map<String, String>? query,
    String cacheKey,
  ) async {
    final start = DateTime.now();
    _metrics?.recordApiRequest();
    final uri = Uri.parse('$_base$path').replace(queryParameters: query);
    final response = await _http.get(uri, headers: await _headers());
    final result = _decode(response);
    _metrics?.recordSyncDuration(
      'GET $path',
      DateTime.now().difference(start).inMilliseconds,
    );

    if (result != null) {
      _cache?.set(cacheKey, result);
      await _persistentCache?.save(
        cacheKey,
        result,
        freshTtl: _freshTtl(path),
        maxTtl: _maxTtl(path),
      );
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _fetchJsonList(
    String path,
    Map<String, String>? query,
    String cacheKey,
  ) async {
    final start = DateTime.now();
    _metrics?.recordApiRequest();
    final uri = Uri.parse('$_base$path').replace(queryParameters: query);
    final response = await _http.get(uri, headers: await _headers());
    _metrics?.recordSyncDuration(
      'GET $path',
      DateTime.now().difference(start).inMilliseconds,
    );
    if (response.statusCode == 204) return [];
    final body = jsonDecode(response.body);
    if (body is List) {
      final result =
          body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _cache?.set(cacheKey, result);
      final asMap = {'_list': result};
      await _persistentCache?.save(
        cacheKey,
        asMap,
        freshTtl: _freshTtl(path),
        maxTtl: _maxTtl(path),
      );
      return result;
    }
    _throwForStatus(response);
    return [];
  }

  List<Map<String, dynamic>>? _jsonToList(Map<String, dynamic> data) {
    final list = data['_list'];
    if (list is List) {
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return null;
  }

  final Map<String, Future<void>> _refreshInFlight = {};

  void _scheduleBackgroundRefresh(
    String path,
    Map<String, String>? query,
    String cacheKey,
  ) {
    if (_refreshInFlight.containsKey(cacheKey)) return;
    _refreshInFlight[cacheKey] = _backgroundRefresh(path, query, cacheKey);
    _refreshInFlight[cacheKey]!.then((_) {
      _refreshInFlight.remove(cacheKey);
    }).catchError((_) {
      _refreshInFlight.remove(cacheKey);
    });
  }

  Future<void> _backgroundRefresh(
    String path,
    Map<String, String>? query,
    String cacheKey,
  ) async {
    try {
      if (_isOffline) return;
      final start = DateTime.now();
      final uri = Uri.parse('$_base$path').replace(queryParameters: query);
      final response = await _http.get(uri, headers: await _headers());
      final decoded = _decode(response);
      if (decoded != null) {
        _cache?.set(cacheKey, decoded);
        await _persistentCache?.save(
          cacheKey,
          decoded,
          freshTtl: _freshTtl(path),
          maxTtl: _maxTtl(path),
        );
      }
      _metrics?.recordSyncDuration(
        'BG $path',
        DateTime.now().difference(start).inMilliseconds,
      );
    } catch (_) {}
  }

  String _cacheKey(String path, Map<String, String>? query) {
    final buffer = StringBuffer(path);
    if (query != null && query.isNotEmpty) {
      final sortedKeys = query.keys.toList()..sort();
      for (final k in sortedKeys) {
        buffer.write('&$k=${query[k]}');
      }
    }
    return buffer.toString();
  }

  Future<void> _invalidateCache(String path) async {
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length >= 3) {
      final prefix = '/${parts[0]}/${parts[1]}/${parts[2]}';
      _cache?.removeByPrefix(prefix);
      await _persistentCache?.removeByPrefix(prefix);
      _metrics?.recordInvalidation();
    }
  }

  Map<String, dynamic>? _decode(http.Response response) {
    if (response.statusCode == 204 || response.body.isEmpty) return null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final trimmed = response.body.trim();
      if (trimmed == 'null') return null;
      final body = jsonDecode(response.body);
      if (body == null) return null;
      if (body is Map) return Map<String, dynamic>.from(body);
      if (body is List) {
        debugPrint(
          'ApiClient: expected object, got list for ${response.request?.url}',
        );
        return null;
      }
    }
    _throwForStatus(response);
    return null;
  }

  void _throwForStatus(http.Response response) {
    String message = 'API error ${response.statusCode}';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] != null) {
        message = '${body['error']}';
        final detail = body['detail'];
        final hint = body['hint'];
        if (detail != null) message = '$message: $detail';
        if (hint != null) message = '$message\n$hint';
      }
    } catch (_) {}
    throw Exception(message);
  }
}
