import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opem/core/admin_theme.dart';
import 'package:opem/provider/admin_provider.dart';
import 'package:opem/utils/constants.dart';
import 'package:opem/widgets/ui/animated_primary_button.dart';
import 'package:provider/provider.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(
    text: isDemoMode ? 'admin@bbuys.com' : '',
  );
  final _passwordController = TextEditingController(
    text: isDemoMode ? 'admin123' : '',
  );
  bool _obscurePassword = true;
  bool _submitting = false;

  late final AnimationController _cardAnimController;
  late final Animation<double> _cardFade;
  late final Animation<double> _cardSlide;

  @override
  void initState() {
    super.initState();
    _cardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _cardFade = CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOut);
    _cardSlide = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOutCubic),
    );
    _cardAnimController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _cardAnimController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    final admin = context.read<AdminProvider>();
    final success = await admin.signInAsAdmin(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (mounted) {
      setState(() => _submitting = false);
      if (!success && admin.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(admin.errorMessage!)),
              ],
            ),
            backgroundColor: AdminColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.primary,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F172A), // Slate 900
              Color(0xFF1E293B), // Slate 800
              Color(0xFF0F172A), // Slate 900
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: AnimatedBuilder(
                animation: _cardAnimController,
                builder: (context, child) => Opacity(
                  opacity: _cardFade.value,
                  child: Transform.translate(
                    offset: Offset(0, _cardSlide.value),
                    child: child,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Brand Badge ─────────────────────────────────────────
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF047857)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AdminColors.accent.withValues(alpha: 0.4),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.store_mall_directory_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      adminAppName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Operations & Catalog Console',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.65),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ── Login Card ──────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Administrator Login',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AdminColors.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Sign in with your authorized admin credentials',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AdminColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Email Field
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                decoration: const InputDecoration(
                                  labelText: 'Admin Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Email is required';
                                  }
                                  final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+');
                                  if (!emailRegex.hasMatch(val.trim())) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password Field
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleLogin(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AdminColors.textSecondary,
                                    ),
                                    onPressed: () {
                                      setState(() => _obscurePassword = !_obscurePassword);
                                    },
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Password is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),

                              // Submit Button
                              AnimatedPrimaryButton(
                                label: 'Sign In to Admin Console',
                                isLoading: _submitting,
                                onPressed: _handleLogin,
                                leadingIcon: Icons.shield_outlined,
                                color: AdminColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Demo Mode Controls ──────────────────────────────────
                    if (isDemoMode) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.science_outlined, color: AdminColors.warning, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Demo Mode Testing Presets',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                _emailController.text = 'admin@bbuys.com';
                                _passwordController.text = 'admin123';
                                context.read<AdminProvider>().simulateAdminLoginInDemo();
                              },
                              icon: const Icon(Icons.verified_user, color: AdminColors.accent, size: 18),
                              label: const Text(
                                'Quick Login as Store Admin',
                                style: TextStyle(color: Colors.white, fontSize: 13),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AdminColors.accent),
                                minimumSize: const Size(double.infinity, 42),
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                _emailController.text = 'alex.morgan@example.com';
                                _passwordController.text = 'customer123';
                                context.read<AdminProvider>().simulateCustomerLoginInDemo();
                              },
                              icon: const Icon(Icons.block, color: AdminColors.danger, size: 18),
                              label: const Text(
                                'Test as Customer → Access Denied',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AdminColors.danger),
                                minimumSize: const Size(double.infinity, 42),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    // Security Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 12, color: Colors.white.withValues(alpha: 0.4)),
                        const SizedBox(width: 4),
                        Text(
                          'Secured by Supabase RLS',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
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
    );
  }
}
