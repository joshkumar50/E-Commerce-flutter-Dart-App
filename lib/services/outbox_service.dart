import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/outbox_event.dart';
import '../utils/constants.dart';
import '../utils/observability.dart';

/// Transactional Outbox Service
/// Decouples business transaction commits from event delivery to external systems,
/// preventing dual-write anomalies and race conditions.
class OutboxService {
  static final OutboxService instance = OutboxService._();
  OutboxService._();

  // In-memory demo event list
  final List<OutboxEvent> _demoEvents = [
    OutboxEvent(
      id: 1,
      eventType: 'order.created',
      aggregateType: 'order',
      aggregateId: 'ord_demo_101',
      payload: {'order_id': 'ord_demo_101', 'total_amount': 24.99, 'items_count': 3},
      status: OutboxStatus.published,
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      processedAt: DateTime.now().subtract(const Duration(minutes: 14)),
    ),
    OutboxEvent(
      id: 2,
      eventType: 'inventory.reserved',
      aggregateType: 'inventory',
      aggregateId: 'prod_1',
      payload: {'product_id': 1, 'quantity': 2, 'order_id': 'ord_demo_101'},
      status: OutboxStatus.published,
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      processedAt: DateTime.now().subtract(const Duration(minutes: 14)),
    ),
    OutboxEvent(
      id: 3,
      eventType: 'payment.verified',
      aggregateType: 'payment',
      aggregateId: 'pay_demo_789',
      payload: {'payment_id': 'pay_demo_789', 'method': 'upi', 'amount': 24.99},
      status: OutboxStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
  ];

  final _streamController = StreamController<List<OutboxEvent>>.broadcast();
  Stream<List<OutboxEvent>> get outboxStream => _streamController.stream;

  /// Publish a domain event atomically to the outbox
  Future<String> publishEvent({
    required String eventType,
    required String aggregateType,
    required String aggregateId,
    Map<String, dynamic> payload = const {},
    String? correlationId,
    int schemaVersion = 1,
  }) async {
    final traceId = correlationId ?? const Uuid().v4();

    if (isDemoMode) {
      final event = OutboxEvent(
        id: _demoEvents.length + 1,
        eventType: eventType,
        aggregateType: aggregateType,
        aggregateId: aggregateId,
        payload: payload,
        correlationId: traceId,
        schemaVersion: schemaVersion,
        status: OutboxStatus.pending,
        createdAt: DateTime.now(),
      );
      _demoEvents.insert(0, event);
      _streamController.add(List.unmodifiable(_demoEvents));
      return event.eventId;
    }

    return AppObservability.measure(
      operation: 'publish_outbox_event',
      metadata: {
        'event_type': eventType,
        'aggregate_type': aggregateType,
        'aggregate_id': aggregateId,
        'correlation_id': traceId,
      },
      action: (reqId) async {
        final result = await Supabase.instance.client.rpc(
          'rpc_publish_outbox_event',
          params: {
            'p_event_type': eventType,
            'p_aggregate_type': aggregateType,
            'p_aggregate_id': aggregateId,
            'p_payload': payload,
            'p_correlation_id': traceId,
            'p_schema_version': schemaVersion,
          },
        );

        return result?.toString() ?? traceId;
      },
    );
  }

  /// Process pending outbox events in a bounded batch using SKIP LOCKED
  Future<Map<String, dynamic>> processBatch({int batchSize = 50}) async {
    if (isDemoMode) {
      int processed = 0;
      for (int i = 0; i < _demoEvents.length; i++) {
        if (_demoEvents[i].status == OutboxStatus.pending && processed < batchSize) {
          _demoEvents[i] = OutboxEvent(
            id: _demoEvents[i].id,
            eventId: _demoEvents[i].eventId,
            eventType: _demoEvents[i].eventType,
            aggregateType: _demoEvents[i].aggregateType,
            aggregateId: _demoEvents[i].aggregateId,
            payload: _demoEvents[i].payload,
            schemaVersion: _demoEvents[i].schemaVersion,
            status: OutboxStatus.published,
            retryCount: _demoEvents[i].retryCount,
            maxRetries: _demoEvents[i].maxRetries,
            correlationId: _demoEvents[i].correlationId,
            createdAt: _demoEvents[i].createdAt,
            processedAt: DateTime.now(),
          );
          processed++;
        }
      }
      _streamController.add(List.unmodifiable(_demoEvents));
      return {
        'success': true,
        'batch_size': batchSize,
        'processed_count': processed,
        'failed_count': 0,
      };
    }

    return AppObservability.measure(
      operation: 'process_outbox_batch',
      metadata: {'batch_size': batchSize},
      action: (reqId) async {
        final res = await Supabase.instance.client.rpc(
          'rpc_process_outbox_batch',
          params: {'p_batch_size': batchSize},
        );

        if (res is Map) {
          return Map<String, dynamic>.from(res);
        }
        return {'success': true, 'processed_count': 0};
      },
    );
  }

  /// Fetch recent events for operational inspection and auditing
  Future<List<OutboxEvent>> fetchRecentEvents({int limit = 50}) async {
    if (isDemoMode) {
      final safeLimit = limit.clamp(1, 100);
      final list = _demoEvents.take(safeLimit).toList();
      return list;
    }

    try {
      final safeLimit = limit.clamp(1, 100);
      final rows = await Supabase.instance.client
          .from(tableEventOutbox)
          .select()
          .order('created_at', ascending: false)
          .limit(safeLimit);

      return (rows as List)
          .map((e) => OutboxEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppObservability.error('Failed to fetch outbox events: $e');
      return [];
    }
  }
}
