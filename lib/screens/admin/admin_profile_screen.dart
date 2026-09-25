import 'package:flutter/material.dart';
import 'package:opem/core/admin_theme.dart';
import 'package:opem/provider/admin_provider.dart';
import 'package:opem/services/app_update_service.dart';
import 'package:opem/utils/constants.dart';
import 'package:provider/provider.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  void _confirmLogout(BuildContext context, AdminProvider admin) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to end your administrator session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await admin.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final profile = admin.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Profile & Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Profile Header Card ──────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AdminColors.primaryLight,
                    backgroundImage: (profile?.avatarUrl.isNotEmpty == true)
                        ? NetworkImage(profile!.avatarUrl)
                        : null,
                    child: (profile?.avatarUrl.isEmpty ?? true)
                        ? Text(
                            profile?.fullName.isNotEmpty == true
                                ? profile!.fullName[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile?.fullName ?? 'Administrator',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile?.email ?? '',
                    style: const TextStyle(fontSize: 13, color: AdminColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AdminColors.accentLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AdminColors.accent),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 14, color: AdminColors.accentDark),
                        SizedBox(width: 4),
                        Text(
                          'STORE ADMINISTRATOR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AdminColors.accentDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Environment & System Info ────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.hub_outlined, color: AdminColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Backend Infrastructure',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'Database Authority',
                    value: isDemoMode ? 'Demo In-Memory Mode' : 'Supabase PostgreSQL',
                  ),
                  _InfoRow(
                    label: 'Row Level Security',
                    value: 'Enforced via Postgres RLS',
                  ),
                  _InfoRow(
                    label: 'Realtime Engine',
                    value: 'Active WebSocket Sync',
                  ),
                  _InfoRow(
                    label: 'Low Stock Threshold',
                    value: '$kLowStockThreshold units',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Demo Role Switcher ───────────────────────────────────────────
          if (isDemoMode) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shield_outlined, color: AdminColors.warning, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Role Security Testing',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Test how the Admin App responds when a customer attempts unauthorized access:',
                      style: TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => admin.simulateCustomerLoginInDemo(),
                      icon: const Icon(Icons.lock_person_outlined, color: AdminColors.danger),
                      label: const Text(
                        'Simulate Customer Role (Triggers Access Denied)',
                        style: TextStyle(color: AdminColors.danger, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AdminColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ─── Direct App Updates & Deployment ─────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.system_update_rounded, color: AdminColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Direct App Updates',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Built-in Over-The-Air app update delivery directly from GitHub repository releases.',
                    style: TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        AppUpdateService.instance.checkForUpdate(
                          isAdmin: true,
                          context: context,
                          isManual: true,
                        );
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Check for Admin App Update'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminColors.primary,
                        side: const BorderSide(color: AdminColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Logout Button ────────────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: () => _confirmLogout(context, admin),
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out of Admin Console'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AdminColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminColors.textPrimary)),
        ],
      ),
    );
  }
}
