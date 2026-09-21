import 'package:flutter/material.dart';
import 'package:opem/core/admin_theme.dart';
import 'package:opem/provider/admin_provider.dart';
import 'package:opem/screens/admin/admin_login_screen.dart';
import 'package:opem/screens/admin/admin_main_screen.dart';
import 'package:provider/provider.dart';

/// Gatekeeper for the Admin Application.
/// Enforces that only users with the 'admin' role can access the portal.
class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();

    // 1. Loading state during auth check
    if (admin.isLoading) {
      return Scaffold(
        backgroundColor: AdminColors.primary,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AdminColors.primarySurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AdminColors.primaryLight, width: 1.5),
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  size: 48,
                  color: AdminColors.accent,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: AdminColors.accent),
              const SizedBox(height: 16),
              const Text(
                'Verifying Administrator Credentials...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Unauthenticated -> Show Admin Login
    if (!admin.isAuthenticated) {
      return const AdminLoginScreen();
    }

    // 3. Authenticated BUT not an Admin -> Show "Admin Access Required" Access Denied Screen!
    if (!admin.isAdmin) {
      return Scaffold(
        backgroundColor: AdminColors.background,
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: AdminColors.danger,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AdminColors.dangerLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.gpp_bad,
                    size: 64,
                    color: AdminColors.danger,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Admin Access Required',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  admin.errorMessage ??
                      'This application is restricted to store administrators and staff. Your account (${admin.profile?.email ?? 'User'}) has the "${admin.profile?.role ?? 'customer'}" role and cannot access this console.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AdminColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => admin.signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out & Return to Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.primary,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 4. Role is 'admin' -> Grant Access to Admin Portal
    return const AdminMainScreen();
  }
}
