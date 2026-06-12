import 'dart:convert';

import 'package:isar_community/isar.dart';

import 'package:bloodconnect/models/cache_entry.dart';

class CacheResult {
  final Map<String, dynamic> data;
  final bool isStale;

  CacheResult({required this.data, required this.isStale});
}

class PersistentCacheService {
  final Isar _isar;
  final int _maxEntries;

  PersistentCacheService(this._isar, {int maxEntries = 500})
      : _maxEntries = maxEntries;

  Future<void> save(
    String key,
    Map<String, dynamic> data, {
    Duration? freshTtl,
    Duration? maxTtl,
  }) async {
    final now = DateTime.now();
    final fresh = freshTtl ?? const Duration(minutes: 5);
    final max = maxTtl ?? const Duration(hours: 24);

    /// Retry loop — handles unique-index race when two concurrent writes
    /// both read null from findFirst() and both try to insert the same key.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _isar.writeTxn(() async {
          final existing =
              await _isar.cacheEntrys.where().keyEqualTo(key).findFirst();
          final entry = (existing ?? CacheEntry())
            ..key = key
            ..jsonData = jsonEncode(data)
            ..createdAt = now
            ..expiresAt = now.add(max)
            ..staleAt = now.add(fresh);
          await _isar.cacheEntrys.put(entry);
        });
        return;
      } on IsarError catch (_) {
        if (attempt == 2) rethrow;
        // unique index violation from a concurrent write — retry
      }
    }
  }

  Future<Map<String, dynamic>?> get(String key) async {
    final entry =
        await _isar.cacheEntrys.where().keyEqualTo(key).findFirst();
    if (entry == null) return null;

    final now = DateTime.now();
    if (now.isAfter(entry.expiresAt)) {
      await _isar.writeTxn(() async {
        await _isar.cacheEntrys.delete(entry.id);
      });
      return null;
    }

    return jsonDecode(entry.jsonData) as Map<String, dynamic>;
  }

  Future<CacheResult?> getWithStaleness(String key) async {
    final entry =
        await _isar.cacheEntrys.where().keyEqualTo(key).findFirst();
    if (entry == null) return null;

    final now = DateTime.now();
    if (now.isAfter(entry.expiresAt)) {
      await _isar.writeTxn(() async {
        await _isar.cacheEntrys.delete(entry.id);
      });
      return null;
    }

    final data = jsonDecode(entry.jsonData) as Map<String, dynamic>;
    final isStale = now.isAfter(entry.staleAt);

    return CacheResult(data: data, isStale: isStale);
  }

  Future<void> remove(String key) async {
    final entry =
        await _isar.cacheEntrys.where().keyEqualTo(key).findFirst();
    if (entry != null) {
      await _isar.writeTxn(() async {
        await _isar.cacheEntrys.delete(entry.id);
      });
    }
  }

  Future<void> removeByPrefix(String prefix) async {
    await _isar.writeTxn(() async {
      await _isar.cacheEntrys
          .filter()
          .keyStartsWith(prefix)
          .deleteAll();
    });
  }

  Future<void> clear() async {
    await _isar.writeTxn(() async {
      await _isar.cacheEntrys.clear();
    });
  }

  Future<void> removeExpired() async {
    final now = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.cacheEntrys
          .filter()
          .expiresAtLessThan(now)
          .deleteAll();
    });
  }

  Future<void> trim() async {
    final count = await _isar.cacheEntrys.count();
    if (count <= _maxEntries) return;

    final toDelete = count - _maxEntries;
    if (toDelete <= 0) return;

    final oldest = await _isar.cacheEntrys
        .where()
        .sortByCreatedAt()
        .limit(toDelete)
        .findAll();

    if (oldest.isEmpty) return;

    final ids = oldest.map((e) => e.id).toList();
    await _isar.writeTxn(() async {
      await _isar.cacheEntrys.deleteAll(ids);
    });
  }

  Future<int> get size => _isar.cacheEntrys.count();
}
