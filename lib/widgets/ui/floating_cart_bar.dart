import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:opem/core/design_tokens.dart';
import 'package:opem/core/router.dart';
import 'package:opem/provider/cart_provider.dart';
import 'package:opem/widgets/ui/pressable_scale.dart';

/// A quick-commerce style floating cart summary bar that animates into view
/// when the cart has items. Features item count badge, live total in INR,
/// and a direct "View Cart" call to action.
class FloatingCartBar extends StatelessWidget {
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final double bottomOffset;

  const FloatingCartBar({
    super.key,
    this.onTap,
    this.margin,
    this.bottomOffset = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        final hasItems = cart.itemCount > 0;

        return AnimatedSlide(
          duration: AppMotion.normal,
          curve: AppMotion.emphasized,
          offset: hasItems ? Offset.zero : const Offset(0, 1.5),
          child: AnimatedOpacity(
            duration: AppMotion.normal,
            curve: Curves.easeInOut,
            opacity: hasItems ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !hasItems,
              child: SafeArea(
                child: Padding(
                  padding: margin ??
                      EdgeInsets.only(
                        left: AppSpacing.md,
                        right: AppSpacing.md,
                        bottom: bottomOffset,
                      ),
                  child: PressableScale(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      if (onTap != null) {
                        onTap!();
                      } else {
                        context.push(Routes.cart);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryDark,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: AppShadows.floating,
                      ),
                      child: Row(
                        children: [
                          // Item count pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.shopping_bag_outlined,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  '${cart.itemCount} ${cart.itemCount == 1 ? "item" : "items"}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          // Price info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppCurrency.format(cart.totalPrice),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const Text(
                                  'plus taxes & delivery',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // View Cart Action
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'View Cart',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: AppSpacing.xs),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
