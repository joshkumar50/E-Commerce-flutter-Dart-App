import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:opem/core/design_tokens.dart';

/// A premium animated CTA button with:
///  - Smooth loading state cross-fade (spinner ↔ label, no layout jump)
///  - Scale press feedback via [GestureDetector] (physics-spring-like feel)
///  - Gradient background with a glow shadow matching the brand colour
///  - Respects platform reduced-motion preference
///  - Haptic feedback on press
class AnimatedPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? leadingIcon;
  final Color? color;
  final double height;

  const AnimatedPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.leadingIcon,
    this.color,
    this.height = 52,
  });

  @override
  State<AnimatedPrimaryButton> createState() => _AnimatedPrimaryButtonState();
}

class _AnimatedPrimaryButtonState extends State<AnimatedPrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed == null || widget.isLoading) return;
    setState(() => _isPressed = true);
    _pressController.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails _) {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _pressController.reverse();
    if (!widget.isLoading) widget.onPressed?.call();
  }

  void _onTapCancel() {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  bool get _isDisabled => widget.onPressed == null || widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ?? AppColors.primary;
    final reducedMotion = appPrefersReducedMotion(context);

    final button = GestureDetector(
      onTapDown: reducedMotion ? null : _onTapDown,
      onTapUp: reducedMotion ? null : _onTapUp,
      onTapCancel: reducedMotion ? null : _onTapCancel,
      onTap: reducedMotion ? (widget.isLoading ? null : widget.onPressed) : null,
      child: AnimatedBuilder(
        animation: _pressController,
        builder: (context, child) {
          return Transform.scale(
            scale: reducedMotion ? 1.0 : _scaleAnim.value,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: widget.height,
          decoration: BoxDecoration(
            gradient: _isDisabled
                ? null
                : LinearGradient(
                    colors: [
                      baseColor,
                      Color.lerp(baseColor, Colors.black, 0.15)!,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
            color: _isDisabled ? AppColors.surfaceMuted : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isDisabled
                ? null
                : [
                    BoxShadow(
                      color: baseColor.withValues(alpha: _isPressed ? 0.2 : 0.38),
                      blurRadius: _isPressed ? 8 : 16,
                      offset: Offset(0, _isPressed ? 2 : 6),
                    ),
                  ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      key: ValueKey('loader'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      key: const ValueKey('label'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.leadingIcon != null) ...[
                          Icon(widget.leadingIcon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _isDisabled ? AppColors.textMuted : Colors.white,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );

    return button;
  }
}
