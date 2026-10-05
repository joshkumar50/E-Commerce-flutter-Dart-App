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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _passwordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    try {
      await authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
      );
      // Note: GoRouter automatically redirects to home because of AuthRouterListenable
      // in router.dart when authService.isSignedIn becomes true.
    } on AuthException catch (e) {
      EasyLoading.showError(e.message);
    } catch (e) {
      EasyLoading.showError('Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignUp() async {
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
      EasyLoading.showError('Google sign up failed: ${e.toString()}');
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
            stops: const [0.0, 0.40, 1.0],
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
                    // ── Header Row ────────────────────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton.filled(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                        onPressed: () => context.pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          foregroundColor: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Create Account',
                      style: GoogleFonts.outfit(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Join B-Buys for premium grocery delivery',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 36),

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
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline, color: colorScheme.primary, size: 20),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.transparent,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Full name is required';
                              if (v.trim().length < 2) return 'Name must be at least 2 characters';
                              return null;
                            },
                          ),
                          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary, size: 20),
                              border: const OutlineInputBorder(
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
                            onFieldSubmitted: (_) => _handleSignUp(),
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
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Password is required';
                              if (v.length < 6) return 'Password must be at least 6 characters';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Primary Register Button ────────────────────────────────
                    AnimatedPrimaryButton(
                      label: 'Create Account',
                      isLoading: _isLoading,
                      onPressed: _handleSignUp,
                      leadingIcon: Icons.person_add_outlined,
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

                    // ── Social Sign Up Buttons ────────────────────────────────
                    _SocialAuthButton(
                      icon: Icons.phone_iphone_rounded,
                      iconColor: const Color(0xFF059669),
                      label: 'Sign up with Phone',
                      onPressed: () => context.push(Routes.phoneLogin),
                    ),
                    const SizedBox(height: 10),
                    _SocialAuthButton(
                      icon: Icons.g_mobiledata,
                      iconColor: Colors.blue,
                      label: 'Sign up with Google',
                      onPressed: _handleGoogleSignUp,
                    ),

                    const SizedBox(height: 36),

                    // ── Sign In Footer ────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account?",
                          style: GoogleFonts.inter(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          child: Text(
                            'Sign In',
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

class _SocialAuthButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onPressed;

  const _SocialAuthButton({
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
