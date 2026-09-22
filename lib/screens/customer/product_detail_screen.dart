import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:opem/core/design_tokens.dart';
import 'package:opem/models/product.dart';
import 'package:opem/provider/cart_provider.dart';
import 'package:opem/services/analytics_service.dart';
import 'package:opem/services/auth_service.dart';
import 'package:opem/services/wishlist_service.dart';
import 'package:opem/widgets/ui/pressable_scale.dart';
import 'package:opem/widgets/ui/shimmer_loading.dart';
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

    HapticFeedback.lightImpact();
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          PressableScale(
            onTap: _isLoadingFavorite ? null : _toggleFavorite,
            child: Container(
              margin: const EdgeInsets.only(right: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.xs + 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Icon(
                _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isFavorite ? AppColors.saleRed : AppColors.textPrimary,
                size: 22,
              ),
            ),
          ),
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
                  height: 290,
                  width: double.infinity,
                  color: AppColors.surfaceMuted,
                  child: product.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const ShimmerLoading(
                            child: ColoredBox(color: Colors.white),
                          ),
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.local_grocery_store_outlined,
                              size: 64,
                              color: AppColors.textMuted,
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.local_grocery_store_outlined,
                            size: 64,
                            color: AppColors.textMuted,
                          ),
                        ),
                ),
                if (discountPct > 0)
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.saleRed,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        boxShadow: AppShadows.subtle,
                      ),
                      child: Text(
                        '$discountPct% OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // ─── Product Overview ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Unit & Delivery Time Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs + 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          product.unit,
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs + 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, size: 14, color: AppColors.accent),
                            SizedBox(width: AppSpacing.xxs),
                            Text(
                              '10-15 mins',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Name
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Price & Stock Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        AppCurrency.format(product.effectivePrice),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (product.hasDiscount) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          AppCurrency.format(product.price),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: product.inStock ? AppColors.primarySoft : AppColors.saleRedSoft,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          product.inStock ? 'In Stock (${product.stockQuantity})' : 'Out of Stock',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: product.inStock ? AppColors.primaryDark : AppColors.saleRed,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 40, color: AppColors.border),

                  // Description
                  const Text(
                    'Product Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
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

                  const SizedBox(height: AppSpacing.xl),

                  // Quality & Freshness Guarantee Card
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: const BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '100% Quality & Freshness Guarantee',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: AppSpacing.xxs),
                              Text(
                                'Hand-inspected before packaging. Direct from local stores to your door.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100), // bottom bar spacing
                ],
              ),
            ),
          ],
        ),
      ),

      // ─── Sticky Bottom Action Bar ──────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
          boxShadow: AppShadows.floating,
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Quantity Stepper
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 18),
                      onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                    ),
                    Text(
                      '$_quantity',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      onPressed: () => setState(() => _quantity++),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Add to Cart Button
              Expanded(
                child: PressableScale(
                  onTap: product.inStock
                      ? () async {
                          HapticFeedback.mediumImpact();
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: product.inStock ? AppColors.primary : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: product.inStock ? AppShadows.subtle : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          color: product.inStock ? Colors.white : AppColors.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          product.inStock
                              ? 'Add • ${AppCurrency.format(product.effectivePrice * _quantity)}'
                              : 'Out of Stock',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: product.inStock ? Colors.white : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
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
