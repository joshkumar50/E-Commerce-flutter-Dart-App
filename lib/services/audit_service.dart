import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_audit_log.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../utils/observability.dart';

/// Immutable Admin Audit Service
/// Records and provides auditable logs for all sensitive administrative actions.
class AuditService {
  static final AuditService instance = AuditService._();
  AuditService._();

  // In-memory audit buffer for Demo Mode
  final List<AdminAuditLog> _demoLogs = [];

  /// Log an administrative mutation
  Future<void> logAction({
    required String action,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? previousState,
    Map<String, dynamic>? newState,
    String? reason,
    String severity = 'info',
    String? requestId,
  }) async {
    final reqId = requestId ?? AppObservability.newRequestId();

    final log = AdminAuditLog(
      actorId: authService.currentUserId ?? 'system',
      actorEmail: authService.currentUserEmail ?? 'system@bbuys.com',
      action: action,
      entityType: entityType,
      entityId: entityId,
      previousState: previousState,
      newState: newState,
      reason: reason,
      severity: severity,
      requestId: reqId,
      createdAt: DateTime.now(),
    );

    if (isDemoMode) {
      _demoLogs.insert(0, log);
      if (_demoLogs.length > 500) _demoLogs.removeLast();
      return;
    }

    try {
      await Supabase.instance.client.rpc(
        'rpc_log_admin_audit',
        params: {
          'p_action': action,
          'p_entity_type': entityType,
          'p_entity_id': entityId,
          'p_previous_state': previousState,
          'p_new_state': newState,
          'p_reason': reason,
          'p_severity': severity,
          'p_request_id': reqId,
        },
      );
    } catch (e) {
      // Fallback: direct insert if RPC not yet deployed
      try {
        await Supabase.instance.client.from(tableAdminAuditLogs).insert(log.toJson());
      } catch (err) {
        AppObservability.error('Failed to persist admin audit log: $err', error: err);
      }
    }
  }

  /// Retrieve audit logs with optional filters
  Future<List<AdminAuditLog>> fetchAuditLogs({
    String? entityType,
    String? entityId,
    String? severity,
    int limit = 50,
  }) async {
    if (isDemoMode) {
      var list = List<AdminAuditLog>.from(_demoLogs);
      if (entityType != null) {
        list = list.where((l) => l.entityType == entityType).toList();
      }
      if (entityId != null) {
        list = list.where((l) => l.entityId == entityId).toList();
      }
      if (severity != null) {
        list = list.where((l) => l.severity == severity).toList();
      }
      return list.take(limit).toList();
    }

    try {
      dynamic query = Supabase.instance.client.from(tableAdminAuditLogs).select();

      if (entityType != null) query = query.eq('entity_type', entityType);
      if (entityId != null) query = query.eq('entity_id', entityId);
      if (severity != null) query = query.eq('severity', severity);

      final rows = await query.order('created_at', ascending: false).limit(limit);
      return (rows as List).map((r) => AdminAuditLog.fromJson(r)).toList();
    } catch (e) {
      AppObservability.error('Failed to fetch admin audit logs: $e');
      return [];
    }
  }

  // Helper audit methods for common operations

  Future<void> logPriceChange({
    required int productId,
    required String productName,
    required double oldPrice,
    required double newPrice,
    String? reason,
  }) async {
    await logAction(
      action: 'update_price',
      entityType: 'product',
      entityId: productId.toString(),
      previousState: {'name': productName, 'price': oldPrice},
      newState: {'name': productName, 'price': newPrice},
      reason: reason ?? 'Price adjusted in catalog',
      severity: (newPrice < oldPrice * 0.5) ? 'warning' : 'info',
    );
  }

  Future<void> logStockAdjustment({
    required int productId,
    required String productName,
    required int oldStock,
    required int newStock,
    String? reason,
  }) async {
    await logAction(
      action: 'adjust_stock',
      entityType: 'inventory',
      entityId: productId.toString(),
      previousState: {'name': productName, 'stock_quantity': oldStock},
      newState: {'name': productName, 'stock_quantity': newStock},
      reason: reason ?? 'Manual stock adjustment by admin',
      severity: newStock == 0 ? 'warning' : 'info',
    );
  }

  Future<void> logOrderStatusChange({
    required String orderId,
    required String oldStatus,
    required String newStatus,
    String? reason,
  }) async {
    await logAction(
      action: 'update_order_status',
      entityType: 'order',
      entityId: orderId,
      previousState: {'status': oldStatus},
      newState: {'status': newStatus},
      reason: reason,
      severity: newStatus == 'cancelled' ? 'warning' : 'info',
    );
  }
}
