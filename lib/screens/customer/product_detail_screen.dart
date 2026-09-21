import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:opem/core/theme.dart';
import 'package:opem/models/product.dart';
import 'package:opem/provider/cart_provider.dart';
import 'package:opem/services/analytics_service.dart';
import 'package:opem/services/auth_service.dart';
import 'package:opem/services/wishlist_service.dart';
import 'package:provider/provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  bool _isFavorite = false;
  bool _isLoadingFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
    // Non-blocking business funnel telemetry
    AnalyticsService.instance.trackProductViewed(
      productId: widget.product.id,
      productName: widget.product.name,
      price: widget.product.effectivePrice,
      categoryId: widget.product.categoryId,
    );
  }

  Future<void> _checkFavorite() async {
    final uid = authService.currentUserId;
    if (uid == null) return;
    final fav = await wishlistService.isFavorite(userId: uid, productId: widget.product.id);
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFavorite() async {
    final uid = authService.currentUserId;
    if (uid == null) {
      EasyLoading.showInfo('Please sign in to save favorites');
      return;
    }

    setState(() => _isLoadingFavorite = true);
    final fav = await wishlistService.toggleWishlist(
      userId: uid,
      productId: widget.product.id,
    );
    if (mounted) {
      setState(() {
        _isFavorite = fav;
        _isLoadingFavorite = false;
      });
      EasyLoading.showToast(fav ? 'Added to favorites' : 'Removed from favorites');
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final cart = context.watch<CartProvider>();

    int discountPct = 0;
    if (product.hasDiscount && product.price > 0) {
      discountPct = (((product.price - product.salePrice!) / product.price) * 100).round();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? AppColors.saleRed : AppColors.textPrimary,
            ),
            onPressed: _isLoadingFavorite ? null : _toggleFavorite,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Hero Product Image ─────────────────────────────────────────
            Stack(
              children: [
                Container(
                  height: 280,
                  width: double.infinity,
                  color: AppColors.surfaceMuted,
                  child: product.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image, size: 64, color: AppColors.textMuted),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.shopping_bag, size: 64, color: AppColors.textMuted),
                        ),
                ),
                if (discountPct > 0)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.saleRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$discountPct% OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // ─── Product Overview ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Unit Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      product.unit,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Name
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Price Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '\$${product.effectivePrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      if (product.hasDiscount) ...[
                        const SizedBox(width: 10),
                        Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Stock Status
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: product.inStock ? AppColors.primarySoft : AppColors.saleRedLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          product.inStock ? 'In Stock (${product.stockQuantity})' : 'Out of Stock',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: product.inStock ? AppColors.primary : AppColors.saleRed,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 36, color: AppColors.border),

                  // Description
                  const Text(
                    'About this item',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description.isNotEmpty
                        ? product.description
                        : 'Freshly harvested grocery produce sourced directly from trusted regional farmers and producers.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Freshness Guarantee Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_outlined, color: AppColors.primary, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '100% Quality & Freshness Guarantee',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Hand-inspected before packaging. Direct from store to your door.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80), // bottom bar spacing
                ],
              ),
            ),
          ],
        ),
      ),

      // ─── Sticky Bottom Action Bar ──────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Quantity Stepper
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                    ),
                    Text(
                      '$_quantity',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () => setState(() => _quantity++),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Add to Cart Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: product.inStock
                      ? () async {
                          await cart.addToCart(product.id, quantity: _quantity);
                          EasyLoading.showSuccess('Added $_quantity to Cart');
                          AnalyticsService.instance.trackCartItemAdded(
                            productId: product.id,
                            productName: product.name,
                            quantity: _quantity,
                            price: product.effectivePrice,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: Text(
                    'Add • \$${(product.effectivePrice * _quantity).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
