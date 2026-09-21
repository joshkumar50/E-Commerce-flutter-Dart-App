/// Strongly-typed Grocery Product model mapping to public.products table.
/// Includes backward-compatible getters and constructor arguments for legacy UI screens.
class Product {
  final int id;
  final String? categoryId;
  final String name;
  final String description;
  final double price;
  final double? salePrice;
  final int stockQuantity;
  final String unit;
  final String imageUrl;
  final bool isActive;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Legacy compatibility fields
  final String? legacyPid;
  final String? legacyOwner;
  final String? legacyCity;

  const Product({
    required this.id,
    this.categoryId,
    String? name,
    String? title,
    this.description = '',
    required this.price,
    this.salePrice,
    this.stockQuantity = 0,
    this.unit = 'item',
    String? imageUrl,
    String? image,
    this.isActive = true,
    this.version = 1,
    this.createdAt,
    this.updatedAt,
    String? pid,
    String? owner,
    String? city,
  })  : name = name ?? title ?? '',
        imageUrl = imageUrl ?? image ?? '',
        legacyPid = pid,
        legacyOwner = owner,
        legacyCity = city;

  // ─── Backward-compatible Getters ──────────────────────────────────────────
  String get title => name;
  String get image => imageUrl;
  String get pid => legacyPid ?? id.toString();
  String get owner => legacyOwner ?? 'store';
  String get city => legacyCity ?? 'Main Branch';

  /// Effective display price (returns salePrice if present and valid, otherwise regular price)
  double get effectivePrice => (salePrice != null && salePrice! > 0) ? salePrice! : price;

  /// True if product is currently on discount
  bool get hasDiscount => salePrice != null && salePrice! > 0 && salePrice! < price;

  /// In stock check
  bool get inStock => stockQuantity > 0;

  factory Product.fromJson(Map<String, dynamic> map) {
    return Product(
      id: (map['id'] as num?)?.toInt() ?? 0,
      categoryId: (map['category_id'] ?? map['categoryId']) as String?,
      name: (map['name'] ?? map['title'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      salePrice: (map['sale_price'] as num?)?.toDouble(),
      stockQuantity: (map['stock_quantity'] as num?)?.toInt() ?? 100,
      unit: (map['unit'] ?? 'item') as String,
      imageUrl: (map['image_url'] ?? map['image'] ?? '') as String,
      isActive: (map['is_active'] as bool?) ?? true,
      version: (map['version'] as num?)?.toInt() ?? 1,
      pid: map['Pid'] as String?,
      owner: map['owner'] as String?,
      city: map['city'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'price': price,
        'sale_price': salePrice,
        'stock_quantity': stockQuantity,
        'unit': unit,
        'image_url': imageUrl,
        'is_active': isActive,
        'version': version,
        if (categoryId != null) 'category_id': categoryId,
      };

  /// Legacy insertion map for backward compatibility
  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'title': name,
        'description': description,
        'price': price,
        'sale_price': salePrice,
        'stock_quantity': stockQuantity,
        'unit': unit,
        'image_url': imageUrl,
        'image': imageUrl,
        'is_active': isActive,
        'version': version,
        'owner': owner,
        'city': city,
        'Pid': pid,
        if (categoryId != null) 'category_id': categoryId,
      };

  Product copyWith({
    String? name,
    String? categoryId,
    String? description,
    double? price,
    double? salePrice,
    int? stockQuantity,
    String? unit,
    String? imageUrl,
    bool? isActive,
    int? version,
  }) {
    return Product(
      id: id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      salePrice: salePrice ?? this.salePrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      version: version ?? this.version,
      owner: legacyOwner,
      city: legacyCity,
      pid: legacyPid,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Thrown when an Optimistic Concurrency Control (OCC) version mismatch occurs
/// during concurrent product updates.
class StaleVersionException implements Exception {
  final String message;
  final int currentVersion;
  final int expectedVersion;

  const StaleVersionException({
    required this.message,
    required this.currentVersion,
    required this.expectedVersion,
  });

  @override
  String toString() =>
      'StaleVersionException: $message (Current: $currentVersion, Expected: $expectedVersion)';
}

