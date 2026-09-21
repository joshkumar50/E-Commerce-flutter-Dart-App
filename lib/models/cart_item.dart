import 'package:opem/models/product.dart';

/// Strongly-typed Shopping Cart Item model mapping to public.cart_items.
class CartItem {
  final String id;
  final String userId;
  final int productId;
  final int quantity;
  final Product? product;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CartItem({
    required this.id,
    required this.userId,
    required this.productId,
    required this.quantity,
    this.product,
    this.createdAt,
    this.updatedAt,
  });

  /// Subtotal for this cart item
  double get subtotal => (product?.effectivePrice ?? 0.0) * quantity;

  factory CartItem.fromJson(Map<String, dynamic> map) {
    return CartItem(
      id: (map['id'] ?? '') as String,
      userId: (map['user_id'] ?? '') as String,
      productId: (map['product_id'] as num).toInt(),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      product: map['products'] != null
          ? Product.fromJson(map['products'] as Map<String, dynamic>)
          : (map['product'] != null
              ? Product.fromJson(map['product'] as Map<String, dynamic>)
              : null),
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
        'product_id': productId,
        'quantity': quantity,
      };

  CartItem copyWith({
    int? quantity,
    Product? product,
  }) {
    return CartItem(
      id: id,
      userId: userId,
      productId: productId,
      quantity: quantity ?? this.quantity,
      product: product ?? this.product,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
