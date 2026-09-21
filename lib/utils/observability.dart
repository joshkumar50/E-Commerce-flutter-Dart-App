import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Standard Log Levels
enum LogLevel { debug, info, warn, error }

/// Structured Log Record for Production Observability
class LogRecord {
  final LogLevel level;
  final String message;
  final String? requestId;
  final String? operation;
  final Duration? durationMs;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;
  final Object? error;
  final StackTrace? stackTrace;

  LogRecord({
    required this.level,
    required this.message,
    this.requestId,
    this.operation,
    this.durationMs,
    this.metadata,
    DateTime? timestamp,
    this.error,
    this.stackTrace,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name.toUpperCase(),
      'message': message,
      if (requestId != null) 'request_id': requestId,
      if (operation != null) 'operation': operation,
      if (durationMs != null) 'duration_ms': durationMs!.inMilliseconds,
      if (metadata != null) 'metadata': AppObservability.sanitize(metadata!),
      if (error != null) 'error': error.toString(),
    };
  }
}

/// Latency and Observability Tracker for SLOs / Performance Budgets
class PerformanceTracker {
  static final PerformanceTracker instance = PerformanceTracker._();
  PerformanceTracker._();

  final Map<String, List<int>> _latenciesMs = {};
  final Map<String, int> _errorCounts = {};
  final Map<String, int> _successCounts = {};

  void recordLatency(String operation, int latencyMs) {
    _latenciesMs.putIfAbsent(operation, () => []).add(latencyMs);
    // Keep max 1,000 samples per operation to avoid unbounded memory growth
    if (_latenciesMs[operation]!.length > 1000) {
      _latenciesMs[operation]!.removeAt(0);
    }
  }

  void recordSuccess(String operation) {
    _successCounts[operation] = (_successCounts[operation] ?? 0) + 1;
  }

  void recordError(String operation) {
    _errorCounts[operation] = (_errorCounts[operation] ?? 0) + 1;
  }

  /// Calculates P50, P90, P95, P99 latencies for an operation
  Map<String, dynamic> getStats(String operation) {
    final list = _latenciesMs[operation];
    if (list == null || list.isEmpty) {
      return {
        'count': 0,
        'p50_ms': 0,
        'p95_ms': 0,
        'p99_ms': 0,
        'successes': _successCounts[operation] ?? 0,
        'errors': _errorCounts[operation] ?? 0,
      };
    }

    final sorted = List<int>.from(list)..sort();
    int percentile(double p) {
      final idx = (p * (sorted.length - 1)).round();
      return sorted[idx];
    }

    return {
      'count': sorted.length,
      'p50_ms': percentile(0.50),
      'p90_ms': percentile(0.90),
      'p95_ms': percentile(0.95),
      'p99_ms': percentile(0.99),
      'min_ms': sorted.first,
      'max_ms': sorted.last,
      'successes': _successCounts[operation] ?? 0,
      'errors': _errorCounts[operation] ?? 0,
    };
  }

  void reset() {
    _latenciesMs.clear();
    _errorCounts.clear();
    _successCounts.clear();
  }
}

/// Centralized Observability & Safe Resilience Engine
class AppObservability {
  static const _uuid = Uuid();
  static final _random = Random();

  /// Generates unique correlation ID for end-to-end tracing
  static String newRequestId() => 'req_${_uuid.v4().substring(0, 8)}';

  /// Redacts sensitive credentials (passwords, tokens, payment secrets)
  static Map<String, dynamic> sanitize(Map<String, dynamic> data) {
    final clean = <String, dynamic>{};
    const sensitiveKeys = {
      'password', 'token', 'secret', 'authorization',
      'key', 'credit_card', 'cvv', 'access_token', 'refresh_token'
    };

    for (final entry in data.entries) {
      final keyLower = entry.key.toLowerCase();
      if (sensitiveKeys.any((s) => keyLower.contains(s))) {
        clean[entry.key] = '[REDACTED]';
      } else if (entry.value is Map<String, dynamic>) {
        clean[entry.key] = sanitize(entry.value as Map<String, dynamic>);
      } else {
        clean[entry.key] = entry.value;
      }
    }
    return clean;
  }

  /// Structured Logging
  static void log(LogRecord record) {
    if (kDebugMode) {
      final durationStr = record.durationMs != null ? ' (${record.durationMs!.inMilliseconds}ms)' : '';
      final reqStr = record.requestId != null ? '[${record.requestId}] ' : '';
      debugPrint('${record.timestamp.toIso8601String()} [${record.level.name.toUpperCase()}] $reqStr${record.message}$durationStr');
      if (record.metadata != null) {
        debugPrint('   Metadata: ${sanitize(record.metadata!)}');
      }
      if (record.error != null) {
        debugPrint('   Error: ${record.error}');
      }
    }
  }

  static void info(String message, {String? requestId, String? operation, Map<String, dynamic>? metadata}) {
    log(LogRecord(level: LogLevel.info, message: message, requestId: requestId, operation: operation, metadata: metadata));
  }

  static void warn(String message, {String? requestId, String? operation, Map<String, dynamic>? metadata, Object? error}) {
    log(LogRecord(level: LogLevel.warn, message: message, requestId: requestId, operation: operation, metadata: metadata, error: error));
  }

  static void error(String message, {String? requestId, String? operation, Map<String, dynamic>? metadata, Object? error, StackTrace? stackTrace}) {
    log(LogRecord(level: LogLevel.error, message: message, requestId: requestId, operation: operation, metadata: metadata, error: error, stackTrace: stackTrace));
  }

  /// Measure operation execution latency and record to performance statistics
  static Future<T> measure<T>({
    required String operation,
    required Future<T> Function(String requestId) action,
    Map<String, dynamic>? metadata,
  }) async {
    final requestId = newRequestId();
    final stopwatch = Stopwatch()..start();
    try {
      final result = await action(requestId);
      stopwatch.stop();
      final duration = stopwatch.elapsed;

      PerformanceTracker.instance.recordLatency(operation, duration.inMilliseconds);
      PerformanceTracker.instance.recordSuccess(operation);

      log(LogRecord(
        level: LogLevel.info,
        message: 'Completed $operation',
        requestId: requestId,
        operation: operation,
        durationMs: duration,
        metadata: metadata,
      ));
      return result;
    } catch (err, stack) {
      stopwatch.stop();
      final duration = stopwatch.elapsed;

      PerformanceTracker.instance.recordLatency(operation, duration.inMilliseconds);
      PerformanceTracker.instance.recordError(operation);

      log(LogRecord(
        level: LogLevel.error,
        message: 'Failed $operation: $err',
        requestId: requestId,
        operation: operation,
        durationMs: duration,
        metadata: metadata,
        error: err,
        stackTrace: stack,
      ));
      rethrow;
    }
  }

  /// Safe exponential backoff retry with jitter for idempotent operations
  static Future<T> retry<T>({
    required String operation,
    required Future<T> Function() action,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 150),
    double backoffMultiplier = 2.0,
    bool Function(dynamic error)? isRetryable,
  }) async {
    int attempt = 0;
    Duration currentDelay = initialDelay;

    while (true) {
      attempt++;
      try {
        return await action();
      } catch (err) {
        if (attempt >= maxAttempts || (isRetryable != null && !isRetryable(err))) {
          rethrow;
        }

        // Add 10-30% randomized jitter to prevent thundering herd
        final jitterMs = _random.nextInt((currentDelay.inMilliseconds * 0.3).round() + 1);
        final waitDuration = currentDelay + Duration(milliseconds: jitterMs);

        warn(
          'Transient error in $operation (attempt $attempt/$maxAttempts). Retrying in ${waitDuration.inMilliseconds}ms',
          operation: operation,
          error: err,
        );

        await Future.delayed(waitDuration);
        currentDelay = Duration(milliseconds: (currentDelay.inMilliseconds * backoffMultiplier).round());
      }
    }
  }
}
