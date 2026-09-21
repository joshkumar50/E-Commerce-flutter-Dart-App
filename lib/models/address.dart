/// Strongly-typed Customer Delivery Address model mapping to public.addresses table.
class Address {
  final String id;
  final String userId;
  final String label; // e.g. 'Home', 'Work', 'Other'
  final String fullName;
  final String phone;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Address({
    required this.id,
    required this.userId,
    this.label = 'Home',
    required this.fullName,
    required this.phone,
    required this.addressLine1,
    this.addressLine2 = '',
    required this.city,
    required this.state,
    required this.postalCode,
    this.country = 'India',
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  String get formattedAddress {
    final buffer = StringBuffer(addressLine1);
    if (addressLine2.isNotEmpty) buffer.write(', $addressLine2');
    buffer.write(', $city, $state - $postalCode, $country');
    return buffer.toString();
  }

  factory Address.fromJson(Map<String, dynamic> map) {
    return Address(
      id: (map['id'] ?? '') as String,
      userId: (map['user_id'] ?? '') as String,
      label: (map['label'] ?? 'Home') as String,
      fullName: (map['full_name'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      addressLine1: (map['address_line1'] ?? '') as String,
      addressLine2: (map['address_line2'] ?? '') as String,
      city: (map['city'] ?? '') as String,
      state: (map['state'] ?? '') as String,
      postalCode: (map['postal_code'] ?? '') as String,
      country: (map['country'] ?? 'India') as String,
      isDefault: (map['is_default'] as bool?) ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'label': label,
        'full_name': fullName,
        'phone': phone,
        'address_line1': addressLine1,
        'address_line2': addressLine2,
        'city': city,
        'state': state,
        'postal_code': postalCode,
        'country': country,
        'is_default': isDefault,
      };

  Address copyWith({
    String? label,
    String? fullName,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    bool? isDefault,
  }) {
    return Address(
      id: id,
      userId: userId,
      label: label ?? this.label,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
