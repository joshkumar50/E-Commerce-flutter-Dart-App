import 'package:opem/widgets/ui/app_modals.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:opem/core/design_tokens.dart';
import 'package:opem/core/router.dart';
import 'package:opem/provider/cart_provider.dart';
import 'package:opem/widgets/ui/animated_primary_button.dart';
import 'package:opem/widgets/ui/empty_state_view.dart';
import 'package:opem/widgets/ui/pressable_scale.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    if (cart.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (cart.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'My Cart',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        body: EmptyStateView(
          icon: Icons.shopping_basket_outlined,
          title: 'Your cart is empty',
          message:
              'Explore fresh farm produce, groceries, and staples and add them to your basket.',
          actionLabel: 'Start Shopping',
          onAction: () => context.go(Routes.home),
        ),
      );
    }

    const double freeDeliveryThreshold = 500.0;
    final double subtotal = cart.totalAmount;
    final double deliveryFee = subtotal >= freeDeliveryThreshold ? 0.0 : 40.0;
    final double tax = double.parse((subtotal * 0.05).toStringAsFixed(2));
    final double total = subtotal + deliveryFee + tax;
    final double deliveryProgress =
        (subtotal / freeDeliveryThreshold).clamp(0.0, 1.0);
    final bool freeDeliveryUnlocked = subtotal >= freeDeliveryThreshold;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'My Cart (${cart.totalQuantity} items)',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _showClearCartDialog(context, cart);
            },
            icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.saleRed),
            label: Text(
              'Clear',
              style: GoogleFonts.inter(
                color: AppColors.saleRed,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
        children: [
          // ── Free Delivery Progress Card ─────────────────────────────────
          AnimatedContainer(
            duration: AppMotion.normal,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: freeDeliveryUnlocked
                  ? AppColors.primarySoft
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: freeDeliveryUnlocked
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.borderLight,
              ),
              boxShadow: AppShadows.subtle,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: AppMotion.normal,
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: freeDeliveryUnlocked
                            ? AppColors.primary
                            : AppColors.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        freeDeliveryUnlocked
                            ? Icons.check_rounded
                            : Icons.delivery_dining_rounded,
                        color: freeDeliveryUnlocked
                            ? Colors.white
                            : AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        freeDeliveryUnlocked
                            ? '🎉 You unlocked FREE delivery!'
                            : 'Add ${AppCurrency.format(freeDeliveryThreshold - subtotal)} more for FREE delivery',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: freeDeliveryUnlocked
                              ? AppColors.primaryDark
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: deliveryProgress),
                    duration: AppMotion.slow,
                    curve: AppMotion.decelerate,
                    builder: (context, animatedValue, _) =>
                        LinearProgressIndicator(
                      value: animatedValue,
                      minHeight: 7,
                      backgroundColor: AppColors.surfaceMuted,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Cart Items (swipe to remove) ────────────────────────────────
          ...cart.items.map((item) {
            final product = item.product;
            final itemPrice = product?.effectivePrice ?? 0.0;
            final lineTotal = itemPrice * item.quantity;

            return Dismissible(
              key: ValueKey(item.id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) {
                HapticFeedback.mediumImpact();
                cart.updateQuantity(item.id, 0);
              },
              background: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: AppColors.saleRed,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_rounded,
                    color: Colors.white, size: 26),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: AppShadows.subtle,
                ),
                child: Row(
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Container(
                        width: 72,
                        height: 72,
                        color: AppColors.surfaceMuted,
                        child: (product != null && product.imageUrl.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: product.imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.local_grocery_store_outlined,
                                  size: 28,
                                  color: AppColors.textMuted,
                                ),
                              )
                            : const Icon(
                                Icons.local_grocery_store_outlined,
                                size: 28,
                                color: AppColors.textMuted,
                              ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),

                    // Name & Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product?.name ?? 'Grocery Item',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            product?.unit ?? '1 unit',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppCurrency.format(itemPrice),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                AppCurrency.format(lineTotal),
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    // Quantity Stepper
                    _QuantityStepper(
                      quantity: item.quantity,
                      onDecrement: () {
                        HapticFeedback.lightImpact();
                        cart.updateQuantity(item.id, item.quantity - 1);
                      },
                      onIncrement: () {
                        HapticFeedback.lightImpact();
                        cart.updateQuantity(item.id, item.quantity + 1);
                      },
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: AppSpacing.sm),

          // ── Bill Summary Card ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: AppShadows.subtle,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Bill Summary',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _BillRow(label: 'Item Subtotal', value: AppCurrency.format(subtotal)),
                const SizedBox(height: AppSpacing.sm),
                _BillRow(
                  label: 'Delivery Fee',
                  value: deliveryFee == 0.0 ? 'FREE' : AppCurrency.format(deliveryFee),
                  valueColor: deliveryFee == 0.0 ? AppColors.primary : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                _BillRow(
                    label: 'Taxes & GST (5%)',
                    value: AppCurrency.format(tax)),
                const Divider(height: 24, color: AppColors.border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'To Pay',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      AppCurrency.format(total),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Checkout Button ─────────────────────────────────────────────
          AnimatedPrimaryButton(
            label: 'Proceed to Checkout',
            leadingIcon: Icons.lock_outline_rounded,
            onPressed: () {
              HapticFeedback.mediumImpact();
              context.push(Routes.checkout);
            },
            height: 56,
          ),

          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_outlined,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                'Secure encrypted checkout',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, CartProvider cart) {
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear Cart?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'All items will be removed from your cart.',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              cart.clearCart();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.saleRed),
            child: Text('Clear All',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Quantity Stepper widget ──────────────────────────────────────────────────
class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _QuantityStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: quantity == 1
                ? Icons.delete_outline_rounded
                : Icons.remove_rounded,
            iconColor: quantity == 1 ? AppColors.saleRed : AppColors.primary,
            onTap: onDecrement,
          ),
          SizedBox(
            width: 28,
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: Text(
                '$quantity',
                key: ValueKey<int>(quantity),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            iconColor: AppColors.primary,
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _StepButton(
      {required this.icon, required this.iconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      scaleFactor: 0.85,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 16, color: iconColor),
      ),
    );
  }
}

// ── Bill Row helper ──────────────────────────────────────────────────────────
class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _BillRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontSize: 13)),
        Text(
          value,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
