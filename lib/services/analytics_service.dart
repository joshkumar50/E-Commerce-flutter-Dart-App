import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/analytics_event.dart';
import '../utils/constants.dart';
import '../utils/observability.dart';

/// Production Analytics Service
/// Non-blocking, fault-isolated telemetry emitter.
/// GUARANTEE: An analytics failure will NEVER disrupt browsing, cart operations, or checkout.
class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();
  AnalyticsService._();

  static const _uuid = Uuid();
  final String _sessionId = _uuid.v4().substring(0, 8);
  String? _anonymousId;
  final List<AnalyticsEvent> _buffer = [];
  Timer? _flushTimer;
  bool _isFlushing = false;

  // In-memory analytics store for Demo Mode / fallback
  final List<AnalyticsEvent> _demoEvents = [];

  String get sessionId => _sessionId;
  String get anonymousId => _anonymousId ??= _uuid.v4();

  String get currentPlatform {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isWindows) return 'windows';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return 'unknown';
  }

  /// Initialize periodic background flush (every 30 seconds)
  void init() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      flush();
    });
  }

  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  /// Emit an analytics event asynchronously without blocking the caller.
  /// Any exception is caught and suppressed to guarantee shopping flow safety.
  void track({
    required String eventType,
    String? entityType,
    String? entityId,
    Map<String, dynamic> properties = const {},
  }) {
    // Run completely detached from current execution frame
    Future.microtask(() {
      try {
        final userId = !isDemoMode
            ? Supabase.instance.client.auth.currentUser?.id
            : null;

        final event = AnalyticsEvent(
          userId: userId,
          anonymousId: anonymousId,
          sessionId: _sessionId,
          eventType: eventType,
          entityType: entityType,
          entityId: entityId,
          properties: properties,
          appVersion: '1.0.0',
          platform: currentPlatform,
          createdAt: DateTime.now(),
        );

        _buffer.add(event);

        if (isDemoMode) {
          _demoEvents.add(event);
          if (_demoEvents.length > 500) _demoEvents.removeAt(0);
        }

        // Flush immediately if buffer exceeds threshold (20 events)
        if (_buffer.length >= 20) {
          flush();
        }
      } catch (err) {
        // Suppress telemetry errors completely - non-negotiable safety rule
        AppObservability.warn('Non-fatal analytics tracking failure: $err');
      }
    });
  }

  /// Explicitly flush buffered events to the backend
  Future<void> flush() async {
    if (_isFlushing || _buffer.isEmpty) return;
    _isFlushing = true;

    final batch = List<AnalyticsEvent>.from(_buffer);
    _buffer.clear();

    if (isDemoMode) {
      _isFlushing = false;
      return;
    }

    try {
      final rows = batch.map((e) => e.toJson()).toList();
      await Supabase.instance.client.from(tableAnalyticsEvents).insert(rows);
    } catch (err) {
      AppObservability.warn('Analytics batch insert suppressed: $err');
      // Re-insert failed batch into front of buffer (up to 100 items max)
      if (_buffer.length < 100) {
        _buffer.insertAll(0, batch.take(50));
      }
    } finally {
      _isFlushing = false;
    }
  }

  // Convenience Telemetry Helpers for Business Funnel

  void trackAppOpened() {
    track(eventType: 'app_opened');
  }

  void trackProductViewed({
    required int productId,
    required String productName,
    required double price,
    String? categoryId,
  }) {
    track(
      eventType: 'product_viewed',
      entityType: 'product',
      entityId: productId.toString(),
      properties: {
        'name': productName,
        'price': price,
        if (categoryId != null) 'category_id': categoryId,
      },
    );
  }

  void trackCartItemAdded({
    required int productId,
    required String productName,
    required int quantity,
    required double price,
  }) {
    track(
      eventType: 'cart_item_added',
      entityType: 'product',
      entityId: productId.toString(),
      properties: {
        'name': productName,
        'quantity': quantity,
        'price': price,
        'total': price * quantity,
      },
    );
  }

  void trackCartItemRemoved({
    required int productId,
  }) {
    track(
      eventType: 'cart_item_removed',
      entityType: 'product',
      entityId: productId.toString(),
    );
  }

  void trackCheckoutStarted({
    required double totalAmount,
    required int itemCount,
  }) {
    track(
      eventType: 'checkout_started',
      properties: {
        'total_amount': totalAmount,
        'item_count': itemCount,
      },
    );
  }

  void trackPaymentStarted({
    required String orderId,
    required double amount,
    required String method,
  }) {
    track(
      eventType: 'payment_started',
      entityType: 'order',
      entityId: orderId,
      properties: {
        'amount': amount,
        'method': method,
      },
    );
  }

  void trackOrderCreated({
    required String orderId,
    required double totalAmount,
    required int itemCount,
  }) {
    track(
      eventType: 'order_created',
      entityType: 'order',
      entityId: orderId,
      properties: {
        'total_amount': totalAmount,
        'item_count': itemCount,
      },
    );
  }

  void trackSearchPerformed({
    required String query,
    required int resultCount,
  }) {
    track(
      eventType: 'search_performed',
      properties: {
        'query': query,
        'result_count': resultCount,
        'zero_results': resultCount == 0,
      },
    );
  }

  /// Fetch Business Funnel metrics via RPC
  Future<Map<String, dynamic>> fetchBusinessFunnel({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (isDemoMode) {
      // Return simulated funnel metrics based on current session
      final appOpens = _demoEvents.where((e) => e.eventType == 'app_opened').length + 150;
      final productViews = _demoEvents.where((e) => e.eventType == 'product_viewed').length + 120;
      final cartAdds = _demoEvents.where((e) => e.eventType == 'cart_item_added').length + 65;
      final checkoutStarts = _demoEvents.where((e) => e.eventType == 'checkout_started').length + 42;
      final paymentStarts = _demoEvents.where((e) => e.eventType == 'payment_started').length + 38;
      final ordersCompleted = _demoEvents.where((e) => e.eventType == 'order_created').length + 35;

      return {
        'start_date': (startDate ?? DateTime.now().subtract(const Duration(days: 30))).toIso8601String(),
        'end_date': (endDate ?? DateTime.now()).toIso8601String(),
        'overall_conversion_percent': ((ordersCompleted / appOpens) * 100).toStringAsFixed(1),
        'stages': {
          'app_opened': appOpens,
          'product_viewed': productViews,
          'cart_item_added': cartAdds,
          'checkout_started': checkoutStarts,
          'payment_started': paymentStarts,
          'order_completed': ordersCompleted,
        },
        'dropoffs': {
          'view_to_cart_pct': (((productViews - cartAdds) / productViews) * 100).toStringAsFixed(1),
          'cart_to_checkout_pct': (((cartAdds - checkoutStarts) / cartAdds) * 100).toStringAsFixed(1),
          'checkout_to_payment_pct': (((checkoutStarts - paymentStarts) / checkoutStarts) * 100).toStringAsFixed(1),
          'payment_to_order_pct': (((paymentStarts - ordersCompleted) / paymentStarts) * 100).toStringAsFixed(1),
        }
      };
    }

    try {
      final response = await Supabase.instance.client.rpc(
        'rpc_get_business_funnel',
        params: {
          if (startDate != null) 'p_start_date': startDate.toIso8601String(),
          if (endDate != null) 'p_end_date': endDate.toIso8601String(),
        },
      );
      if (response is Map<String, dynamic>) {
        return response;
      }
      return {};
    } catch (e) {
      AppObservability.error('Failed to fetch business funnel metrics', error: e);
      return {};
    }
  }

  /// Run bounded telemetry retention cleanup
  Future<int> purgeExpiredTelemetry({int daysRetention = 90}) async {
    if (isDemoMode) {
      final initialCount = _demoEvents.length;
      final cutoff = DateTime.now().subtract(Duration(days: daysRetention));
      _demoEvents.removeWhere((e) => e.createdAt.isBefore(cutoff));
      return initialCount - _demoEvents.length;
    }

    try {
      final response = await Supabase.instance.client.rpc(
        'rpc_cleanup_expired_telemetry',
        params: {
          'p_days_retention': daysRetention,
          'p_batch_limit': 5000,
        },
      );
      return response is int ? response : (int.tryParse(response.toString()) ?? 0);
    } catch (e) {
      AppObservability.error('Failed to run telemetry retention cleanup', error: e);
      return 0;
    }
  }
}
