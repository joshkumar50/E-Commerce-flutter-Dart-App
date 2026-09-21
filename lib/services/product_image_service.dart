import 'package:opem/models/product_image.dart';
import 'package:opem/utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductImageService {
  final Map<int, List<ProductImage>> _demoImages = {};

  /// Fetch all secondary images for a product ordered by sort_order
  Future<List<ProductImage>> fetchProductImages(int productId) async {
    if (isDemoMode) {
      return _demoImages[productId] ?? [];
    }

    final data = await Supabase.instance.client
        .from(tableProductImages)
        .select()
        .eq('product_id', productId)
        .order('sort_order', ascending: true);

    return (data as List).map((e) => ProductImage.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Add a secondary image to a product
  Future<ProductImage> addProductImage({
    required int productId,
    required String imageUrl,
    int sortOrder = 0,
  }) async {
    if (isDemoMode) {
      final img = ProductImage(
        id: 'img-${DateTime.now().millisecondsSinceEpoch}',
        productId: productId,
        imageUrl: imageUrl,
        sortOrder: sortOrder,
        createdAt: DateTime.now(),
      );
      _demoImages.putIfAbsent(productId, () => []).add(img);
      return img;
    }

    final data = await Supabase.instance.client
        .from(tableProductImages)
        .insert({
          'product_id': productId,
          'image_url': imageUrl,
          'sort_order': sortOrder,
        })
        .select()
        .single();

    return ProductImage.fromJson(data);
  }

  /// Remove a secondary product image
  Future<void> deleteProductImage(String id, {int? productId}) async {
    if (isDemoMode) {
      if (productId != null) {
        _demoImages[productId]?.removeWhere((img) => img.id == id);
      }
      return;
    }

    await Supabase.instance.client
        .from(tableProductImages)
        .delete()
        .eq('id', id);
  }
}

final productImageService = ProductImageService();
