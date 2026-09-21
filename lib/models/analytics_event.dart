class AnalyticsEvent {
  final int? id;
  final String? userId;
  final String? anonymousId;
  final String? sessionId;
  final String eventType;
  final String? entityType;
  final String? entityId;
  final Map<String, dynamic> properties;
  final String? appVersion;
  final String? platform;
  final DateTime createdAt;

  AnalyticsEvent({
    this.id,
    this.userId,
    this.anonymousId,
    this.sessionId,
    required this.eventType,
    this.entityType,
    this.entityId,
    this.properties = const {},
    this.appVersion,
    this.platform,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (anonymousId != null) 'anonymous_id': anonymousId,
      if (sessionId != null) 'session_id': sessionId,
      'event_type': eventType,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      'properties': properties,
      if (appVersion != null) 'app_version': appVersion,
      if (platform != null) 'platform': platform,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      userId: json['user_id']?.toString(),
      anonymousId: json['anonymous_id']?.toString(),
      sessionId: json['session_id']?.toString(),
      eventType: json['event_type']?.toString() ?? '',
      entityType: json['entity_type']?.toString(),
      entityId: json['entity_id']?.toString(),
      properties: json['properties'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['properties'])
          : {},
      appVersion: json['app_version']?.toString(),
      platform: json['platform']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
