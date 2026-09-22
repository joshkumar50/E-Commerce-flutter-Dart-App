import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:opem/core/design_tokens.dart';
import 'package:opem/core/router.dart';
import 'package:opem/models/product.dart';
import 'package:opem/provider/cart_provider.dart';
import 'package:opem/services/auth_service.dart';
import 'package:opem/services/wishlist_service.dart';
import 'package:opem/widgets/ui/animated_quantity_stepper.dart';
import 'package:opem/widgets/ui/pressable_scale.dart';
import 'package:opem/widgets/ui/shimmer_loading.dart';

/// Modern Grocery Product Card with tactile press feedback, smooth
/// image loading placeholders, out-of-stock badges, and Zepto/Blinkit-style
/// animated quantity steppers.
class ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isFavorite = false;
  bool _isLoadingFavorite = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = wishlistService.isFavoriteSync(widget.product.id);
  }

  Future<void> _toggleFavorite() async {
    final uid = authService.currentUserId;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to save favorites'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _isLoadingFavorite = true;
      _isFavorite = !_isFavorite;
    });
    final isFav = await wishlistService.toggleWishlist(
      userId: uid,
      productId: widget.product.id,
    );
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
        _isLoadingFavorite = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final cartItem = cart.items.cast<dynamic>().firstWhere(
          (item) => item.productId == widget.product.id,
          orElse: () => null,
        );
    final inCartQuantity = cartItem?.quantity ?? 0;

    // Discount percentage
    int discountPct = 0;
    if (widget.product.hasDiscount && widget.product.price > 0) {
      discountPct = (((widget.product.price - widget.product.salePrice!) / widget.product.price) * 100).round();
    }

    final isOutOfStock = widget.product.stockQuantity <= 0;

    return PressableScale(
      onTap: widget.onTap ?? () => context.push(Routes.productDetail, extra: widget.product),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.borderLight, width: 1),
          boxShadow: AppShadows.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Image Container with Badges ─────────────────────────────────
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.15,
                  child: Container(
                    color: AppColors.surfaceMuted,
                    child: widget.product.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.product.imageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 350,
                            memCacheHeight: 350,
                            placeholder: (_, __) => const ShimmerLoading(
                              child: ColoredBox(color: Colors.white),
                            ),
                            errorWidget: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.local_grocery_store_outlined,
                                color: AppColors.textMuted,
                                size: 36,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.local_grocery_store_outlined,
                              color: AppColors.textMuted,
                              size: 36,
                            ),
                          ),
                  ),
                ),
                // Discount Badge
                if (discountPct > 0)
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs + 2,
                        vertical: AppSpacing.xxs,
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
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                // Out of stock overlay badge
                if (isOutOfStock)
                  Positioned(
                    bottom: AppSpacing.sm,
                    left: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: const Text(
                        'Out of Stock',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                // Favorite Button
                Positioned(
                  top: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: PressableScale(
                    onTap: _isLoadingFavorite ? null : _toggleFavorite,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xs + 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.subtle,
                      ),
                      child: Icon(
                        _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 16,
                        color: _isFavorite ? AppColors.saleRed : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ─── Content ─────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Unit Tag
                    Text(
                      widget.product.unit,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    // Product Title
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),

                    // ─── Price & Stepper Row ─────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Price Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.product.hasDiscount)
                                Text(
                                  AppCurrency.format(widget.product.price),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                    decoration: TextDecoration.lineThrough,
                                    height: 1.1,
                                  ),
                                ),
                              Text(
                                AppCurrency.format(widget.product.effectivePrice),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Animated Stepper or Disabled Button
                        if (isOutOfStock)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Text(
                              'Sold Out',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          )
                        else
                          AnimatedQuantityStepper(
                            quantity: inCartQuantity,
                            maxStock: widget.product.stockQuantity,
                            onAdd: () {
                              cart.addToCart(widget.product.id, quantity: 1);
                            },
                            onIncrement: () {
                              if (cartItem != null) {
                                cart.updateQuantity(cartItem.id, inCartQuantity + 1);
                              }
                            },
                            onDecrement: () {
                              if (cartItem != null) {
                                cart.updateQuantity(cartItem.id, inCartQuantity - 1);
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
