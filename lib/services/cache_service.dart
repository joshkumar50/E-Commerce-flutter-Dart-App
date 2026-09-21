import 'dart:async';
import 'package:opem/utils/observability.dart';

class _CacheEntry<T> {
  final T value;
  final DateTime expiresAt;
  DateTime lastAccessed;

  _CacheEntry({
    required this.value,
    required this.expiresAt,
  }) : lastAccessed = DateTime.now();

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// High-Performance In-Memory Cache with TTL, LRU Eviction & Reactive Invalidation
///
/// NON-NEGOTIABLE ARCHITECTURAL RULE:
/// Only static or semi-static read data (categories, catalog lists, profile metadata)
/// may be cached. Authoritative checkout calculations, stock availability,
/// and payment status must NEVER rely on cached data.
class CacheService {
  static final CacheService instance = CacheService._();
  CacheService._();

  final Map<String, _CacheEntry<dynamic>> _cache = {};
  final int maxEntries = 200;

  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  int get hits => _hits;
  int get misses => _misses;
  int get size => _cache.length;

  /// Retrieve item from cache if present and unexpired
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) {
      _misses++;
      return null;
    }

    if (entry.isExpired) {
      _cache.remove(key);
      _misses++;
      return null;
    }

    entry.lastAccessed = DateTime.now();
    _hits++;
    return entry.value as T;
  }

  /// Store item in cache with explicit TTL
  void set<T>(String key, T value, {Duration ttl = const Duration(minutes: 5)}) {
    _enforceCapacity();
    _cache[key] = _CacheEntry<T>(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  /// Read-through helper: returns cached value or executes fetcher and caches result
  Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    final cached = get<T>(key);
    if (cached != null) {
      return cached;
    }

    final fresh = await fetcher();
    set<T>(key, fresh, ttl: ttl);
    return fresh;
  }

  /// Invalidate a specific key
  void invalidate(String key) {
    _cache.remove(key);
  }

  /// Reactive invalidation for all keys starting with prefix (e.g. 'products:')
  void invalidatePrefix(String prefix) {
    final toRemove = _cache.keys.where((k) => k.startsWith(prefix)).toList();
    for (final k in toRemove) {
      _cache.remove(k);
    }
    AppObservability.info(
      'Invalidated ${toRemove.length} cache entries matching prefix "$prefix"',
      operation: 'cache_invalidation',
    );
  }

  /// Clear entire cache
  void clear() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
    _evictions = 0;
  }

  void _enforceCapacity() {
    if (_cache.length >= maxEntries) {
      // LRU eviction: remove oldest lastAccessed entry
      String? oldestKey;
      DateTime? oldestTime;

      for (final entry in _cache.entries) {
        if (oldestTime == null || entry.value.lastAccessed.isBefore(oldestTime)) {
          oldestTime = entry.value.lastAccessed;
          oldestKey = entry.key;
        }
      }

      if (oldestKey != null) {
        _cache.remove(oldestKey);
        _evictions++;
      }
    }
  }

  Map<String, dynamic> getStats() {
    final total = _hits + _misses;
    final hitRate = total > 0 ? (_hits / total) * 100 : 0.0;
    return {
      'size': _cache.length,
      'max_entries': maxEntries,
      'hits': _hits,
      'misses': _misses,
      'evictions': _evictions,
      'hit_rate_pct': hitRate.toStringAsFixed(1),
    };
  }
}

final cacheService = CacheService.instance;
