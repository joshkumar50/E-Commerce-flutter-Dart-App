import 'dart:async';

class _Bucket {
  int tokens;
  DateTime lastRefill;

  _Bucket({required this.tokens, required this.lastRefill});
}

class RateLimiter {
  final int maxCalls;
  final Duration window;
  final Map<String, _Bucket> _buckets = {};

  RateLimiter({required this.maxCalls, required this.window});

  Future<bool> tryAcquire(String key) async {
    final now = DateTime.now();
    
    if (!_buckets.containsKey(key)) {
      _buckets[key] = _Bucket(tokens: maxCalls - 1, lastRefill: now);
      return true;
    }

    final bucket = _buckets[key]!;
    final diff = now.difference(bucket.lastRefill);

    if (diff >= window) {
      // Window elapsed, refill tokens
      bucket.tokens = maxCalls - 1;
      bucket.lastRefill = now;
      return true;
    }

    if (bucket.tokens > 0) {
      bucket.tokens--;
      return true;
    }

    return false; // Limit exceeded
  }

  void reset(String key) {
    _buckets.remove(key);
  }
}
