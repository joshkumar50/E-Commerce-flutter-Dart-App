import 'dart:typed_data';
import 'package:opem/demo/demo_data.dart';
import 'package:opem/models/product.dart';
import 'package:opem/services/audit_service.dart';
import 'package:opem/services/cache_service.dart';
import 'package:opem/services/storage_service.dart';
import 'package:opem/utils/constants.dart';
import 'package:opem/utils/observability.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductService {
  // ─── Customer Streams & Reads ──────────────────────────────────────────────

  /// Realtime stream of active grocery products (used by Customer App)
  Stream<List<Product>> watchActiveProducts() {
    if (isDemoMode) {
      return DemoDataService.watchActiveProducts();
    }

    return Supabase.instance.client
        .from(tableProducts)
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('id')
        .map((list) => list.map((e) => Product.fromJson(e)).toList());
  }

  /// Realtime stream of all products (active + inactive) for Admin App
  Stream<List<Product>> watchAllAdminProducts() {
    if (isDemoMode) {
      return DemoDataService.watchAllAdminProducts();
    }

    return Supabase.instance.client
        .from(tableProducts)
        .stream(primaryKey: ['id'])
        .order('id', ascending: false)
        .map((list) => list.map((e) => Product.fromJson(e)).toList());
  }

  /// Legacy stream for existing UI widgets expecting Map lists
  Stream<List<Map<String, dynamic>>> watchAllProducts() {
    if (isDemoMode) return DemoDataService.watchAllProducts();

    return Supabase.instance.client
        .from(tableProducts)
        .stream(primaryKey: ['id'])
        .order('id');
  }

  /// Legacy stream for backwards compatibility
  Stream<List<Map<String, dynamic>>> watchProductsByOwner(String userId) {
    if (isDemoMode) return DemoDataService.watchAllProducts();

    return Supabase.instance.client
        .from(tableProducts)
        .stream(primaryKey: ['id'])
        .order('id');
  }

  /// Paginated and cached catalog fetch with selective column projection
  Future<List<Product>> fetchProducts({
    String? categoryId,
    bool activeOnly = true,
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    final safeLimit = limit.clamp(1, 100);
    final safeOffset = offset < 0 ? 0 : offset;
    final cacheKey = 'products:cat_${categoryId ?? 'all'}:act_$activeOnly:lim_$safeLimit:off_$safeOffset';

    if (!forceRefresh) {
      final cached = cacheService.get<List<Product>>(cacheKey);
      if (cached != null) return cached;
    }

    if (isDemoMode) {
      var list = DemoDataService.products;
      if (activeOnly) list = list.where((p) => p.isActive).toList();
      if (categoryId != null && categoryId.isNotEmpty) {
        list = list.where((p) => p.categoryId == categoryId).toList();
      }
      final safeEnd = (safeOffset + safeLimit).clamp(0, list.length);
      final paginated = safeOffset >= list.length ? <Product>[] : list.sublist(safeOffset, safeEnd);
      cacheService.set(cacheKey, paginated, ttl: const Duration(minutes: 5));
      return paginated;
    }

    return AppObservability.measure(
      operation: 'fetch_products_paginated',
      metadata: {
        'category_id': categoryId,
        'active_only': activeOnly,
        'limit': safeLimit,
        'offset': safeOffset,
      },
      action: (reqId) async {
        // Selective projection to reduce payload size over mobile network
        var query = Supabase.instance.client
            .from(tableProducts)
            .select('id, name, description, price, unit, image_url, category_id, stock_quantity, is_active, created_at, updated_at');

        if (activeOnly) {
          query = query.eq('is_active', true);
        }
        if (categoryId != null && categoryId.isNotEmpty) {
          query = query.eq('category_id', categoryId);
        }

        final data = await query
            .order('id', ascending: true)
            .range(safeOffset, safeOffset + safeLimit - 1);

        final items = (data as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
        cacheService.set(cacheKey, items, ttl: const Duration(minutes: 5));
        return items;
      },
    );
  }

  /// High-performance bounded search with trigram index acceleration
  Future<List<Product>> searchProducts(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    final cleanQuery = query.trim();
    // Pathological input limit & early reject to protect database
    if (cleanQuery.length < 2 || cleanQuery.length > 50) return [];

    final safeLimit = limit.clamp(1, 50);
    final safeOffset = offset < 0 ? 0 : offset;

    if (isDemoMode) {
      final q = cleanQuery.toLowerCase();
      final all = DemoDataService.products
          .where((p) =>
              p.isActive &&
              (p.name.toLowerCase().contains(q) ||
                  p.description.toLowerCase().contains(q)))
          .toList();
      final safeEnd = (safeOffset + safeLimit).clamp(0, all.length);
      if (safeOffset >= all.length) return [];
      return all.sublist(safeOffset, safeEnd);
    }

    return AppObservability.measure(
      operation: 'search_products',
      metadata: {'query': cleanQuery, 'limit': safeLimit, 'offset': safeOffset},
      action: (reqId) async {
        // Uses GIN trigram index on PostgreSQL (idx_products_name_trgm)
        final data = await Supabase.instance.client
            .from(tableProducts)
            .select('id, name, description, price, unit, image_url, category_id, stock_quantity, is_active')
            .eq('is_active', true)
            .ilike('name', '%$cleanQuery%')
            .order('id')
            .range(safeOffset, safeOffset + safeLimit - 1);

        return (data as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
      },
    );
  }

  /// Fetch single product by ID (authoritative read, non-cached for stock accuracy)
  Future<Product?> fetchProductById(int id) async {
    if (isDemoMode) {
      return DemoDataService.products.firstWhere(
        (p) => p.id == id,
        orElse: () => DemoDataService.products.first,
      );
    }

    return AppObservability.measure(
      operation: 'fetch_product_by_id',
      metadata: {'id': id},
      action: (reqId) async {
        final data = await Supabase.instance.client
            .from(tableProducts)
            .select('id, name, description, price, unit, image_url, category_id, stock_quantity, is_active, created_at, updated_at')
            .eq('id', id)
            .maybeSingle();

        if (data == null) return null;
        return Product.fromJson(data);
      },
    );
  }

  // ─── Admin Writes & Management (with Reactive Cache Invalidation) ──────────

  /// Admin: Create a new grocery product
  Future<Product> createProduct(Product product) async {
    if (isDemoMode) {
      DemoDataService.addDemoProduct(product);
      cacheService.invalidatePrefix('products:');
      return product;
    }

    return AppObservability.measure(
      operation: 'admin_create_product',
      metadata: {'name': product.name},
      action: (reqId) async {
        final data = await Supabase.instance.client
            .from(tableProducts)
            .insert(product.toJson())
            .select()
            .single();

        cacheService.invalidatePrefix('products:');
        
        // Log immutable admin audit
        AuditService.instance.logAction(
          action: 'create_product',
          entityType: 'product',
          entityId: data['id']?.toString() ?? 'unknown',
          newState: product.toJson(),
          reason: 'Created new product in catalog',
          requestId: reqId,
        ).catchError((_) {});

        return Product.fromJson(data);
      },
    );
  }

  /// Admin: Update an existing product with optional Optimistic Concurrency Control (OCC)
  Future<void> updateProduct(
    int id,
    Map<String, dynamic> updates, {
    int? expectedVersion,
  }) async {
    if (isDemoMode) {
      DemoDataService.updateDemoProduct(id, updates, expectedVersion: expectedVersion);
      cacheService.invalidatePrefix('products:');
      AuditService.instance.logAction(
        action: 'update_product',
        entityType: 'product',
        entityId: id.toString(),
        newState: updates,
        reason: 'Updated product fields in demo mode',
      ).catchError((_) {});
      return;
    }

    await AppObservability.measure(
      operation: 'admin_update_product',
      metadata: {'id': id, 'expected_version': expectedVersion},
      action: (reqId) async {
        if (expectedVersion != null) {
          final res = await Supabase.instance.client.rpc(
            'rpc_update_product_occ',
            params: {
              'p_product_id': id,
              'p_expected_version': expectedVersion,
              'p_updates': updates,
              'p_reason': 'Admin catalog update via app',
            },
          );

          if (res is Map) {
            final success = res['success'] == true;
            if (!success) {
              if (res['error'] == 'stale_version_conflict') {
                throw StaleVersionException(
                  message: res['message']?.toString() ??
                      'This product was modified by another administrator. Please refresh before saving.',
                  currentVersion: (res['current_version'] as num?)?.toInt() ?? 0,
                  expectedVersion: expectedVersion,
                );
              }
              throw Exception(res['message'] ?? 'Failed to update product');
            }
          }
        } else {
          await Supabase.instance.client
              .from(tableProducts)
              .update(updates)
              .eq('id', id);
        }

        cacheService.invalidatePrefix('products:');

        AuditService.instance.logAction(
          action: 'update_product',
          entityType: 'product',
          entityId: id.toString(),
          newState: updates,
          reason: 'Updated product catalog properties',
          requestId: reqId,
        ).catchError((_) {});
      },
    );
  }

  /// Admin: Update stock quantity
  Future<void> updateStock(int id, int stockQuantity) async {
    await updateProduct(id, {'stock_quantity': stockQuantity});
    AuditService.instance.logStockAdjustment(
      productId: id,
      productName: 'Product #$id',
      oldStock: 0,
      newStock: stockQuantity,
      reason: 'Admin updated stock quantity',
    ).catchError((_) {});
  }

  /// Admin: Toggle active/inactive status
  Future<void> toggleProductStatus(int id, bool isActive) async {
    await updateProduct(id, {'is_active': isActive});
    AuditService.instance.logAction(
      action: isActive ? 'activate_product' : 'deactivate_product',
      entityType: 'product',
      entityId: id.toString(),
      newState: {'is_active': isActive},
      reason: 'Admin toggled product active status',
      severity: isActive ? 'info' : 'warning',
    ).catchError((_) {});
  }

  /// Admin: Delete a product with safe non-blocking image cleanup
  Future<void> deleteProduct({required int id, String? imageUrl, String? pid}) async {
    if (isDemoMode) {
      DemoDataService.deleteDemoProduct(id);
      cacheService.invalidatePrefix('products:');
      AuditService.instance.logAction(
        action: 'delete_product',
        entityType: 'product',
        entityId: id.toString(),
        severity: 'warning',
        reason: 'Admin deleted product from catalog',
      ).catchError((_) {});
      return;
    }

    await AppObservability.measure(
      operation: 'admin_delete_product',
      metadata: {'id': id},
      action: (reqId) async {
        // 1. Delete product record from database
        await Supabase.instance.client.from(tableProducts).delete().eq('id', id);
        cacheService.invalidatePrefix('products:');

        // Audit log deletion
        AuditService.instance.logAction(
          action: 'delete_product',
          entityType: 'product',
          entityId: id.toString(),
          severity: 'warning',
          reason: 'Admin deleted product from catalog',
          requestId: reqId,
        ).catchError((_) {});

        // 2. Safe asynchronous/non-blocking storage cleanup so image latency doesn't fail the deletion
        if (imageUrl != null && imageUrl.isNotEmpty) {
          storageService.deleteImage(imageUrl).catchError((err) {
            AppObservability.warn('Non-blocking image cleanup failed', operation: 'storage_cleanup', error: err);
          });
        } else if (pid != null && pid.isNotEmpty) {
          storageService.deleteImage(pid).catchError((err) {
            AppObservability.warn('Non-blocking image cleanup failed', operation: 'storage_cleanup', error: err);
          });
        }
      },
    );
  }

  // ─── Legacy Wrappers ──────────────────────────────────────────────────────

  Future<void> addProduct(Product product) async {
    await createProduct(product);
  }

  Future<String> uploadImage({
    required String fileName,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    return storageService.uploadProductImage(
      productId: 0,
      fileName: fileName,
      bytes: bytes,
      contentType: contentType,
    );
  }
}

final productService = ProductService();
