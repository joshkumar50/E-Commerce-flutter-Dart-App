import 'package:opem/demo/demo_data.dart';
import 'package:opem/models/wishlist_item.dart';
import 'package:opem/utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WishlistService {
  final Set<int> _cachedFavoriteIds = {};
  bool _isInitialized = false;

  /// Fast synchronous check against preloaded in-memory favorites (0ms latency, no network call)
  bool isFavoriteSync(int productId) {
    if (isDemoMode) {
      return DemoDataService.wishlistProductIds.contains(productId);
    }
    return _cachedFavoriteIds.contains(productId);
  }

  /// Preload favorite product IDs for the customer in a single lightweight query
  Future<Set<int>> preloadFavorites(String userId) async {
    if (isDemoMode) {
      _cachedFavoriteIds.clear();
      _cachedFavoriteIds.addAll(DemoDataService.wishlistProductIds);
      _isInitialized = true;
      return _cachedFavoriteIds;
    }

    try {
      final data = await Supabase.instance.client
          .from(tableWishlistItems)
          .select('product_id')
          .eq('user_id', userId);

      _cachedFavoriteIds.clear();
      for (final row in data as List) {
        _cachedFavoriteIds.add((row['product_id'] as num).toInt());
      }
      _isInitialized = true;
    } catch (_) {
      // In case of error, leave cache as-is
    }
    return _cachedFavoriteIds;
  }

  /// Fetch all favorite products for a customer
  Future<List<WishlistItem>> fetchWishlist(String userId) async {
    if (isDemoMode) return DemoDataService.wishlistItems;

    final data = await Supabase.instance.client
        .from(tableWishlistItems)
        .select('*, products(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final items = (data as List).map((e) => WishlistItem.fromJson(e as Map<String, dynamic>)).toList();
    _cachedFavoriteIds.clear();
    for (final item in items) {
      _cachedFavoriteIds.add(item.productId);
    }
    _isInitialized = true;
    return items;
  }

  /// Check if a product is in customer's favorites (uses cache if available)
  Future<bool> isFavorite({
    required String userId,
    required int productId,
  }) async {
    if (isDemoMode) {
      return DemoDataService.wishlistProductIds.contains(productId);
    }

    if (_isInitialized) {
      return _cachedFavoriteIds.contains(productId);
    }

    final data = await Supabase.instance.client
        .from(tableWishlistItems)
        .select('id')
        .eq('user_id', userId)
        .eq('product_id', productId)
        .maybeSingle();

    final isFav = data != null;
    if (isFav) {
      _cachedFavoriteIds.add(productId);
    } else {
      _cachedFavoriteIds.remove(productId);
    }
    return isFav;
  }

  /// Toggle favorite status (adds if missing, removes if present)
  Future<bool> toggleWishlist({
    required String userId,
    required int productId,
  }) async {
    if (isDemoMode) {
      final res = DemoDataService.toggleDemoWishlist(productId);
      if (res) {
        _cachedFavoriteIds.add(productId);
      } else {
        _cachedFavoriteIds.remove(productId);
      }
      return res;
    }

    final currentlyFavorite = _isInitialized 
        ? _cachedFavoriteIds.contains(productId)
        : await isFavorite(userId: userId, productId: productId);

    if (currentlyFavorite) {
      _cachedFavoriteIds.remove(productId);
      await Supabase.instance.client
          .from(tableWishlistItems)
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);
      return false;
    } else {
      _cachedFavoriteIds.add(productId);
      await Supabase.instance.client.from(tableWishlistItems).insert({
        'user_id': userId,
        'product_id': productId,
      });
      return true;
    }
  }

  void clearCache() {
    _cachedFavoriteIds.clear();
    _isInitialized = false;
  }
}

final wishlistService = WishlistService();
