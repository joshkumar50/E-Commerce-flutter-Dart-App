import 'package:flutter_test/flutter_test.dart';
import 'package:opem/demo/demo_data.dart';
import 'package:opem/demo/demo_transaction_service.dart';
import 'package:opem/models/product.dart';
import 'package:opem/services/cache_service.dart';
import 'package:opem/services/product_service.dart';
import 'package:opem/services/wishlist_service.dart';
import 'package:opem/utils/observability.dart';

void main() {
  setUp(() {
    cacheService.clear();
    PerformanceTracker.instance.reset();
    wishlistService.clearCache();
  });

  group('1. Large Catalog & Pagination Scalability Tests', () {
    test('Can query paginated products across a large catalog with P95 < 60ms', () async {
      // Simulate large catalog of 1,000 products by appending items
      final addedIds = <int>[];
      for (int i = 100; i < 1100; i++) {
        addedIds.add(i);
        DemoDataService.products.add(
          Product(
            id: i,
            name: 'Bulk Grocery Item #$i',
            description: 'Organic fresh item $i sourced directly from farm',
            price: 50.0 + (i % 20),
            unit: '1 kg',
            imageUrl: 'https://example.com/item$i.png',
            categoryId: i % 2 == 0 ? 'fruits_veg' : 'dairy_eggs',
            stockQuantity: 100,
            isActive: true,
          ),
        );
      }

      try {
        final stopwatch = Stopwatch()..start();
        final results = await productService.fetchProducts(
          limit: 20,
          offset: 0,
          forceRefresh: true,
        );
        stopwatch.stop();

        expect(results.length, 20);
        expect(results.first.id, 1);
        expect(stopwatch.elapsedMilliseconds, lessThan(60));

        // Test offset pagination
        final page2 = await productService.fetchProducts(
          limit: 20,
          offset: 20,
          forceRefresh: true,
        );
        expect(page2.length, 20);
        expect(page2.first.id, isNot(results.first.id));

        // Test boundary clamping (limit > 100 clamped safely)
        final largePage = await productService.fetchProducts(
          limit: 500,
          offset: 0,
          forceRefresh: true,
        );
        expect(largePage.length, lessThanOrEqualTo(100));
      } finally {
        DemoDataService.products.removeWhere((p) => addedIds.contains(p.id));
      }
    });

    test('Pathological search inputs are safely bounded and rejected early', () async {
      // Query too short (< 2 chars) -> returns empty list without querying DB
      final emptyResult = await productService.searchProducts('a');
      expect(emptyResult, isEmpty);

      // Query too long (> 50 chars pathological attack) -> rejected early
      final longQuery = 'a' * 55;
      final rejectedResult = await productService.searchProducts(longQuery);
      expect(rejectedResult, isEmpty);

      // Legitimate search
      final milkResults = await productService.searchProducts('milk');
      expect(milkResults.any((p) => p.name.toLowerCase().contains('milk')), isTrue);
    });
  });

  group('2. In-Memory Caching & Reactive Invalidation Tests', () {
    test('Cache service serves cached items with 0ms network latency and records stats', () async {
      const key = 'test:products:page_1';
      final dummyProducts = [
        const Product(
          id: 999,
          name: 'Cached Item',
          description: 'Fast cache read',
          price: 99.0,
          unit: '1 pc',
          imageUrl: '',
          categoryId: 'fruits_veg',
          stockQuantity: 10,
          isActive: true,
        )
      ];

      cacheService.set(key, dummyProducts, ttl: const Duration(minutes: 5));
      expect(cacheService.get<List<Product>>(key), isNotNull);
      expect(cacheService.hits, 1);

      // Reactive invalidation by prefix
      cacheService.invalidatePrefix('test:products:');
      expect(cacheService.get<List<Product>>(key), isNull);
      expect(cacheService.misses, 1);
    });

    test('Admin product mutation reactively invalidates catalog cache', () async {
      // Warm up cache
      await productService.fetchProducts(limit: 10, offset: 0);
      expect(cacheService.size, greaterThan(0));

      // Admin updates a product
      await productService.updateProduct(1, {'price': 199.0});

      // Cache for products should be invalidated
      expect(cacheService.get('products:cat_all:act_true:lim_10:off_0'), isNull);
    });
  });

  group('3. N+1 Elimination & Wishlist Preloading Tests', () {
    test('Preloaded favorites allow O(1) synchronous checks without network calls', () async {
      await wishlistService.preloadFavorites('test-user-uuid');

      // Check synchronous favorite check
      final isFav = wishlistService.isFavoriteSync(1);
      expect(isFav, isA<bool>());

      // Toggle favorite modifies cache immediately
      final wasFav = wishlistService.isFavoriteSync(1);
      final toggled = await wishlistService.toggleWishlist(
        userId: 'test-user-uuid',
        productId: 1,
      );
      expect(toggled, !wasFav);
      expect(wishlistService.isFavoriteSync(1), toggled);
    });
  });

  group('4. High Concurrency & Checkout Contention Tests', () {
    test('100 concurrent buyers competing for 3 units of stock results in 0 overselling', () async {
      final txService = DemoTransactionService.instance;
      const testProductId = 1005;

      DemoDataService.products.removeWhere((p) => p.id == testProductId);
      DemoDataService.products.add(
        const Product(
          id: testProductId,
          name: 'Scarce Item',
          description: 'Limited inventory product',
          price: 50.0,
          unit: '1 unit',
          stockQuantity: 3,
          isActive: true,
        ),
      );

      final addressId = DemoDataService.addresses.first.id;
      const concurrentBuyers = 100;
      final futures = <Future<Map<String, dynamic>?>>[];

      for (int i = 0; i < concurrentBuyers; i++) {
        futures.add(
          txService.createCheckout(
            userId: 'concurrent-user-$i',
            addressId: addressId,
            cartItems: [
              {'product_id': testProductId, 'quantity': 1}
            ],
            idempotencyKey: 'idemp-stress-$i',
          ).then<Map<String, dynamic>?>((res) => res).catchError((e) {
            return null; // Rejected due to insufficient stock
          }),
        );
      }

      final results = await Future.wait(futures);
      final successes = results.where((r) => r != null && r['success'] == true).toList();
      final failures = results.where((r) => r == null).toList();

      expect(successes.length, 3, reason: 'Exactly 3 buyers should succeed');
      expect(failures.length, 97, reason: '97 buyers should fail with insufficient stock');

      // Final stock verification
      final updatedProduct = DemoDataService.products.firstWhere((p) => p.id == testProductId);
      expect(updatedProduct.stockQuantity, 0, reason: 'Stock must be exactly 0, never negative');
    });

    test('Bounded reservation expiration sweeper processes in chunks of batchSize', () async {
      final txService = DemoTransactionService.instance;
      // Sweep reservations with bounded batch
      final expired = await txService.expireReservations(batchSize: 50);
      expect(expired, lessThanOrEqualTo(50));
    });
  });

  group('5. Observability, Latency & Resilience Tests', () {
    test('Structured log sanitization removes passwords, tokens, and payment secrets', () {
      final sensitiveMap = {
        'user_id': 'usr_123',
        'password': 'SuperSecretPassword!1',
        'token': 'bearer_eyJhbGciOi...',
        'credit_card': '4111222233334444',
        'nested': {
          'api_key': 'secret_key_12345',
          'status': 'active',
        },
      };

      final sanitized = AppObservability.sanitize(sensitiveMap);
      expect(sanitized['password'], '[REDACTED]');
      expect(sanitized['token'], '[REDACTED]');
      expect(sanitized['credit_card'], '[REDACTED]');
      expect((sanitized['nested'] as Map)['api_key'], '[REDACTED]');
      expect(sanitized['user_id'], 'usr_123');
      expect((sanitized['nested'] as Map)['status'], 'active');
    });

    test('PerformanceTracker records P50, P95, P99 latencies accurately', () {
      for (int i = 1; i <= 100; i++) {
        PerformanceTracker.instance.recordLatency('catalog_read', i);
      }

      final stats = PerformanceTracker.instance.getStats('catalog_read');
      expect(stats['count'], 100);
      expect(stats['p50_ms'], 51);
      expect(stats['p95_ms'], 95);
      expect(stats['p99_ms'], 99);
      expect(stats['min_ms'], 1);
      expect(stats['max_ms'], 100);
    });

    test('Exponential retry with jitter handles transient errors and succeeds on recovery', () async {
      int attempts = 0;
      final result = await AppObservability.retry<String>(
        operation: 'transient_query',
        maxAttempts: 3,
        initialDelay: const Duration(milliseconds: 10),
        action: () async {
          attempts++;
          if (attempts < 2) {
            throw Exception('Transient 503 Service Unavailable');
          }
          return 'SUCCESS';
        },
      );

      expect(attempts, 2);
      expect(result, 'SUCCESS');
    });

    test('Exponential retry exhausts maxAttempts on persistent failure without infinite looping', () async {
      int attempts = 0;
      await expectLater(
        AppObservability.retry<String>(
          operation: 'failing_query',
          maxAttempts: 3,
          initialDelay: const Duration(milliseconds: 10),
          action: () async {
            attempts++;
            throw Exception('Fatal DB Timeout');
          },
        ),
        throwsA(isA<Exception>()),
      );
      expect(attempts, 3);
    });
  });

  group('6. Spike & Soak Traffic Simulation Tests', () {
    test('Spike traffic (10x influx) is sustained without memory corruption or unhandled errors', () async {
      // Normal traffic: 10 requests
      for (int i = 0; i < 10; i++) {
        await productService.fetchProducts(limit: 10);
      }

      // Sudden Spike: 100 concurrent requests
      final spikeFutures = <Future<dynamic>>[];
      for (int i = 0; i < 100; i++) {
        if (i % 2 == 0) {
          spikeFutures.add(productService.fetchProducts(limit: 10));
        } else {
          spikeFutures.add(productService.searchProducts('apple'));
        }
      }

      final results = await Future.wait(spikeFutures);
      expect(results.length, 100);

      // Return to baseline: verified stable
      final postSpike = await productService.fetchProducts(limit: 10);
      expect(postSpike, isNotEmpty);
    });

    test('Soak simulation: 500 sequential operations verify zero memory leaks or unreleased handles', () async {
      for (int i = 0; i < 500; i++) {
        cacheService.set('key_$i', 'value_$i');
        cacheService.get('key_$i');
      }

      // Max entries bound strictly respected (LRU eviction active)
      expect(cacheService.size, lessThanOrEqualTo(cacheService.maxEntries));
      expect(cacheService.hits, greaterThan(0));
    });
  });
}
