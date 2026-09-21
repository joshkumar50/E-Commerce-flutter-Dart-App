import 'package:flutter_test/flutter_test.dart';
import 'package:opem/demo/demo_data.dart';
import 'package:opem/demo/demo_transaction_service.dart';
import 'package:opem/models/category.dart';
import 'package:opem/models/order_v2.dart';
import 'package:opem/models/product.dart';

void main() {
  setUp(() {
    // Register temporary test product category if needed
    if (!DemoDataService.categories.any((c) => c.id == 'cat-test')) {
      DemoDataService.categories.add(
        const Category(
          id: 'cat-test',
          name: 'Test Category',
          sortOrder: 99,
          isActive: true,
        ),
      );
    }
  });

  group('Concurrency & Inventory Protection Tests (Section 33)', () {
    test('100 concurrent checkout attempts for 1 unit on stock = 10: exactly 10 succeed, 90 rejected, zero negative stock', () async {
      final service = DemoTransactionService.instance;
      const testProductId = 101;

      // Setup Product with stock = 10
      DemoDataService.products.removeWhere((p) => p.id == testProductId);
      DemoDataService.products.add(
        const Product(
          id: testProductId,
          name: 'Limited Avocado',
          price: 90.0,
          stockQuantity: 10,
          unit: '1 piece',
          isActive: true,
        ),
      );

      final addressId = DemoDataService.addresses.first.id;

      // Fire 100 concurrent checkout attempts
      final List<Future<Map<String, dynamic>?>> futures = [];
      for (int i = 0; i < 100; i++) {
        futures.add(
          service.createCheckout(
            userId: 'concurrent-user-$i',
            addressId: addressId,
            cartItems: [
              {'product_id': testProductId, 'quantity': 1},
            ],
          ).then<Map<String, dynamic>?>((res) => res).catchError((e) {
            return null; // Rejected due to insufficient stock
          }),
        );
      }

      final results = await Future.wait(futures);

      final successCount = results.where((r) => r != null && r['success'] == true).length;
      final rejectedCount = results.where((r) => r == null).length;

      expect(successCount, equals(10), reason: 'Exactly 10 purchases must succeed');
      expect(rejectedCount, equals(90), reason: 'Exactly 90 purchases must be rejected');

      // Verify product stock is exactly 0 and NEVER negative
      final finalProduct = DemoDataService.products.firstWhere((p) => p.id == testProductId);
      expect(finalProduct.stockQuantity, equals(0), reason: 'Stock must be exactly 0, never negative');
    });

    test('20 concurrent requests for 2 units on stock = 10: exactly 5 succeed, 15 rejected, no overselling', () async {
      final service = DemoTransactionService.instance;
      const testProductId = 102;

      DemoDataService.products.removeWhere((p) => p.id == testProductId);
      DemoDataService.products.add(
        const Product(
          id: testProductId,
          name: 'Organic Blueberries',
          price: 150.0,
          stockQuantity: 10,
          unit: 'Pack of 125g',
          isActive: true,
        ),
      );

      final addressId = DemoDataService.addresses.first.id;

      final List<Future<Map<String, dynamic>?>> futures = [];
      for (int i = 0; i < 20; i++) {
        futures.add(
          service.createCheckout(
            userId: 'user-qty2-$i',
            addressId: addressId,
            cartItems: [
              {'product_id': testProductId, 'quantity': 2},
            ],
          ).then<Map<String, dynamic>?>((res) => res).catchError((e) {
            return null;
          }),
        );
      }

      final results = await Future.wait(futures);

      final successCount = results.where((r) => r != null && r['success'] == true).length;
      final rejectedCount = results.where((r) => r == null).length;

      expect(successCount, equals(5), reason: 'Exactly 5 purchases of 2 units each (total 10) must succeed');
      expect(rejectedCount, equals(15), reason: '15 purchases must be rejected');

      final finalProduct = DemoDataService.products.firstWhere((p) => p.id == testProductId);
      expect(finalProduct.stockQuantity, equals(0));
    });

    test('10 users requesting 3 units each on stock = 20: maximum 6 succeed (18 reserved), stock = 2', () async {
      final service = DemoTransactionService.instance;
      const testProductId = 103;

      DemoDataService.products.removeWhere((p) => p.id == testProductId);
      DemoDataService.products.add(
        const Product(
          id: testProductId,
          name: 'Dragon Fruit',
          price: 120.0,
          stockQuantity: 20,
          unit: '1 piece',
          isActive: true,
        ),
      );

      final addressId = DemoDataService.addresses.first.id;

      final List<Future<Map<String, dynamic>?>> futures = [];
      for (int i = 0; i < 10; i++) {
        futures.add(
          service.createCheckout(
            userId: 'user-qty3-$i',
            addressId: addressId,
            cartItems: [
              {'product_id': testProductId, 'quantity': 3},
            ],
          ).then<Map<String, dynamic>?>((res) => res).catchError((e) {
            return null;
          }),
        );
      }

      final results = await Future.wait(futures);

      final successCount = results.where((r) => r != null && r['success'] == true).length;
      expect(successCount, equals(6), reason: '6 x 3 = 18 units reserved');

      final finalProduct = DemoDataService.products.firstWhere((p) => p.id == testProductId);
      expect(finalProduct.stockQuantity, equals(2), reason: 'Remaining stock must be exactly 2');
    });

    test('Admin adjustments concurrently audit correctly', () async {
      final service = DemoTransactionService.instance;
      const testProductId = 104;

      DemoDataService.products.removeWhere((p) => p.id == testProductId);
      DemoDataService.products.add(
        const Product(
          id: testProductId,
          name: 'Alphonso Mango',
          price: 250.0,
          stockQuantity: 15,
          unit: '1 kg',
          isActive: true,
        ),
      );

      // Admin adds 10 units
      final newStock = await service.adminAdjustStock(
        productId: testProductId,
        delta: 10,
        reason: 'Shipment received from farm',
      );
      expect(newStock, equals(25));

      final ledgerEntry = service.inventoryLedger.last;
      expect(ledgerEntry['change_type'], equals('admin_adjustment'));
      expect(ledgerEntry['quantity_change'], equals(10));
      expect(ledgerEntry['stock_before'], equals(15));
      expect(ledgerEntry['stock_after'], equals(25));
    });
  });

  group('Phase 5 Final End-to-End Scenario (Section 50)', () {
    test('Kiwi Scenario: Stock 5, Customers A (2), B (2), C (2 fails), Payment, Webhook Deduplication, and Restock Refund', () async {
      final service = DemoTransactionService.instance;
      const kiwiId = 999;
      const double kiwiPrice = 180.0;

      // SETUP: Product Kiwi, Stock = 5, Price = ₹180
      DemoDataService.products.removeWhere((p) => p.id == kiwiId);
      DemoDataService.products.add(
        const Product(
          id: kiwiId,
          name: 'Kiwi',
          price: kiwiPrice,
          stockQuantity: 5,
          unit: 'Pack of 3',
          isActive: true,
        ),
      );

      final addressId = DemoDataService.addresses.first.id;

      // ─── Step 1: Customer A adds 2 Kiwi ──────────────────────────────────
      final orderARes = await service.createCheckout(
        userId: 'customer-a',
        addressId: addressId,
        cartItems: [
          {'product_id': kiwiId, 'quantity': 2},
        ],
        idempotencyKey: 'idem-customer-a-1',
      );
      expect(orderARes['success'], isTrue);
      final orderAId = orderARes['order_id'] as String;

      // Stock after Customer A: 5 - 2 = 3
      expect(DemoDataService.products.firstWhere((p) => p.id == kiwiId).stockQuantity, equals(3));

      // ─── Step 2: Customer B adds 2 Kiwi ──────────────────────────────────
      final orderBRes = await service.createCheckout(
        userId: 'customer-b',
        addressId: addressId,
        cartItems: [
          {'product_id': kiwiId, 'quantity': 2},
        ],
        idempotencyKey: 'idem-customer-b-1',
      );
      expect(orderBRes['success'], isTrue);
      final orderBId = orderBRes['order_id'] as String;

      // Stock after Customer B: 3 - 2 = 1
      expect(DemoDataService.products.firstWhere((p) => p.id == kiwiId).stockQuantity, equals(1));

      // ─── Step 3: Customer C attempts to buy 2 Kiwi ────────────────────────
      // Expected: Must fail due to insufficient stock (only 1 available)
      expect(
        () async => await service.createCheckout(
          userId: 'customer-c',
          addressId: addressId,
          cartItems: [
            {'product_id': kiwiId, 'quantity': 2},
          ],
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'error',
          contains('Insufficient stock for "Kiwi"'),
        )),
      );

      // Stock must remain 1
      expect(DemoDataService.products.firstWhere((p) => p.id == kiwiId).stockQuantity, equals(1));

      // ─── Step 4: Customer A pays ──────────────────────────────────────────
      final verifyA = await service.verifyPayment(
        orderId: orderAId,
        providerPaymentId: 'pay_kiwi_customer_a',
        providerSignature: 'sig_kiwi_customer_a',
        method: 'upi',
      );
      expect(verifyA['success'], isTrue);
      expect(verifyA['status'], equals('confirmed'));

      // Check Order A state
      final orderA = service.allOrders.firstWhere((o) => o.id == orderAId);
      expect(orderA.status, equals(OrderStatus.confirmed));

      // ─── Step 5: Late/Duplicate Webhook arrives for Customer A ────────────
      final duplicateWebhook = await service.verifyPayment(
        orderId: orderAId,
        providerPaymentId: 'pay_kiwi_customer_a',
        providerSignature: 'sig_kiwi_customer_a',
      );
      expect(duplicateWebhook['success'], isTrue);
      expect(duplicateWebhook['message'], contains('idempotent replay'));

      // No double inventory effect
      expect(DemoDataService.products.firstWhere((p) => p.id == kiwiId).stockQuantity, equals(1));

      // ─── Step 6: Customer B payment cancelled / fails ─────────────────────
      final cancelB = await service.handlePaymentFailure(
        orderId: orderBId,
        reason: 'User cancelled payment',
      );
      expect(cancelB['success'], isTrue);

      // Customer B's 2 held units are safely restored! Stock becomes 1 + 2 = 3
      expect(DemoDataService.products.firstWhere((p) => p.id == kiwiId).stockQuantity, equals(3));

      // ─── Step 7: Refund Order A with Restock ──────────────────────────────
      const refundKey = 'idem-refund-order-a';
      final refundA = await service.processRefund(
        orderId: orderAId,
        amount: orderA.grandTotal,
        reason: 'Customer requested refund for kiwi batch',
        restock: true, // Restock physical item
        idempotencyKey: refundKey,
      );
      expect(refundA['success'], isTrue);
      expect(refundA['restocked'], isTrue);

      // Customer A's 2 units are restored! Stock becomes 3 + 2 = 5 (Initial Stock!)
      expect(DemoDataService.products.firstWhere((p) => p.id == kiwiId).stockQuantity, equals(5));

      // ─── Step 8: Duplicate Refund request retried ─────────────────────────
      final duplicateRefund = await service.processRefund(
        orderId: orderAId,
        amount: orderA.grandTotal,
        reason: 'Customer requested refund for kiwi batch',
        restock: true,
        idempotencyKey: refundKey,
      );
      expect(duplicateRefund['success'], isTrue);
      expect(duplicateRefund['refund_id'], equals(refundA['refund_id']));

      // Stock is NOT restored a second time! Remains exactly 5.
      expect(DemoDataService.products.firstWhere((p) => p.id == kiwiId).stockQuantity, equals(5));
    });
  });
}
