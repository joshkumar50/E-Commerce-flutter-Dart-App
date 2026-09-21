import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:opem/models/product.dart';
import 'package:opem/services/product_service.dart';
import 'package:opem/widgets/drawer.dart';

/// Shows all products listed by the current user (seller view).
class MyProductsScreen extends StatelessWidget {
  const MyProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Products owned by current user are fetched via ProductEditScreen's
    // stream in the admin Phase 4. For now, show all products belonging to user.
    return Scaffold(
      appBar: AppBar(title: const Text('My Products')),
      drawer: const GlobalDrawer(pageIndex: 2),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: productService.watchAllProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final products = (snapshot.data ?? [])
              .map((e) => Product.fromJson(e))
              .toList();

          if (products.isEmpty) {
            return const Center(child: Text('No products found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];
              return _MyProductTile(product: p);
            },
          );
        },
      ),
    );
  }
}

class _MyProductTile extends StatelessWidget {
  final Product product;
  const _MyProductTile({required this.product});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    EasyLoading.show(status: 'Deleting…');
    try {
      await productService.deleteProduct(id: product.id, pid: product.pid);
      EasyLoading.showSuccess('Deleted');
    } catch (e) {
      EasyLoading.showError('Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: product.image.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(product.image,
                    width: 56, height: 56, fit: BoxFit.cover),
              )
            : const Icon(Icons.image_not_supported),
        title: Text(product.title),
        subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _confirmDelete(context),
        ),
      ),
    );
  }
}
