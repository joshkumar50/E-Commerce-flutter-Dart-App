import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:opem/core/router.dart';
import 'package:opem/core/theme.dart';
import 'package:opem/models/category.dart';
import 'package:opem/models/product.dart';
import 'package:opem/provider/cart_provider.dart';
import 'package:opem/provider/user_provider.dart';
import 'package:opem/services/analytics_service.dart';
import 'package:opem/services/auth_service.dart';
import 'package:opem/services/category_service.dart';
import 'package:opem/services/product_service.dart';
import 'package:opem/services/remote_config_service.dart';
import 'package:opem/services/wishlist_service.dart';
import 'package:opem/widgets/category_chip.dart';
import 'package:opem/widgets/deals_banner.dart';
import 'package:opem/widgets/product_card.dart';
import 'package:opem/widgets/search_bar_widget.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    // Non-blocking business funnel telemetry
    AnalyticsService.instance.trackAppOpened();
    RemoteConfigService.instance.fetchConfig().then((_) {
      if (mounted) setState(() {});
    });

    final uid = authService.currentUserId;
    if (uid != null) {
      wishlistService.preloadFavorites(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final cartQty = context.watch<CartProvider>().totalQuantity;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header: Delivery Location & Greeting ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    // Location Icon & Address Text
                    Expanded(
                      child: InkWell(
                        onTap: () => context.push(Routes.addresses),
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        user.name.isNotEmpty ? 'Hello, ${user.name.split(' ').first}' : 'Deliver To',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
                                    ],
                                  ),
                                  const Text(
                                    'Bengaluru, Outer Ring Road',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Quick Cart Button
                    IconButton(
                      icon: Badge(
                        isLabelVisible: cartQty > 0,
                        label: Text('$cartQty'),
                        backgroundColor: AppColors.primary,
                        child: const Icon(Icons.shopping_bag_outlined, color: AppColors.textPrimary, size: 26),
                      ),
                      onPressed: () => context.push(Routes.cart),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Search Trigger Bar ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: SearchBarWidget(
                readOnly: true,
                onTap: () => context.push(Routes.search),
              ),
            ),

            // ─── Maintenance Mode Warning Banner (if active) ───────────────
            if (RemoteConfigService.instance.isMaintenanceMode)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.build_circle, color: Colors.brown),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          RemoteConfigService.instance.maintenanceMessage,
                          style: const TextStyle(fontSize: 12, color: Colors.brown, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ─── Promotional Deals Banner (Feature Flag Controlled) ──────────
            if (RemoteConfigService.instance.isFeatureEnabled('deals_banner', defaultValue: true))
              const SliverToBoxAdapter(
                child: DealsBanner(),
              ),

            // ─── Categories Horizontal Selector ──────────────────────────────
            SliverToBoxAdapter(
              child: StreamBuilder<List<Category>>(
                stream: categoryService.watchActiveCategories(),
                builder: (context, snapshot) {
                  final categories = snapshot.data ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Categories',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                // Switch to Categories tab
                              },
                              child: const Text(
                                'See All',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            CategoryChipWidget(
                              label: 'All Items',
                              isSelected: _selectedCategoryId == null,
                              onTap: () => setState(() => _selectedCategoryId = null),
                            ),
                            ...categories.map(
                              (cat) => CategoryChipWidget(
                                category: cat,
                                label: cat.name,
                                isSelected: _selectedCategoryId == cat.id,
                                onTap: () {
                                  setState(() {
                                    _selectedCategoryId = _selectedCategoryId == cat.id ? null : cat.id;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ─── Products Section Title ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: AppColors.accent, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      _selectedCategoryId != null ? 'Filtered Products' : 'Popular & Fresh Groceries',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── 2-Column Product Grid ───────────────────────────────────────
            StreamBuilder<List<Product>>(
              stream: productService.watchActiveProducts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'Unable to load products: ${snapshot.error}',
                          style: const TextStyle(color: AppColors.saleRed),
                        ),
                      ),
                    ),
                  );
                }

                var products = snapshot.data ?? [];
                if (_selectedCategoryId != null) {
                  products = products.where((p) => p.categoryId == _selectedCategoryId).toList();
                }

                if (products.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
                            SizedBox(height: 12),
                            Text(
                              'No products found in this category.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => ProductCard(product: products[index]),
                      childCount: products.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
