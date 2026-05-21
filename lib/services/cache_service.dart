import 'dart:collection';

class CacheEntry<T> {
  final T data;
  final DateTime expiresAt;

  CacheEntry(this.data, this.expiresAt);

  bool get isValid => DateTime.now().isBefore(expiresAt);
}

class CacheService {
  final LinkedHashMap<String, CacheEntry<dynamic>> _store =
      LinkedHashMap<String, CacheEntry<dynamic>>();
  final Map<String, Duration> _ttlOverrides;
  final int _maxSize;

  CacheService({
    Map<String, Duration>? ttlOverrides,
    int maxSize = 200,
  })  : _ttlOverrides = ttlOverrides ?? {},
        _maxSize = maxSize;

  static const Duration _defaultTtl = Duration(seconds: 60);

  Duration _ttl(String key) {
    for (final entry in _ttlOverrides.entries) {
      if (key.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return _defaultTtl;
  }

  void set(String key, dynamic data, {Duration? ttl}) {
    _evictIfNeeded();
    _store[key] = CacheEntry(data, DateTime.now().add(ttl ?? _ttl(key)));
  }

  T? get<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (!entry.isValid) {
      _store.remove(key);
      return null;
    }
    _store.remove(key);
    _store[key] = entry;
    return entry.data as T;
  }

  void remove(String key) {
    _store.remove(key);
  }

  void removeByPrefix(String prefix) {
    _store.removeWhere((key, _) => key.startsWith(prefix));
  }

  void clear() {
    _store.clear();
  }

  int get size => _store.length;
  int get maxSize => _maxSize;

  List<String> get keys => _store.keys.toList();

  void evictExpired() {
    _store.removeWhere((_, entry) => !entry.isValid);
  }

  void evictLRU([int? targetCount]) {
    final target = targetCount ?? (_maxSize * 0.7).round();
    while (_store.length > target) {
      _store.remove(_store.keys.first);
    }
  }

  void _evictIfNeeded() {
    evictExpired();
    if (_store.length >= _maxSize) {
      evictLRU();
    }
  }
}
