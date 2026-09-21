class AdminAuditLog {
  final int? id;
  final String? actorId;
  final String? actorEmail;
  final String action;
  final String entityType;
  final String entityId;
  final Map<String, dynamic>? previousState;
  final Map<String, dynamic>? newState;
  final String? reason;
  final String severity; // info, warning, critical
  final String? requestId;
  final String? ipAddress;
  final DateTime createdAt;

  AdminAuditLog({
    this.id,
    this.actorId,
    this.actorEmail,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.previousState,
    this.newState,
    this.reason,
    this.severity = 'info',
    this.requestId,
    this.ipAddress,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (actorId != null) 'actor_id': actorId,
      if (actorEmail != null) 'actor_email': actorEmail,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      if (previousState != null) 'previous_state': previousState,
      if (newState != null) 'new_state': newState,
      if (reason != null) 'reason': reason,
      'severity': severity,
      if (requestId != null) 'request_id': requestId,
      if (ipAddress != null) 'ip_address': ipAddress,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AdminAuditLog.fromJson(Map<String, dynamic> json) {
    return AdminAuditLog(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      actorId: json['actor_id']?.toString(),
      actorEmail: json['actor_email']?.toString(),
      action: json['action']?.toString() ?? '',
      entityType: json['entity_type']?.toString() ?? '',
      entityId: json['entity_id']?.toString() ?? '',
      previousState: json['previous_state'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['previous_state'])
          : null,
      newState: json['new_state'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['new_state'])
          : null,
      reason: json['reason']?.toString(),
      severity: json['severity']?.toString() ?? 'info',
      requestId: json['request_id']?.toString(),
      ipAddress: json['ip_address']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
