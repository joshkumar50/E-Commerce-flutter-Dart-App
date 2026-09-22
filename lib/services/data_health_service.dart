import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/constants.dart';
import '../utils/observability.dart';
import 'checkout_service.dart';

/// Abuse / Fraud Risk Signal Model
class AbuseRiskSignal {
  final String signal;
  final String reason;
  final String severity; // info, warning, high, critical
  final Map<String, dynamic> evidence;
  final String actionRecommendation;
  final DateTime detectedAt;

  AbuseRiskSignal({
    required this.signal,
    required this.reason,
    required this.severity,
    required this.evidence,
    required this.actionRecommendation,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'signal': signal,
    'reason': reason,
    'severity': severity,
    'evidence': evidence,
    'action_recommendation': actionRecommendation,
    'detected_at': detectedAt.toIso8601String(),
  };
}

/// Data Quality & Health Check Service
/// Monitors transactional data integrity, orphaned records, inventory discrepancies, and abuse signals.
class DataHealthService {
  static final DataHealthService instance = DataHealthService._();
  DataHealthService._();

  /// Run automated database data health check
  Future<Map<String, dynamic>> runHealthCheck() async {
    if (isDemoMode) {
      return {
        'status': 'HEALTHY',
        'checked_at': DateTime.now().toIso8601String(),
        'action_required_count': 0,
        'checks': {
          'negative_stock': 0,
          'invalid_prices': 0,
          'stuck_reservations': 0,
          'orphaned_order_items': 0,
          'orphaned_payments': 0,
          'unresolved_payments': 0,
          'missing_categories': 0,
          'missing_images': 0,
        }
      };
    }

    try {
      final response = await Supabase.instance.client.rpc('rpc_run_data_health_check');
      if (response is Map<String, dynamic>) {
        return response;
      }
      return {'status': 'UNKNOWN', 'error': 'Malformed response'};
    } catch (e) {
      AppObservability.error('Failed to run data health check: $e');
      return {
        'status': 'ERROR',
        'error': e.toString(),
        'checked_at': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Trigger inventory reservation expiration sweeper
  Future<int> sweepExpiredReservations() async {
    if (isDemoMode) {
      return await checkoutService.sweepExpiredReservations();
    }
    try {
      final response = await Supabase.instance.client.rpc('rpc_expire_reservations');
      return response is int ? response : (int.tryParse(response.toString()) ?? 0);
    } catch (e) {
      AppObservability.error('Failed to sweep expired reservations: $e');
      return 0;
    }
  }

  /// Fetch aggregated high-level business & technical dashboard metrics
  Future<Map<String, dynamic>> fetchAdminDashboardMetrics() async {
    if (isDemoMode) {
      return {
        'timestamp': DateTime.now().toIso8601String(),
        'customers': {
          'total': 18,
          'new_30d': 6,
        },
        'catalog': {
          'total': 10,
          'active': 9,
          'low_stock': 2,
          'out_of_stock': 0,
        },
        'orders': {
          'total': 14,
          'pending': 1,
          'confirmed': 8,
          'delivered': 4,
          'cancelled': 1,
          'total_revenue': 4850.00,
        },
        'payments': {
          'successful': 12,
          'failed': 1,
          'refunded': 1,
          'failure_rate_pct': 7.7,
        }
      };
    }

    try {
      final response = await Supabase.instance.client.rpc('rpc_get_admin_dashboard_metrics');
      if (response is Map<String, dynamic>) {
        return response;
      }
      return {};
    } catch (e) {
      AppObservability.error('Failed to fetch admin dashboard metrics: $e');
      return {};
    }
  }

  /// Rules-based Fraud & Abuse Monitoring Engine
  /// Analyzes transactional patterns and flags risk signals for admin review.
  /// Rule: NEVER automatically ban users purely based on one heuristic.
  List<AbuseRiskSignal> evaluateAbuseSignals({
    required List<Map<String, dynamic>> recentOrders,
    required List<Map<String, dynamic>> recentPayments,
  }) {
    final signals = <AbuseRiskSignal>[];

    // Check 1: Repeated failed payments by same customer
    final failedByCustomer = <String, int>{};
    for (final p in recentPayments) {
      if (p['status'] == 'failed' && p['user_id'] != null) {
        final uid = p['user_id'].toString();
        failedByCustomer[uid] = (failedByCustomer[uid] ?? 0) + 1;
      }
    }

    for (final entry in failedByCustomer.entries) {
      if (entry.value >= 3) {
        signals.add(AbuseRiskSignal(
          signal: 'REPEATED_PAYMENT_FAILURE',
          reason: 'Customer experienced ${entry.value} consecutive payment failures',
          severity: entry.value >= 5 ? 'high' : 'warning',
          evidence: {'customer_id': entry.key, 'failed_attempts': entry.value},
          actionRecommendation: 'Inspect payment gateway error codes. Contact customer to assist with banking issues before restricting checkout.',
        ));
      }
    }

    // Check 2: Abnormal order velocity (> 4 orders within 15 minutes by same customer)
    final ordersByCustomer = <String, List<DateTime>>{};
    for (final o in recentOrders) {
      final uid = o['user_id']?.toString() ?? 'anonymous';
      final created = DateTime.tryParse(o['created_at']?.toString() ?? '') ?? DateTime.now();
      ordersByCustomer.putIfAbsent(uid, () => []).add(created);
    }

    for (final entry in ordersByCustomer.entries) {
      final times = entry.value..sort();
      if (times.length >= 4) {
        final diff = times.last.difference(times.first);
        if (diff.inMinutes <= 15) {
          signals.add(AbuseRiskSignal(
            signal: 'ABNORMAL_ORDER_VELOCITY',
            reason: 'Customer placed ${times.length} orders within ${diff.inMinutes} minutes',
            severity: 'warning',
            evidence: {'customer_id': entry.key, 'order_count': times.length, 'time_window_minutes': diff.inMinutes},
            actionRecommendation: 'Verify delivery address and payment verification. Check for bot or automated script behavior.',
          ));
        }
      }
    }

    // Check 3: Suspicious refund frequency
    final refundedOrders = recentOrders.where((o) => o['status'] == 'refunded').toList();
    if (recentOrders.isNotEmpty && (refundedOrders.length / recentOrders.length) > 0.3) {
      signals.add(AbuseRiskSignal(
        signal: 'HIGH_REFUND_RATIO',
        reason: 'Refund ratio (${(refundedOrders.length / recentOrders.length * 100).toStringAsFixed(1)}%) exceeds operational threshold (30%)',
        severity: 'high',
        evidence: {'total_orders': recentOrders.length, 'refunded_orders': refundedOrders.length},
        actionRecommendation: 'Review product quality, delivery transit damages, or potential refund policy exploitation.',
      ));
    }

    return signals;
  }
}
