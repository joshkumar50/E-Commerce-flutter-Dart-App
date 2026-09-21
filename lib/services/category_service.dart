import 'package:opem/demo/demo_data.dart';
import 'package:opem/models/category.dart';
import 'package:opem/services/cache_service.dart';
import 'package:opem/utils/constants.dart';
import 'package:opem/utils/observability.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryService {
  /// Realtime stream of active grocery categories ordered by sortOrder (Customer App)
  Stream<List<Category>> watchActiveCategories() {
    if (isDemoMode) {
      return DemoDataService.watchActiveCategories();
    }

    return Supabase.instance.client
        .from(tableCategories)
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('sort_order', ascending: true)
        .map((list) => list.map((e) => Category.fromJson(e)).toList());
  }

  /// Realtime stream of all categories (active + inactive) for Admin App
  Stream<List<Category>> watchAllCategories() {
    if (isDemoMode) {
      return DemoDataService.watchAllCategories();
    }

    return Supabase.instance.client
        .from(tableCategories)
        .stream(primaryKey: ['id'])
        .order('sort_order', ascending: true)
        .map((list) => list.map((e) => Category.fromJson(e)).toList());
  }

  /// Fetch list of categories with in-memory caching (TTL 15m)
  Future<List<Category>> fetchCategories({bool activeOnly = true, bool forceRefresh = false}) async {
    final cacheKey = 'categories:active_$activeOnly';
    if (!forceRefresh) {
      final cached = cacheService.get<List<Category>>(cacheKey);
      if (cached != null) return cached;
    }

    if (isDemoMode) {
      final list = activeOnly
          ? DemoDataService.categories.where((c) => c.isActive).toList()
          : DemoDataService.categories;
      cacheService.set(cacheKey, list, ttl: const Duration(minutes: 15));
      return list;
    }

    return AppObservability.measure(
      operation: 'fetch_categories',
      metadata: {'active_only': activeOnly},
      action: (reqId) async {
        var query = Supabase.instance.client
            .from(tableCategories)
            .select('id, name, icon, sort_order, is_active, created_at');

        if (activeOnly) {
          query = query.eq('is_active', true);
        }

        final data = await query.order('sort_order', ascending: true);
        final list = (data as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
        cacheService.set(cacheKey, list, ttl: const Duration(minutes: 15));
        return list;
      },
    );
  }

  // ─── Admin Methods (with Reactive Cache Invalidation) ──────────────────────

  /// Admin: Create a new grocery category
  Future<Category> createCategory(Category category) async {
    if (isDemoMode) {
      DemoDataService.addDemoCategory(category);
      cacheService.invalidatePrefix('categories:');
      return category;
    }

    return AppObservability.measure(
      operation: 'admin_create_category',
      metadata: {'name': category.name},
      action: (reqId) async {
        final data = await Supabase.instance.client
            .from(tableCategories)
            .insert(category.toJson())
            .select()
            .single();

        cacheService.invalidatePrefix('categories:');
        return Category.fromJson(data);
      },
    );
  }

  /// Admin: Update an existing category
  Future<void> updateCategory(String id, Map<String, dynamic> updates) async {
    if (isDemoMode) {
      DemoDataService.updateDemoCategory(id, updates);
      cacheService.invalidatePrefix('categories:');
      return;
    }

    await AppObservability.measure(
      operation: 'admin_update_category',
      metadata: {'id': id},
      action: (reqId) async {
        await Supabase.instance.client
            .from(tableCategories)
            .update(updates)
            .eq('id', id);

        cacheService.invalidatePrefix('categories:');
      },
    );
  }

  /// Admin: Toggle active status
  Future<void> toggleCategoryStatus(String id, bool isActive) async {
    await updateCategory(id, {'is_active': isActive});
  }

  /// Admin: Delete a category
  Future<void> deleteCategory(String id) async {
    if (isDemoMode) {
      DemoDataService.deleteDemoCategory(id);
      cacheService.invalidatePrefix('categories:');
      return;
    }

    await AppObservability.measure(
      operation: 'admin_delete_category',
      metadata: {'id': id},
      action: (reqId) async {
        await Supabase.instance.client
            .from(tableCategories)
            .delete()
            .eq('id', id);

        cacheService.invalidatePrefix('categories:');
      },
    );
  }
}

final categoryService = CategoryService();
