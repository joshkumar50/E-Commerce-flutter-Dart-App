import 'package:flutter/foundation.dart';
import 'package:opem/models/cart_item.dart';
import 'package:opem/services/auth_service.dart';
import 'package:opem/services/cart_service.dart';

class CartProvider extends ChangeNotifier {
  List<CartItem> _items = [];
  bool _isLoading = false;

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isEmpty => _items.isEmpty;

  /// Total count of individual units in cart
  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);

  /// Convenience alias for totalQuantity
  int get itemCount => totalQuantity;

  /// Count of unique distinct products in cart
  int get uniqueItemCount => _items.length;

  /// Total price of all items in cart
  double get totalAmount => _items.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Convenience alias for totalAmount
  double get totalPrice => totalAmount;

  CartProvider() {
    loadCart();
  }

  /// Load cart items for current user
  Future<void> loadCart() async {
    final userId = authService.currentUserId;
    if (userId == null) {
      _items = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _items = await cartService.fetchCart(userId);
    } catch (_) {
      _items = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a product to the cart
  Future<void> addToCart(int productId, {int quantity = 1}) async {
    final userId = authService.currentUserId;
    if (userId == null) return;

    await cartService.addToCart(
      userId: userId,
      productId: productId,
      quantity: quantity,
    );

    await loadCart();
  }

  /// Update quantity of an item in cart
  Future<void> updateQuantity(String cartItemId, int quantity) async {
    await cartService.updateQuantity(
      cartItemId: cartItemId,
      quantity: quantity,
    );

    await loadCart();
  }

  /// Remove item from cart
  Future<void> removeItem(String cartItemId) async {
    await cartService.removeFromCart(cartItemId);
    _items.removeWhere((item) => item.id == cartItemId);
    notifyListeners();
  }

  /// Clear entire cart
  Future<void> clearCart() async {
    final userId = authService.currentUserId;
    if (userId == null) return;

    await cartService.clearCart(userId);
    _items.clear();
    notifyListeners();
  }
}
