import 'package:flutter/material.dart';
import 'package:opem/core/admin_theme.dart';
import 'package:opem/models/category.dart';
import 'package:opem/models/product.dart';
import 'package:opem/screens/admin/admin_product_form_screen.dart';
import 'package:opem/services/category_service.dart';
import 'package:opem/services/product_service.dart';
import 'package:opem/utils/constants.dart';

class AdminProductsScreen extends StatefulWidget {
  final String? initialFilter;

  const AdminProductsScreen({super.key, this.initialFilter});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  String _searchQuery = '';
  String _activeFilter = 'all'; // all, active, inactive, low_stock, out_of_stock
  String? _selectedCategoryId;
  String _sortBy = 'default'; // default, name, price_asc, price_desc, stock_asc
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _activeFilter = widget.initialFilter!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AdminColors.danger),
            SizedBox(width: 8),
            Text('Delete Product'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${product.name}"?\n\nThis action cannot be undone. To temporarily hide it from the store instead, use the Active toggle.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await productService.deleteProduct(
                id: product.id,
                imageUrl: product.imageUrl,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted "${product.name}"'),
                    backgroundColor: AdminColors.danger,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Catalog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Product',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminProductFormScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Search & Sort Bar ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search products by name...',
                      prefixIcon: const Icon(Icons.search, color: AdminColors.textSecondary, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AdminColors.cardBorder),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort, color: AdminColors.primary),
                  tooltip: 'Sort by',
                  onSelected: (val) => setState(() => _sortBy = val),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'default', child: Text('Default (Newest)')),
                    const PopupMenuItem(value: 'name', child: Text('Name (A–Z)')),
                    const PopupMenuItem(value: 'price_asc', child: Text('Price: Low to High')),
                    const PopupMenuItem(value: 'price_desc', child: Text('Price: High to Low')),
                    const PopupMenuItem(value: 'stock_asc', child: Text('Stock: Lowest First')),
                  ],
                ),
              ],
            ),
          ),

          // ─── Filter Chips Row ─────────────────────────────────────────────
          StreamBuilder<List<Category>>(
            stream: categoryService.watchAllCategories(),
            builder: (context, catSnap) {
              final categories = catSnap.data ?? [];

              return Container(
                height: 48,
                color: Colors.white,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: _activeFilter == 'all' && _selectedCategoryId == null,
                      onTap: () => setState(() {
                        _activeFilter = 'all';
                        _selectedCategoryId = null;
                      }),
                    ),
                    _FilterChip(
                      label: 'Active',
                      isSelected: _activeFilter == 'active',
                      onTap: () => setState(() => _activeFilter = _activeFilter == 'active' ? 'all' : 'active'),
                    ),
                    _FilterChip(
                      label: 'Inactive',
                      isSelected: _activeFilter == 'inactive',
                      onTap: () => setState(() => _activeFilter = _activeFilter == 'inactive' ? 'all' : 'inactive'),
                    ),
                    _FilterChip(
                      label: 'Low Stock (≤$kLowStockThreshold)',
                      isSelected: _activeFilter == 'low_stock',
                      onTap: () => setState(() => _activeFilter = _activeFilter == 'low_stock' ? 'all' : 'low_stock'),
                    ),
                    _FilterChip(
                      label: 'Out of Stock',
                      isSelected: _activeFilter == 'out_of_stock',
                      onTap: () => setState(() => _activeFilter = _activeFilter == 'out_of_stock' ? 'all' : 'out_of_stock'),
                    ),
                    const VerticalDivider(width: 16, indent: 4, endIndent: 4),
                    ...categories.map((c) => _FilterChip(
                          label: c.name,
                          isSelected: _selectedCategoryId == c.id,
                          onTap: () => setState(() {
                            _selectedCategoryId = _selectedCategoryId == c.id ? null : c.id;
                          }),
                        )),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1, color: AdminColors.cardBorder),

          // ─── Products List ────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: productService.watchAllAdminProducts(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AdminColors.primary));
                }

                var list = snap.data ?? [];

                // Filter by search query
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  list = list.where((p) => p.name.toLowerCase().contains(q) || p.description.toLowerCase().contains(q)).toList();
                }

                // Filter by status
                if (_activeFilter == 'active') {
                  list = list.where((p) => p.isActive).toList();
                } else if (_activeFilter == 'inactive') {
                  list = list.where((p) => !p.isActive).toList();
                } else if (_activeFilter == 'low_stock') {
                  list = list.where((p) => p.stockQuantity <= kLowStockThreshold).toList();
                } else if (_activeFilter == 'out_of_stock') {
                  list = list.where((p) => p.stockQuantity == 0).toList();
                }

                // Filter by category
                if (_selectedCategoryId != null) {
                  list = list.where((p) => p.categoryId == _selectedCategoryId).toList();
                }

                // Sorting
                if (_sortBy == 'name') {
                  list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                } else if (_sortBy == 'price_asc') {
                  list.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
                } else if (_sortBy == 'price_desc') {
                  list.sort((a, b) => b.effectivePrice.compareTo(a.effectivePrice));
                } else if (_sortBy == 'stock_asc') {
                  list.sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));
                }

                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 56, color: AdminColors.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text(
                            'No products found',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try adjusting your search query or filters',
                            style: TextStyle(fontSize: 13, color: AdminColors.textSecondary),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AdminProductFormScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add New Product'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminColors.primary,
                              minimumSize: const Size(180, 44),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final product = list[index];
                    return _AdminProductCard(
                      product: product,
                      onDelete: () => _confirmDelete(context, product),
                      onEdit: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminProductFormScreen(product: product),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin_products_fab',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AdminProductFormScreen(),
            ),
          );
        },
        backgroundColor: AdminColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: AdminColors.primary,
        backgroundColor: AdminColors.background,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AdminColors.textPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AdminColors.primary : AdminColors.cardBorder,
          ),
        ),
      ),
    );
  }
}

class _AdminProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdminProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.hasDiscount;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Thumbnail
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AdminColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminColors.cardBorder),
                  ),
                  child: product.imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            product.imageUrl,
                            fit: BoxFit.cover,
                            cacheWidth: 200,
                            cacheHeight: 200,
                            errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, color: AdminColors.textMuted),
                          ),
                        )
                      : const Icon(Icons.shopping_bag_outlined, color: AdminColors.textMuted),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AdminColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18, color: AdminColors.textSecondary),
                            padding: EdgeInsets.zero,
                            onSelected: (val) {
                              if (val == 'edit') onEdit();
                              if (val == 'delete') onDelete();
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit Details')),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete Product', style: TextStyle(color: AdminColors.danger)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Unit: ${product.unit}',
                        style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                      ),
                      const SizedBox(height: 6),

                      // Price & Sale Price
                      Row(
                        children: [
                          Text(
                            '₹${product.effectivePrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AdminColors.textPrimary,
                            ),
                          ),
                          if (hasDiscount) ...[
                            const SizedBox(width: 6),
                            Text(
                              '₹${product.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                                color: AdminColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AdminColors.dangerLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'SALE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AdminColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AdminColors.divider),
            const SizedBox(height: 8),

            // ─── Stock Controls & Active Toggle ─────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Stock Badge + Inline Stepper
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: product.stockQuantity == 0
                            ? AdminColors.dangerLight
                            : (product.stockQuantity <= kLowStockThreshold
                                ? AdminColors.warningLight
                                : AdminColors.successLight),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product.stockQuantity == 0
                            ? 'OUT OF STOCK'
                            : (product.stockQuantity <= kLowStockThreshold
                                ? 'LOW STOCK (${product.stockQuantity})'
                                : 'STOCK: ${product.stockQuantity}'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: product.stockQuantity == 0
                              ? AdminColors.danger
                              : (product.stockQuantity <= kLowStockThreshold
                                  ? AdminColors.warning
                                  : AdminColors.success),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Decrement Stock
                    InkWell(
                      onTap: product.stockQuantity > 0
                          ? () => productService.updateStock(product.id, product.stockQuantity - 1)
                          : null,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border.all(color: AdminColors.cardBorder),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.remove, size: 14, color: AdminColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Increment Stock
                    InkWell(
                      onTap: () => productService.updateStock(product.id, product.stockQuantity + 5),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border.all(color: AdminColors.cardBorder),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '+5',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminColors.accent),
                        ),
                      ),
                    ),
                  ],
                ),

                // Active / Inactive Switch
                Row(
                  children: [
                    Text(
                      product.isActive ? 'Active' : 'Hidden',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: product.isActive ? AdminColors.accent : AdminColors.danger,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Switch(
                      value: product.isActive,
                      activeThumbColor: AdminColors.accent,
                      onChanged: (val) async {
                        await productService.toggleProductStatus(product.id, val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
