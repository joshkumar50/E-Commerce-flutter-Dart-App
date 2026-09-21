import 'dart:typed_data';
import 'package:opem/utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  /// Upload an image to Supabase Storage organized by product folder:
  /// `products/<productId>/<timestamp>_<fileName>`
  Future<String> uploadProductImage({
    required int productId,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    if (isDemoMode) {
      return 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=640&q=80';
    }

    final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = 'products/$productId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';

    await Supabase.instance.client.storage
        .from(bucketProductImages)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    return Supabase.instance.client.storage
        .from(bucketProductImages)
        .getPublicUrl(path);
  }

  /// Remove an image from Supabase Storage by its full public URL or relative path
  Future<void> deleteImage(String imageUrlOrPath) async {
    if (isDemoMode || imageUrlOrPath.isEmpty) return;

    try {
      String path = imageUrlOrPath;
      if (imageUrlOrPath.startsWith('http')) {
        // Extract relative path from public URL
        final marker = '/$bucketProductImages/';
        final index = imageUrlOrPath.indexOf(marker);
        if (index != -1) {
          path = imageUrlOrPath.substring(index + marker.length);
        }
      }

      await Supabase.instance.client.storage
          .from(bucketProductImages)
          .remove([path]);
    } catch (_) {
      // Ignored if file doesn't exist
    }
  }
}

final storageService = StorageService();
