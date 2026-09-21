import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:opem/core/router.dart';
import 'package:opem/core/theme.dart';
import 'package:opem/models/wishlist_item.dart';
import 'package:opem/services/auth_service.dart';
import 'package:opem/services/wishlist_service.dart';
import 'package:opem/widgets/product_card.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  late Future<List<WishlistItem>> _wishlistFuture;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  void _loadWishlist() {
    final uid = authService.currentUserId ?? 'demo-user-123';
    setState(() {
      _wishlistFuture = wishlistService.fetchWishlist(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Wishlist'),
      ),
      body: FutureBuilder<List<WishlistItem>>(
        future: _wishlistFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? [];
          final validProducts = items
              .where((item) => item.product != null)
              .map((item) => item.product!)
              .toList();

          if (validProducts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: AppColors.saleRedLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_border, size: 64, color: AppColors.saleRed),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Your wishlist is empty',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap the heart icon on any grocery item to save your favorites here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.go(Routes.home),
                      child: const Text('Explore Fresh Items'),
                    ),
                  ],
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.68,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: validProducts.length,
            itemBuilder: (context, index) => ProductCard(product: validProducts[index]),
          );
        },
      ),
    );
  }
}
