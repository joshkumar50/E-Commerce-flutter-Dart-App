import 'package:flutter/material.dart';
import 'package:opem/core/admin_theme.dart';
import 'package:opem/models/category.dart';
import 'package:opem/models/product.dart';
import 'package:opem/models/profile.dart';
import 'package:opem/provider/admin_provider.dart';
import 'package:opem/screens/admin/admin_analytics_screen.dart';
import 'package:opem/screens/admin/admin_audit_log_screen.dart';
import 'package:opem/screens/admin/admin_category_form_screen.dart';
import 'package:opem/screens/admin/admin_customer_support_screen.dart';
import 'package:opem/screens/admin/admin_feature_flags_screen.dart';
import 'package:opem/screens/admin/admin_health_screen.dart';
import 'package:opem/screens/admin/admin_locations_screen.dart';
import 'package:opem/screens/admin/admin_outbox_screen.dart';
import 'package:opem/screens/admin/admin_product_form_screen.dart';
import 'package:opem/services/category_service.dart';
import 'package:opem/services/product_service.dart';
import 'package:opem/services/profile_service.dart';
import 'package:opem/services/remote_config_service.dart';
import 'package:opem/utils/constants.dart';
import 'package:provider/provider.dart';

class AdminDashboardScreen extends StatelessWidget {
  final Function(int tabIndex, {String? filter}) onNavigateTab;

  const AdminDashboardScreen({
    super.key,
    required this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.dashboard_customize, size: 20),
            SizedBox(width: 8),
            Text(adminAppName),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Database is synchronized in Realtime'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Product>>(
        stream: productService.watchAllAdminProducts(),
        builder: (context, productSnap) {
          final products = productSnap.data ?? [];
          final activeProducts = products.where((p) => p.isActive).length;
          final inactiveProducts = products.where((p) => !p.isActive).length;
          final lowStockProducts = products.where((p) => p.stockQuantity <= kLowStockThreshold).toList();

          return StreamBuilder<List<Category>>(
            stream: categoryService.watchAllCategories(),
            builder: (context, catSnap) {
              final categories = catSnap.data ?? [];

              return FutureBuilder<List<Profile>>(
                future: profileService.fetchAllProfiles(),
                builder: (context, profileSnap) {
                  final profiles = profileSnap.data ?? [];
                  final customerCount = profiles.where((p) => p.role == 'customer').length;

                  final isLoading = productSnap.connectionState == ConnectionState.waiting && products.isEmpty;

                  if (isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: AdminColors.primary),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      // ─── Welcome Header ─────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AdminColors.primary, AdminColors.primarySurface],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AdminColors.primaryLight,
                              child: Text(
                                (admin.profile?.fullName.isNotEmpty == true)
                                    ? admin.profile!.fullName[0].toUpperCase()
                                    : 'A',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome, ${admin.profile?.fullName ?? "Admin"}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Row(
                                    children: [
                                      Icon(Icons.circle, color: AdminColors.success, size: 8),
                                      SizedBox(width: 4),
                                      Text(
                                        'Live Realtime Sync Active',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── Quick Actions Row ──────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AdminProductFormScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Product'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminColors.accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AdminCategoryFormScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                              label: const Text('Add Category'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AdminColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ─── Live Metrics Section ───────────────────────────────
                      const Text(
                        'Database Overview',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Metric Grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.45,
                        children: [
                          _MetricCard(
                            label: 'Active Products',
                            value: '$activeProducts',
                            subtitle: '${products.length} total products',
                            icon: Icons.inventory_2,
                            color: AdminColors.accent,
                            onTap: () => onNavigateTab(1, filter: 'active'),
                          ),
                          _MetricCard(
                            label: 'Categories',
                            value: '${categories.length}',
                            subtitle: '${categories.where((c) => c.isActive).length} active',
                            icon: Icons.category,
                            color: AdminColors.info,
                            onTap: () => onNavigateTab(2),
                          ),
                          _MetricCard(
                            label: 'Low Stock',
                            value: '${lowStockProducts.length}',
                            subtitle: '<= $kLowStockThreshold units left',
                            icon: Icons.warning_amber_rounded,
                            color: AdminColors.warning,
                            onTap: () => onNavigateTab(1, filter: 'low_stock'),
                          ),
                          _MetricCard(
                            label: 'Inactive Products',
                            value: '$inactiveProducts',
                            subtitle: 'Hidden from store',
                            icon: Icons.visibility_off_outlined,
                            color: AdminColors.danger,
                            onTap: () => onNavigateTab(1, filter: 'inactive'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Total Customers Full-Width Card
                      _MetricCardFull(
                        label: 'Total Customers',
                        value: '$customerCount',
                        subtitle: 'Registered consumer shopping profiles',
                        icon: Icons.people_alt,
                        color: AdminColors.primarySurface,
                        onTap: () => onNavigateTab(3),
                      ),
                      const SizedBox(height: 24),

                      // ─── Phase 8 Operations & Growth Control Center ─────────
                      const Text(
                        'Operations & Continuous Growth',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Operational Hub Grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.5,
                        children: [
                          _MetricCard(
                            label: 'BI & Funnel',
                            value: 'Analytics',
                            subtitle: 'Conversion & drop-offs',
                            icon: Icons.insights,
                            color: Colors.indigo,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen()),
                            ),
                          ),
                          _MetricCard(
                            label: 'SRE Health',
                            value: 'Integrity',
                            subtitle: 'Checks & sweeper',
                            icon: Icons.health_and_safety,
                            color: Colors.teal,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AdminHealthScreen()),
                            ),
                          ),
                          _MetricCard(
                            label: 'Audit Log',
                            value: 'History',
                            subtitle: 'Immutable actions',
                            icon: Icons.history_edu,
                            color: Colors.blueGrey,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AdminAuditLogScreen()),
                            ),
                          ),
                          _MetricCard(
                            label: 'Support Tool',
                            value: 'Console',
                            subtitle: 'Lookup & refunds',
                            icon: Icons.support_agent,
                            color: Colors.purple,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AdminCustomerSupportScreen()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Feature Flags & Emergency Kill Switches Banner Card
                      _MetricCardFull(
                        label: 'Feature Flags & Kill Switches',
                        value: 'Remote Config',
                        subtitle: 'Dynamic rollouts, maintenance mode & kill switches',
                        icon: Icons.toggle_on,
                        color: Colors.deepOrange,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AdminFeatureFlagsScreen()),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── Phase 9 Resilience & Scale Hub ─────────
                      const Text(
                        'Extreme Scale & Resilience (Phase 9)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: RemoteConfigService.instance.isHighTrafficMode
                                      ? AdminColors.warning.withValues(alpha: 0.2)
                                      : AdminColors.accent.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  RemoteConfigService.instance.isHighTrafficMode
                                      ? Icons.offline_bolt
                                      : Icons.verified_user_outlined,
                                  color: RemoteConfigService.instance.isHighTrafficMode
                                      ? AdminColors.warning
                                      : AdminColors.accent,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Service Level: ',
                                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                        Text(
                                          RemoteConfigService.instance.serviceLevel.name.toUpperCase(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: RemoteConfigService.instance.serviceLevel == ServiceLevel.full
                                                ? AdminColors.accent
                                                : AdminColors.warning,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      RemoteConfigService.instance.isHighTrafficMode
                                          ? 'High-Traffic Mode ACTIVE (load shedding)'
                                          : 'Normal Operations (full auxiliary systems)',
                                      style: const TextStyle(fontSize: 11, color: AdminColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.5,
                        children: [
                          _MetricCard(
                            label: 'Dark Stores',
                            value: 'Locations',
                            subtitle: 'Multi-hub inventory',
                            icon: Icons.storefront_outlined,
                            color: Colors.blueAccent,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AdminLocationsScreen()),
                            ),
                          ),
                          _MetricCard(
                            label: 'Outbox Events',
                            value: 'Queue',
                            subtitle: 'Transactional dispatcher',
                            icon: Icons.outbox_rounded,
                            color: Colors.deepPurpleAccent,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AdminOutboxScreen()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ─── Low Stock Alerts Section ───────────────────────────
                      if (lowStockProducts.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.notification_important, color: AdminColors.warning, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Inventory Attention Required',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AdminColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () => onNavigateTab(1, filter: 'low_stock'),
                              child: const Text('View All', style: TextStyle(color: AdminColors.accent)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...lowStockProducts.take(4).map(
                          (prod) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AdminColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: prod.imageUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          prod.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined),
                                        ),
                                      )
                                    : const Icon(Icons.shopping_bag_outlined),
                              ),
                              title: Text(
                                prod.name,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'Unit: ${prod.unit} • Price: ₹${prod.effectivePrice.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: prod.stockQuantity == 0 ? AdminColors.dangerLight : AdminColors.warningLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      prod.stockQuantity == 0 ? 'OUT OF STOCK' : '${prod.stockQuantity} left',
                                      style: TextStyle(
                                        color: prod.stockQuantity == 0 ? AdminColors.danger : AdminColors.warning,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle, color: AdminColors.accent),
                                    tooltip: 'Add 10 Stock',
                                    onPressed: () async {
                                      await productService.updateStock(prod.id, prod.stockQuantity + 10);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Restocked "${prod.name}" (+10 units)'),
                                            duration: const Duration(seconds: 1),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AdminColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCardFull extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MetricCardFull({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AdminColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AdminColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
