import 'dart:async';
import 'observability.dart';

/// Circuit Breaker States
enum CircuitState { closed, open, halfOpen }

/// Exception thrown when a call is rejected by an open circuit breaker
class CircuitBreakerOpenException implements Exception {
  final String serviceName;
  final Duration retryAfter;

  const CircuitBreakerOpenException({
    required this.serviceName,
    required this.retryAfter,
  });

  @override
  String toString() =>
      'CircuitBreakerOpenException: Service "$serviceName" is unavailable. Circuit is OPEN. Retry after ${retryAfter.inSeconds}s.';
}

/// Production Circuit Breaker
/// Provides fault isolation, prevents cascading downstream failures,
/// and eliminates thread starvation during external provider degradation.
class CircuitBreaker {
  final String name;
  final int failureThreshold;
  final Duration resetTimeout;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  int _tripCount = 0;

  CircuitBreaker({
    required this.name,
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(seconds: 30),
  });

  CircuitState get state {
    _evaluateState();
    return _state;
  }
  int get failureCount => _failureCount;
  int get tripCount => _tripCount;

  /// Execute an asynchronous operation protected by the circuit breaker.
  /// If circuit is OPEN, throws [CircuitBreakerOpenException] or returns [fallback] immediately.
  Future<T> run<T>({
    required Future<T> Function() action,
    Future<T> Function(Object error)? fallback,
  }) async {
    _evaluateState();

    if (_state == CircuitState.open) {
      final remaining = resetTimeout - DateTime.now().difference(_lastFailureTime!);
      final error = CircuitBreakerOpenException(
        serviceName: name,
        retryAfter: remaining.isNegative ? Duration.zero : remaining,
      );

      AppObservability.warn(
        'CircuitBreaker [$name] rejected call (Circuit is OPEN)',
        operation: 'circuit_breaker_reject',
        metadata: {'service': name, 'trip_count': _tripCount},
      );

      if (fallback != null) {
        return await fallback(error);
      }
      throw error;
    }

    try {
      final result = await action();
      _onSuccess();
      return result;
    } catch (err) {
      _onFailure(err);
      if (fallback != null) {
        return await fallback(err);
      }
      rethrow;
    }
  }

  void _evaluateState() {
    if (_state == CircuitState.open && _lastFailureTime != null) {
      final elapsed = DateTime.now().difference(_lastFailureTime!);
      if (elapsed >= resetTimeout) {
        _state = CircuitState.halfOpen;
        AppObservability.info(
          'CircuitBreaker [$name] transition: OPEN -> HALF_OPEN (Probing service recovery)',
          operation: 'circuit_breaker_probe',
        );
      }
    }
  }

  void _onSuccess() {
    if (_state == CircuitState.halfOpen) {
      _state = CircuitState.closed;
      _failureCount = 0;
      _lastFailureTime = null;
      AppObservability.info(
        'CircuitBreaker [$name] transition: HALF_OPEN -> CLOSED (Service successfully recovered)',
        operation: 'circuit_breaker_recovered',
      );
    } else if (_state == CircuitState.closed) {
      _failureCount = 0;
    }
  }

  void _onFailure(Object error) {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_state == CircuitState.halfOpen || _failureCount >= failureThreshold) {
      _state = CircuitState.open;
      _tripCount++;
      AppObservability.warn(
        'CircuitBreaker [$name] tripped to OPEN (Failures: $_failureCount/$failureThreshold)',
        operation: 'circuit_breaker_trip',
        error: error,
      );
    }
  }

  /// Convenience alias for run
  Future<T> execute<T>(
    Future<T> Function() action, {
    Future<T> Function()? fallback,
  }) async {
    return run(
      action: action,
      fallback: fallback != null ? (_) => fallback() : null,
    );
  }

  /// Manually reset circuit to CLOSED
  void reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _lastFailureTime = null;
  }

  /// Manually trip circuit to OPEN
  void trip() {
    _state = CircuitState.open;
    _lastFailureTime = DateTime.now();
    _tripCount++;
  }
}

/// Global registry of circuit breakers for core external dependencies
class CircuitBreakerRegistry {
  static final CircuitBreakerRegistry instance = CircuitBreakerRegistry._();
  CircuitBreakerRegistry._();

  final Map<String, CircuitBreaker> _breakers = {};

  CircuitBreaker get(
    String name, {
    int failureThreshold = 5,
    Duration resetTimeout = const Duration(seconds: 30),
  }) {
    return _breakers.putIfAbsent(
      name,
      () => CircuitBreaker(
        name: name,
        failureThreshold: failureThreshold,
        resetTimeout: resetTimeout,
      ),
    );
  }

  static final CircuitBreaker paymentGateway = CircuitBreaker(
    name: 'payment_gateway',
    failureThreshold: 3,
    resetTimeout: const Duration(seconds: 20),
  );

  static final CircuitBreaker analyticsService = CircuitBreaker(
    name: 'analytics_service',
    failureThreshold: 5,
    resetTimeout: const Duration(seconds: 30),
  );

  static final CircuitBreaker externalSearch = CircuitBreaker(
    name: 'external_search',
    failureThreshold: 4,
    resetTimeout: const Duration(seconds: 15),
  );
}

