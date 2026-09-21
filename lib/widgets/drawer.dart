import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:opem/core/router.dart';
import 'package:opem/provider/user_provider.dart';
import 'package:opem/services/auth_service.dart';
import 'package:provider/provider.dart';

/// App-wide navigation drawer using standard Material Icons.
class GlobalDrawer extends StatelessWidget {
  final int pageIndex;
  const GlobalDrawer({super.key, required this.pageIndex});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final userName = userProvider.name.isNotEmpty
        ? userProvider.name
        : (userProvider.isAdmin ? 'Admin User' : 'Grocery Shopper');
    final userEmail = userProvider.email ?? 'Demo Mode';
    final avatarUrl = userProvider.avatarUrl;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Row(
              children: [
                Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (userProvider.isAdmin) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ADMIN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            accountEmail: Text(userEmail),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? Icon(
                      userProvider.isAdmin ? Icons.admin_panel_settings : Icons.person,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    )
                  : null,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          _DrawerItem(
            icon: Icons.shopping_bag_outlined,
            label: 'Shop',
            selected: pageIndex == 0,
            onTap: () => _nav(context, Routes.home),
          ),
          _DrawerItem(
            icon: Icons.add_box_outlined,
            label: 'Add Product',
            selected: pageIndex == 1,
            onTap: () => _nav(context, Routes.sell),
          ),
          _DrawerItem(
            icon: Icons.inventory_2_outlined,
            label: 'My Products',
            selected: pageIndex == 2,
            onTap: () => _nav(context, Routes.myProducts),
          ),
          _DrawerItem(
            icon: Icons.receipt_long_outlined,
            label: 'My Orders (Bought)',
            selected: pageIndex == 3,
            onTap: () => _nav(context, Routes.buyOrders),
          ),
          _DrawerItem(
            icon: Icons.local_shipping_outlined,
            label: 'My Orders (Sold)',
            selected: pageIndex == 4,
            onTap: () => _nav(context, Routes.sellOrders),
          ),
          const Divider(),
          _DrawerItem(
            icon: Icons.logout,
            label: 'Sign Out',
            selected: false,
            onTap: () async {
              await authService.signOut();
              if (context.mounted) {
                context.read<UserProvider>().reset();
                context.go(Routes.login);
              }
            },
          ),
        ],
      ),
    );
  }

  void _nav(BuildContext context, String route) {
    Navigator.pop(context); // close drawer
    context.go(route);
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DrawerItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : null),
      title: Text(label),
      selected: selected,
      selectedTileColor:
          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      selectedColor: Theme.of(context).colorScheme.primary,
      onTap: onTap,
    );
  }
}
