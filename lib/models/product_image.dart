/// Secondary Product Image model mapping to public.product_images.
class ProductImage {
  final String id;
  final int productId;
  final String imageUrl;
  final int sortOrder;
  final DateTime? createdAt;

  const ProductImage({
    required this.id,
    required this.productId,
    required this.imageUrl,
    this.sortOrder = 0,
    this.createdAt,
  });

  factory ProductImage.fromJson(Map<String, dynamic> map) {
    return ProductImage(
      id: (map['id'] ?? '') as String,
      productId: (map['product_id'] as num).toInt(),
      imageUrl: (map['image_url'] ?? '') as String,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'image_url': imageUrl,
        'sort_order': sortOrder,
      };
}
