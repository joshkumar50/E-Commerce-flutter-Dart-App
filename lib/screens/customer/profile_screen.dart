import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:opem/core/router.dart';
import 'package:opem/core/theme.dart';
import 'package:opem/provider/user_provider.dart';
import 'package:opem/services/auth_service.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final name = user.name.isNotEmpty ? user.name : 'Customer';
    final email = user.email ?? 'shopper@example.com';
    final avatarUrl = user.avatarUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Profile Header Card ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? const Icon(Icons.person, size: 36, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'CUSTOMER',
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ─── Menu Options ─────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _ProfileMenuItem(
                  icon: Icons.receipt_long_outlined,
                  title: 'My Orders',
                  subtitle: 'Track order status and purchase history',
                  onTap: () => context.push(Routes.orders),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.borderLight),
                _ProfileMenuItem(
                  icon: Icons.location_on_outlined,
                  title: 'Delivery Addresses',
                  subtitle: 'Manage saved delivery addresses',
                  onTap: () => context.push(Routes.addresses),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.borderLight),
                _ProfileMenuItem(
                  icon: Icons.favorite_border,
                  title: 'My Wishlist',
                  subtitle: 'Saved organic groceries',
                  onTap: () => context.push(Routes.wishlist),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.borderLight),
                _ProfileMenuItem(
                  icon: Icons.notifications_none,
                  title: 'Notifications',
                  subtitle: 'Store offers and updates',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notifications coming in future release')),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56, color: AppColors.borderLight),
                _ProfileMenuItem(
                  icon: Icons.help_outline,
                  title: 'Help & Customer Care',
                  subtitle: 'FAQs and support contact',
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'B-Buys Grocery',
                      applicationVersion: 'v1.0.0 (Phase 3)',
                      children: const [
                        Text('B-Buys Grocery provides fresh, organic produce delivered to your doorstep.'),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ─── Sign Out ─────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.saleRedLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.logout, color: AppColors.saleRed, size: 20),
              ),
              title: const Text(
                'Sign Out',
                style: TextStyle(
                  color: AppColors.saleRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              onTap: () async {
                await authService.signOut();
                if (context.mounted) {
                  context.read<UserProvider>().reset();
                  context.go(Routes.login);
                }
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
