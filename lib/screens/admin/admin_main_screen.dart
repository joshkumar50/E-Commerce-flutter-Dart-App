import 'package:flutter/material.dart';
import 'package:opem/core/admin_theme.dart';
import 'package:opem/screens/admin/admin_categories_screen.dart';
import 'package:opem/screens/admin/admin_customers_screen.dart';
import 'package:opem/screens/admin/admin_dashboard_screen.dart';
import 'package:opem/screens/admin/admin_orders_screen.dart';
import 'package:opem/screens/admin/admin_products_screen.dart';
import 'package:opem/screens/admin/admin_profile_screen.dart';
import 'package:opem/services/app_update_service.dart';

class AdminMainScreen extends StatefulWidget {
  final int initialIndex;

  const AdminMainScreen({super.key, this.initialIndex = 0});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  late int _currentIndex;
  String? _productsFilter;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    // Check for updates automatically in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateService.instance.checkForUpdate(
          isAdmin: true,
          context: context,
        );
      }
    });
  }

  void _navigateToTab(int index, {String? filter}) {
    setState(() {
      _currentIndex = index;
      if (index == 1 && filter != null) {
        _productsFilter = filter;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      AdminDashboardScreen(onNavigateTab: _navigateToTab),
      AdminProductsScreen(
        key: ValueKey(_productsFilter ?? 'products_all'),
        initialFilter: _productsFilter,
      ),
      const AdminCategoriesScreen(),
      const AdminOrdersScreen(),
      const AdminCustomersScreen(),
      const AdminProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AdminColors.cardBorder, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
              if (index != 1) {
                _productsFilter = null; // Clear filter when leaving products
              }
            });
          },
          backgroundColor: Colors.white,
          indicatorColor: AdminColors.primaryLight.withValues(alpha: 0.12),
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: AdminColors.primary),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2, color: AdminColors.primary),
              label: 'Products',
            ),
            NavigationDestination(
              icon: Icon(Icons.category_outlined),
              selectedIcon: Icon(Icons.category, color: AdminColors.primary),
              label: 'Categories',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long, color: AdminColors.primary),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_alt_outlined),
              selectedIcon: Icon(Icons.people_alt, color: AdminColors.primary),
              label: 'Customers',
            ),
            NavigationDestination(
              icon: Icon(Icons.manage_accounts_outlined),
              selectedIcon: Icon(Icons.manage_accounts, color: AdminColors.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
