import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:opem/core/router.dart';
import 'package:opem/services/auth_service.dart';
import 'package:opem/widgets/ui/animated_primary_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _passwordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    try {
      await authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Note: GoRouter automatically redirects to home because of AuthRouterListenable
      // in router.dart when authService.isSignedIn becomes true.
    } on AuthException catch (e) {
      EasyLoading.showError(e.message);
    } catch (e) {
      EasyLoading.showError('Sign in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    EasyLoading.show(status: 'Connecting to Google…');
    try {
      final res = await authService.signInWithGoogle();
      if (res != null || authService.isSignedIn) {
        EasyLoading.dismiss();
        // Router will handle the redirect.
      } else {
        EasyLoading.showInfo('Waiting for browser authentication…');
      }
    } on AuthException catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError(e.message);
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError('Google sign in failed: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.35),
              colorScheme.surface,
              colorScheme.surface,
            ],
            stops: const [0.0, 0.45, 1.0],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Logo + Brand ──────────────────────────────────────────
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.75)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.shopping_basket_rounded, size: 44, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to continue to B-Buys',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── Input Card ────────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary, size: 20),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.transparent,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Email is required';
                              final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+');
                              return emailRegex.hasMatch(v.trim()) ? null : 'Enter a valid email address';
                            },
                          ),
                          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_passwordVisible,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleSignIn(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _passwordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  size: 20,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                              ),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.transparent,
                            ),
                            validator: (v) =>
                                (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push(Routes.forgotPassword),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Primary Sign In Button ────────────────────────────────
                    AnimatedPrimaryButton(
                      label: 'Sign In',
                      isLoading: _isLoading,
                      onPressed: _handleSignIn,
                    ),

                    const SizedBox(height: 28),

                    // ── Divider ───────────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(child: Divider(color: colorScheme.outlineVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: GoogleFonts.inter(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: colorScheme.outlineVariant)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Social Buttons ────────────────────────────────────────
                    _SocialLoginButton(
                      icon: Icons.phone_iphone_rounded,
                      iconColor: const Color(0xFF059669),
                      label: 'Continue with Phone',
                      onPressed: () => context.push(Routes.phoneLogin),
                    ),
                    const SizedBox(height: 10),
                    _SocialLoginButton(
                      icon: Icons.g_mobiledata,
                      iconColor: Colors.blue,
                      label: 'Continue with Google',
                      onPressed: _handleGoogleSignIn,
                    ),

                    const SizedBox(height: 36),

                    // ── Sign Up Footer ────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: GoogleFonts.inter(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push(Routes.register),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          child: Text(
                            'Create Account',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable social login/signup button with a subtle hover effect.
class _SocialLoginButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onPressed;

  const _SocialLoginButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.8)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
