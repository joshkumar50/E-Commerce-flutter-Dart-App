import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:opem/core/design_tokens.dart';
import 'package:opem/core/router.dart';
import 'package:opem/models/address.dart';
import 'package:opem/models/category.dart';
import 'package:opem/models/product.dart';
import 'package:opem/provider/cart_provider.dart';
import 'package:opem/provider/user_provider.dart';
import 'package:opem/services/address_service.dart';
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
import 'package:opem/widgets/ui/empty_state_view.dart';
import 'package:opem/widgets/ui/error_state_view.dart';
import 'package:opem/widgets/ui/floating_cart_bar.dart';
import 'package:opem/widgets/ui/pressable_scale.dart';
import 'package:opem/widgets/ui/shimmer_loading.dart';

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
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // ─── Header: Delivery Location & Quick Icons ──────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        // Location Pill
                        Expanded(
                          child: PressableScale(
                            onTap: () => context.push(Routes.addresses),
                            scaleFactor: 0.98,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: const Icon(
                                    Icons.flash_on_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            '⚡ 10-15 MINS',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primaryDark,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 16,
                                            color: AppColors.textSecondary,
                                          ),
                                        ],
                                      ),
                                      StreamBuilder<List<Address>>(
                                        stream: user.id != null
                                            ? addressService.watchAddresses(user.id!)
                                            : const Stream.empty(),
                                        builder: (context, addrSnap) {
                                          final addresses = addrSnap.data ?? [];
                                          final defaultAddr = addresses.where((a) => a.isDefault).firstOrNull ??
                                              addresses.firstOrNull;

                                          final locationTitle = defaultAddr != null
                                              ? '${user.name.isNotEmpty ? "${user.name.split(' ').first} • " : ""}${defaultAddr.label.isNotEmpty ? defaultAddr.label : defaultAddr.addressLine1}'
                                              : (user.name.isNotEmpty
                                                  ? '${user.name.split(' ').first} • Add Address'
                                                  : 'Select Delivery Address');

                                          return Text(
                                            locationTitle,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Quick Cart Icon
                        PressableScale(
                          onTap: () => context.push(Routes.cart),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.borderLight),
                              boxShadow: AppShadows.subtle,
                            ),
                            child: Badge(
                              isLabelVisible: cartQty > 0,
                              label: Text('$cartQty'),
                              backgroundColor: AppColors.primary,
                              child: const Icon(
                                Icons.shopping_bag_outlined,
                                color: AppColors.textPrimary,
                                size: 22,
                              ),
                            ),
                          ),
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
                      margin: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppSpacing.xs,
                      ),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.accent),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.build_circle, color: Colors.brown),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              RemoteConfigService.instance.maintenanceMessage,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.brown,
                                fontWeight: FontWeight.w600,
                              ),
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
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.md,
                              AppSpacing.md,
                              AppSpacing.xs + 2,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text(
                                  'Explore Categories',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 44,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.xs + 2,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 22),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          _selectedCategoryId != null ? 'Filtered Products' : 'Fresh Picks for You',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
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
                      // Modern skeleton grid loading
                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.xxl,
                        ),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.64,
                            crossAxisSpacing: AppSpacing.md,
                            mainAxisSpacing: AppSpacing.md,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => const ProductCardSkeleton(),
                            childCount: 4,
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                          child: ErrorStateView(
                            title: 'Unable to load products',
                            message: '${snapshot.error}',
                            onRetry: () => setState(() {}),
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
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                          child: EmptyStateView(
                            icon: Icons.inventory_2_outlined,
                            title: 'No products found',
                            message: 'Try selecting another category or check back soon.',
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        80, // Space for bottom floating cart
                      ),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.64,
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
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

            // Quick-Commerce Floating Cart Bar
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FloatingCartBar(),
            ),
          ],
        ),
      ),
    );
  }
}
