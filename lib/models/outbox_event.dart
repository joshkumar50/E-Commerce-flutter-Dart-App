import 'package:uuid/uuid.dart';

enum OutboxStatus { pending, processing, published, failed, deadLetter }

/// Transactional Outbox Event Model
/// Guarantees that asynchronous business events are atomically persisted
/// within the same transaction as primary state changes.
class OutboxEvent {
  final int? id;
  final String eventId;
  final String eventType;
  final String aggregateType;
  final String aggregateId;
  final Map<String, dynamic> payload;
  final int schemaVersion;
  final OutboxStatus status;
  final int retryCount;
  final int maxRetries;
  final String? errorMessage;
  final String? correlationId;
  final DateTime createdAt;
  final DateTime? processedAt;

  OutboxEvent({
    this.id,
    String? eventId,
    required this.eventType,
    required this.aggregateType,
    required this.aggregateId,
    this.payload = const {},
    this.schemaVersion = 1,
    this.status = OutboxStatus.pending,
    this.retryCount = 0,
    this.maxRetries = 5,
    this.errorMessage,
    this.correlationId,
    DateTime? createdAt,
    this.processedAt,
  })  : eventId = eventId ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'event_id': eventId,
      'event_type': eventType,
      'aggregate_type': aggregateType,
      'aggregate_id': aggregateId,
      'payload': payload,
      'schema_version': schemaVersion,
      'status': status.name,
      'retry_count': retryCount,
      'max_retries': maxRetries,
      if (errorMessage != null) 'error_message': errorMessage,
      if (correlationId != null) 'correlation_id': correlationId,
      'created_at': createdAt.toIso8601String(),
      if (processedAt != null) 'processed_at': processedAt!.toIso8601String(),
    };
  }

  factory OutboxEvent.fromJson(Map<String, dynamic> json) {
    OutboxStatus parseStatus(String? val) {
      switch (val?.toLowerCase()) {
        case 'processing':
          return OutboxStatus.processing;
        case 'published':
          return OutboxStatus.published;
        case 'failed':
          return OutboxStatus.failed;
        case 'dead_letter':
        case 'deadletter':
          return OutboxStatus.deadLetter;
        case 'pending':
        default:
          return OutboxStatus.pending;
      }
    }

    return OutboxEvent(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      eventId: json['event_id']?.toString() ?? const Uuid().v4(),
      eventType: json['event_type']?.toString() ?? '',
      aggregateType: json['aggregate_type']?.toString() ?? '',
      aggregateId: json['aggregate_id']?.toString() ?? '',
      payload: json['payload'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['payload'])
          : {},
      schemaVersion: json['schema_version'] is int ? json['schema_version'] : 1,
      status: parseStatus(json['status']?.toString()),
      retryCount: json['retry_count'] is int ? json['retry_count'] : 0,
      maxRetries: json['max_retries'] is int ? json['max_retries'] : 5,
      errorMessage: json['error_message']?.toString(),
      correlationId: json['correlation_id']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      processedAt: json['processed_at'] != null
          ? DateTime.tryParse(json['processed_at'].toString())
          : null,
    );
  }
}
