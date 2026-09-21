import 'package:opem/demo/demo_data.dart';
import 'package:opem/models/cart_item.dart';
import 'package:opem/utils/constants.dart';
import 'package:opem/utils/observability.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartService {
  /// Fetch full cart with joined product data
  Future<List<CartItem>> fetchCart(String userId) async {
    if (isDemoMode) return DemoDataService.cartItems;

    return AppObservability.measure(
      operation: 'fetch_cart',
      metadata: {'user_id': userId},
      action: (reqId) async {
        final data = await Supabase.instance.client
            .from(tableCartItems)
            .select('id, user_id, product_id, quantity, created_at, products(id, name, description, price, unit, image_url, category_id, stock_quantity, is_active)')
            .eq('user_id', userId)
            .order('created_at', ascending: true);

        return (data as List).map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList();
      },
    );
  }

  /// Add item to cart using single-roundtrip atomic upsert RPC
  Future<void> addToCart({
    required String userId,
    required int productId,
    int quantity = 1,
  }) async {
    if (isDemoMode) {
      DemoDataService.addDemoCartItem(productId, quantity);
      return;
    }

    await AppObservability.measure(
      operation: 'cart_atomic_upsert',
      metadata: {'product_id': productId, 'quantity': quantity},
      action: (reqId) async {
        try {
          // Fast Path: Single-trip atomic PostgreSQL RPC with ON CONFLICT DO UPDATE
          await Supabase.instance.client.rpc('rpc_upsert_cart_item', params: {
            'p_product_id': productId,
            'p_quantity': quantity,
          });
        } catch (e) {
          AppObservability.warn(
            'Atomic cart upsert RPC failed, falling back to client-side upsert',
            operation: 'cart_atomic_upsert',
            error: e,
          );
          // Resilient Fallback
          final existing = await Supabase.instance.client
              .from(tableCartItems)
              .select('id, quantity')
              .eq('user_id', userId)
              .eq('product_id', productId)
              .maybeSingle();

          if (existing != null) {
            final currentQty = (existing['quantity'] as num).toInt();
            await updateQuantity(
              cartItemId: existing['id'] as String,
              quantity: currentQty + quantity,
            );
          } else {
            await Supabase.instance.client.from(tableCartItems).insert({
              'user_id': userId,
              'product_id': productId,
              'quantity': quantity,
            });
          }
        }
      },
    );
  }

  /// Update quantity of an item in cart
  Future<void> updateQuantity({
    required String cartItemId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      await removeFromCart(cartItemId);
      return;
    }

    if (isDemoMode) {
      DemoDataService.updateDemoCartQuantity(cartItemId, quantity);
      return;
    }

    await AppObservability.measure(
      operation: 'cart_update_quantity',
      metadata: {'cart_item_id': cartItemId, 'quantity': quantity},
      action: (reqId) async {
        await Supabase.instance.client
            .from(tableCartItems)
            .update({'quantity': quantity, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', cartItemId);
      },
    );
  }

  /// Remove single item from cart
  Future<void> removeFromCart(String cartItemId) async {
    if (isDemoMode) {
      DemoDataService.removeDemoCartItem(cartItemId);
      return;
    }

    await AppObservability.measure(
      operation: 'cart_remove_item',
      metadata: {'cart_item_id': cartItemId},
      action: (reqId) async {
        await Supabase.instance.client
            .from(tableCartItems)
            .delete()
            .eq('id', cartItemId);
      },
    );
  }

  /// Clear entire cart for a user
  Future<void> clearCart(String userId) async {
    if (isDemoMode) {
      DemoDataService.cartItems.clear();
      return;
    }

    await AppObservability.measure(
      operation: 'cart_clear',
      metadata: {'user_id': userId},
      action: (reqId) async {
        await Supabase.instance.client
            .from(tableCartItems)
            .delete()
            .eq('user_id', userId);
      },
    );
  }
}

final cartService = CartService();
