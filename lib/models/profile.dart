/// Strongly-typed User Profile model mapping to public.profiles table.
class Profile {
  final String id;
  final String fullName;
  final String email;
  final String avatarUrl;
  final String phone;
  final String role; // 'customer' or 'admin'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarUrl = '',
    this.phone = '',
    this.role = 'customer',
    this.createdAt,
    this.updatedAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isCustomer => role == 'customer';

  factory Profile.fromJson(Map<String, dynamic> map) {
    return Profile(
      id: (map['id'] ?? '') as String,
      fullName: (map['full_name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      avatarUrl: (map['avatar_url'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      role: (map['role'] ?? 'customer') as String,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'avatar_url': avatarUrl,
        'phone': phone,
        'role': role,
      };

  Profile copyWith({
    String? fullName,
    String? email,
    String? avatarUrl,
    String? phone,
    String? role,
  }) {
    return Profile(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
