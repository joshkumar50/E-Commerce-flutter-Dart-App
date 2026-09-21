/// Fulfillment Location model mapping to public.fulfillment_locations table.
/// Supports multi-warehouse and dark store inventory architectures.
class FulfillmentLocation {
  final String id;
  final String name;
  final String type; // 'dark_store', 'central_warehouse', 'retail_hub'
  final Map<String, dynamic> address;
  final List<String> servicedPincodes;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FulfillmentLocation({
    required this.id,
    required this.name,
    this.type = 'dark_store',
    this.address = const {},
    this.servicedPincodes = const [],
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory FulfillmentLocation.fromJson(Map<String, dynamic> json) {
    return FulfillmentLocation(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? 'dark_store').toString(),
      address: json['address'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['address'] as Map)
          : const {},
      servicedPincodes: json['serviced_pincodes'] is List
          ? (json['serviced_pincodes'] as List).map((e) => e.toString()).toList()
          : const [],
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'address': address,
        'serviced_pincodes': servicedPincodes,
        'is_active': isActive,
      };

  FulfillmentLocation copyWith({
    String? id,
    String? name,
    String? type,
    Map<String, dynamic>? address,
    List<String>? servicedPincodes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FulfillmentLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      servicedPincodes: servicedPincodes ?? this.servicedPincodes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Inventory record per fulfillment location mapping to public.inventory_by_location.
class LocationInventory {
  final int id;
  final int productId;
  final String locationId;
  final int availableQuantity;
  final int reservedQuantity;
  final int reorderThreshold;
  final DateTime? updatedAt;

  const LocationInventory({
    required this.id,
    required this.productId,
    required this.locationId,
    required this.availableQuantity,
    this.reservedQuantity = 0,
    this.reorderThreshold = 10,
    this.updatedAt,
  });

  int get totalStock => availableQuantity + reservedQuantity;
  bool get isLowStock => availableQuantity <= reorderThreshold;

  factory LocationInventory.fromJson(Map<String, dynamic> json) {
    return LocationInventory(
      id: (json['id'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      locationId: (json['location_id'] ?? '').toString(),
      availableQuantity: (json['available_quantity'] as num?)?.toInt() ?? 0,
      reservedQuantity: (json['reserved_quantity'] as num?)?.toInt() ?? 0,
      reorderThreshold: (json['reorder_threshold'] as num?)?.toInt() ?? 10,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'location_id': locationId,
        'available_quantity': availableQuantity,
        'reserved_quantity': reservedQuantity,
        'reorder_threshold': reorderThreshold,
      };
}
