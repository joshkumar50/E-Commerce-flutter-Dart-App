import 'package:flutter/material.dart';
import 'package:opem/core/admin_theme.dart';
import 'package:opem/provider/admin_provider.dart';
import 'package:opem/utils/constants.dart';
import 'package:provider/provider.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(
    text: isDemoMode ? 'admin@bbuys.com' : '',
  );
  final _passwordController = TextEditingController(
    text: isDemoMode ? 'admin123' : '',
  );
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

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
            content: Text(admin.errorMessage!),
            backgroundColor: AdminColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ─── App Logo & Title ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdminColors.primarySurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AdminColors.primaryLight, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.store_mall_directory,
                    size: 44,
                    color: AdminColors.accent,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  adminAppName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Operations & Catalog Console',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 32),

                // ─── Login Card ─────────────────────────────────────────────
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Administrator Login',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AdminColors.textPrimary,
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
                            decoration: const InputDecoration(
                              labelText: 'Admin Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!val.contains('@')) {
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
                          const SizedBox(height: 24),

                          // Submit Button
                          ElevatedButton(
                            onPressed: _submitting ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminColors.primary,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Sign In to Admin Console',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ─── Demo Mode Controls ─────────────────────────────────────
                if (isDemoMode) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AdminColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminColors.primaryLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.science_outlined, color: AdminColors.warning, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Demo Mode Testing Presets',
                              style: TextStyle(
                                color: Colors.white,
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
                            'Quick Login as Store Admin (Role: admin)',
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
                            'Test Login as Customer (Role: customer -> Access Denied)',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
