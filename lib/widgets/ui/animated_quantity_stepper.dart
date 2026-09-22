import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opem/core/theme.dart';
import 'pressable_scale.dart';

/// Zepto/Blinkit-style animated quantity stepper.
/// Seamlessly morphs between compact '+ ADD' button and '[-] [count] [+]' stepper with slide transitions.
class AnimatedQuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final int maxStock;
  final double height;
  final bool isCompact;

  const AnimatedQuantityStepper({
    super.key,
    required this.quantity,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
    this.maxStock = 99,
    this.height = 32.0,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.normal,
      switchInCurve: AppMotion.standard,
      switchOutCurve: AppMotion.standard,
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: quantity > 0
          ? _buildActiveStepper(context)
          : _buildAddButton(context),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return PressableScale(
      key: const ValueKey('add_button'),
      onTap: () {
        HapticFeedback.lightImpact();
        onAdd();
      },
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 16),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: AppRadius.r8,
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              'ADD',
              style: TextStyle(
                fontSize: isCompact ? 12 : 13,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveStepper(BuildContext context) {
    return Container(
      key: const ValueKey('active_stepper'),
      height: height,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.r8,
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decrement button
          PressableScale(
            onTap: () {
              HapticFeedback.lightImpact();
              onDecrement();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: const Icon(Icons.remove, size: 16, color: Colors.white),
            ),
          ),

          // Animated number counter
          Container(
            constraints: const BoxConstraints(minWidth: 20),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              transitionBuilder: (child, animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Text(
                '$quantity',
                key: ValueKey<int>(quantity),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Increment button
          PressableScale(
            onTap: (quantity < maxStock)
                ? () {
                    HapticFeedback.lightImpact();
                    onIncrement();
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Icon(
                Icons.add,
                size: 16,
                color: (quantity < maxStock) ? Colors.white : Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
