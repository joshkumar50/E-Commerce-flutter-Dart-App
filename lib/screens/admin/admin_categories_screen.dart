import 'package:flutter/material.dart';
import 'package:opem/core/admin_theme.dart';
import 'package:opem/models/category.dart';
import 'package:opem/models/product.dart';
import 'package:opem/screens/admin/admin_category_form_screen.dart';
import 'package:opem/services/category_service.dart';
import 'package:opem/services/product_service.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDelete(BuildContext context, Category category, int productCount) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AdminColors.danger),
            SizedBox(width: 8),
            Text('Delete Category'),
          ],
        ),
        content: Text(
          productCount > 0
              ? 'Warning: "${category.name}" has $productCount products assigned to it.\n\nDeleting this category will set those products to unassigned. Are you sure?'
              : 'Are you sure you want to delete category "${category.name}"? This action cannot be undone.',
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
              await categoryService.deleteCategory(category.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted category "${category.name}"'),
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
        title: const Text('Category Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Category',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminCategoryFormScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Search Bar ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search categories...',
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
              ),
            ),
          ),
          const Divider(height: 1, color: AdminColors.cardBorder),

          // ─── Categories List ────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Category>>(
              stream: categoryService.watchAllCategories(),
              builder: (context, catSnap) {
                if (catSnap.connectionState == ConnectionState.waiting && !catSnap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AdminColors.primary));
                }

                return StreamBuilder<List<Product>>(
                  stream: productService.watchAllAdminProducts(),
                  builder: (context, prodSnap) {
                    final products = prodSnap.data ?? [];
                    var categories = catSnap.data ?? [];

                    if (_searchQuery.isNotEmpty) {
                      categories = categories
                          .where((c) =>
                              c.name.toLowerCase().contains(_searchQuery) ||
                              c.description.toLowerCase().contains(_searchQuery))
                          .toList();
                    }

                    if (categories.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.category_outlined, size: 56, color: AdminColors.textMuted.withValues(alpha: 0.5)),
                              const SizedBox(height: 16),
                              const Text(
                                'No categories found',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminColors.textPrimary),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const AdminCategoryFormScreen()),
                                  );
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add New Category'),
                                style: ElevatedButton.styleFrom(backgroundColor: AdminColors.primary),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final prodCount = products.where((p) => p.categoryId == cat.id).length;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Thumbnail
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: AdminColors.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AdminColors.cardBorder),
                                  ),
                                  child: cat.imageUrl.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.network(
                                            cat.imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.category_outlined, color: AdminColors.textMuted),
                                          ),
                                        )
                                      : const Icon(Icons.category_outlined, color: AdminColors.textMuted),
                                ),
                                const SizedBox(width: 14),

                                // Information
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              cat.name,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: AdminColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AdminColors.infoLight,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Order: ${cat.sortOrder}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AdminColors.info,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        cat.description.isNotEmpty
                                            ? cat.description
                                            : '$prodCount items assigned',
                                        style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$prodCount products in store',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AdminColors.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Actions: Toggle & Popup
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: cat.isActive,
                                      activeThumbColor: AdminColors.accent,
                                      onChanged: (val) async {
                                        await categoryService.toggleCategoryStatus(cat.id, val);
                                      },
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, color: AdminColors.textSecondary, size: 20),
                                      padding: EdgeInsets.zero,
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => AdminCategoryFormScreen(category: cat),
                                            ),
                                          );
                                        }
                                        if (val == 'delete') {
                                          _confirmDelete(context, cat, prodCount);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(value: 'edit', child: Text('Edit Category')),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete Category', style: TextStyle(color: AdminColors.danger)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
        heroTag: 'admin_categories_fab',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdminCategoryFormScreen()),
          );
        },
        backgroundColor: AdminColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
