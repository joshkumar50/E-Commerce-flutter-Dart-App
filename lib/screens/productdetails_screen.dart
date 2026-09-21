import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:opem/models/product.dart';
import 'package:opem/provider/user_provider.dart';
import 'package:opem/services/order_service.dart';
import 'package:provider/provider.dart';

/// Displays the full details of a [Product] and allows the user to buy it.
class ProductDetailsScreen extends StatelessWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  Future<void> _handleBuy(BuildContext context) async {
    final userProvider = context.read<UserProvider>();
    if (userProvider.id == null) {
      EasyLoading.showError('Not signed in.');
      return;
    }

    EasyLoading.show(status: 'Placing order…');
    try {
      await orderService.placeOrder(
        productName: product.title,
        price: product.price,
        buyerId: userProvider.id!,
        sellerId: product.owner,
        imageUrl: product.image,
      );
      EasyLoading.showSuccess('Order placed!');
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      EasyLoading.showError('Failed to place order: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(product.title)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.image.isNotEmpty)
              CachedNetworkImage(
                imageUrl: product.image,
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const SizedBox(height: 260, child: Icon(Icons.broken_image)),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.title,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (product.city.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Location: ${product.city}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                  const SizedBox(height: 16),
                  Text(product.description,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: const Text('Buy Now'),
                      onPressed: () => _handleBuy(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
