import 'package:opem/models/product.dart';

/// Strongly-typed Wishlist/Favorite item model mapping to public.wishlist_items.
class WishlistItem {
  final String id;
  final String userId;
  final int productId;
  final Product? product;
  final DateTime? createdAt;

  const WishlistItem({
    required this.id,
    required this.userId,
    required this.productId,
    this.product,
    this.createdAt,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> map) {
    return WishlistItem(
      id: (map['id'] ?? '') as String,
      userId: (map['user_id'] ?? '') as String,
      productId: (map['product_id'] as num).toInt(),
      product: map['products'] != null
          ? Product.fromJson(map['products'] as Map<String, dynamic>)
          : (map['product'] != null
              ? Product.fromJson(map['product'] as Map<String, dynamic>)
              : null),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'product_id': productId,
      };
}
