class AppConfig {
  final String key;
  final dynamic value;
  final String? description;
  final bool isActive;
  final String? updatedBy;
  final DateTime updatedAt;

  AppConfig({
    required this.key,
    required this.value,
    this.description,
    this.isActive = true,
    this.updatedBy,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
      if (description != null) 'description': description,
      'is_active': isActive,
      if (updatedBy != null) 'updated_by': updatedBy,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      key: json['key']?.toString() ?? '',
      value: json['value'],
      description: json['description']?.toString(),
      isActive: json['is_active'] == true,
      updatedBy: json['updated_by']?.toString(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
