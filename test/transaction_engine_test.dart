import 'package:flutter_test/flutter_test.dart';
import 'package:opem/demo/demo_data.dart';
import 'package:opem/demo/demo_transaction_service.dart';
import 'package:opem/models/order_v2.dart';

void main() {
  group('Order & Payment Finite State Machine Tests', () {
    test('OrderStatus valid state transitions', () {
      expect(OrderStatus.pendingPayment.canTransitionTo(OrderStatus.paymentProcessing), isTrue);
      expect(OrderStatus.pendingPayment.canTransitionTo(OrderStatus.paid), isTrue);
      expect(OrderStatus.pendingPayment.canTransitionTo(OrderStatus.confirmed), isTrue);
      expect(OrderStatus.pendingPayment.canTransitionTo(OrderStatus.paymentFailed), isTrue);
      expect(OrderStatus.pendingPayment.canTransitionTo(OrderStatus.cancelled), isTrue);

      expect(OrderStatus.confirmed.canTransitionTo(OrderStatus.completed), isTrue);
      expect(OrderStatus.confirmed.canTransitionTo(OrderStatus.cancelled), isTrue);
      expect(OrderStatus.confirmed.canTransitionTo(OrderStatus.refunded), isTrue);

      expect(OrderStatus.completed.canTransitionTo(OrderStatus.refunded), isTrue);
    });

    test('OrderStatus rejects illegal transitions', () {
      // Completed cannot jump back to pending_payment
      expect(OrderStatus.completed.canTransitionTo(OrderStatus.pendingPayment), isFalse);
      // Cancelled is terminal
      expect(OrderStatus.cancelled.canTransitionTo(OrderStatus.confirmed), isFalse);
      // Payment failed cannot directly become completed without payment
      expect(OrderStatus.paymentFailed.canTransitionTo(OrderStatus.completed), isFalse);
      // Refunded is terminal
      expect(OrderStatus.refunded.canTransitionTo(OrderStatus.confirmed), isFalse);
    });

    test('PaymentStatus valid and invalid transitions', () {
      expect(PaymentStatus.created.canTransitionTo(PaymentStatus.pending), isTrue);
      expect(PaymentStatus.created.canTransitionTo(PaymentStatus.captured), isTrue);
      expect(PaymentStatus.created.canTransitionTo(PaymentStatus.failed), isTrue);

      expect(PaymentStatus.captured.canTransitionTo(PaymentStatus.refunded), isTrue);
      expect(PaymentStatus.captured.canTransitionTo(PaymentStatus.partiallyRefunded), isTrue);

      // Captured cannot go back to pending
      expect(PaymentStatus.captured.canTransitionTo(PaymentStatus.pending), isFalse);
      // Failed cannot jump to captured without a new payment attempt
      expect(PaymentStatus.failed.canTransitionTo(PaymentStatus.captured), isFalse);
    });
  });

  group('Server-Authoritative Pricing & Snapshot Integrity Tests', () {
    test('Price snapshots calculate subtotal, delivery fee, and 5% tax correctly', () async {
      final service = DemoTransactionService.instance;
      // Product 1: Organic Whole Milk (sale_price: 2.19, unit: 1 Litre, stock >= 10)
      DemoDataService.updateDemoProduct(1, {'price': 60.0, 'sale_price': 50.0, 'stock_quantity': 100});

      final res = await service.createCheckout(
        userId: 'test-user-pricing',
        addressId: DemoDataService.addresses.first.id,
        cartItems: [
          {'product_id': 1, 'quantity': 4}, // 4 x 50 = 200 INR (< 500 -> delivery fee 40 INR)
        ],
      );

      expect(res['success'], isTrue);
      expect(res['subtotal'], equals(200.0));
      expect(res['delivery_fee'], equals(40.0));
      expect(res['tax_total'], equals(10.0)); // 5% of 200 = 10.0
      expect(res['grand_total'], equals(250.0)); // 200 + 40 + 10 = 250.0
    });

    test('Free delivery threshold applied when subtotal >= 500 INR', () async {
      final service = DemoTransactionService.instance;
      DemoDataService.updateDemoProduct(1, {'price': 100.0, 'sale_price': null, 'stock_quantity': 100});

      final res = await service.createCheckout(
        userId: 'test-user-free-deliv',
        addressId: DemoDataService.addresses.first.id,
        cartItems: [
          {'product_id': 1, 'quantity': 6}, // 6 x 100 = 600 INR (>= 500 -> FREE delivery)
        ],
      );

      expect(res['subtotal'], equals(600.0));
      expect(res['delivery_fee'], equals(0.0)); // Free delivery!
      expect(res['tax_total'], equals(30.0)); // 5% of 600 = 30.0
      expect(res['grand_total'], equals(630.0));
    });

    test('Historical snapshot remains unchanged after product price is subsequently updated', () async {
      final service = DemoTransactionService.instance;
      DemoDataService.updateDemoProduct(1, {'price': 50.0, 'sale_price': null, 'stock_quantity': 100});

      final res = await service.createCheckout(
        userId: 'test-user-snapshot',
        addressId: DemoDataService.addresses.first.id,
        cartItems: [
          {'product_id': 1, 'quantity': 2},
        ],
      );

      final orderId = res['order_id'] as String;
      final originalOrder = service.allOrders.firstWhere((o) => o.id == orderId);
      expect(originalOrder.items.first.unitPrice, equals(50.0));

      // Admin updates product price to 100 later
      DemoDataService.updateDemoProduct(1, {'price': 100.0});

      // The historical order snapshot MUST STILL have 50.0!
      final preservedOrder = service.allOrders.firstWhere((o) => o.id == orderId);
      expect(preservedOrder.items.first.unitPrice, equals(50.0));
      expect(preservedOrder.items.first.lineTotal, equals(100.0));
    });
  });

  group('Idempotency & Retry-Safety Tests', () {
    test('Submitting identical checkout with same idempotency key returns exact same order without double stock decrement', () async {
      final service = DemoTransactionService.instance;
      DemoDataService.updateDemoProduct(2, {'price': 80.0, 'sale_price': null, 'stock_quantity': 20});

      const key = 'idem-checkout-test-999';

      // 1st Attempt
      final res1 = await service.createCheckout(
        userId: 'test-idem-user',
        addressId: DemoDataService.addresses.first.id,
        cartItems: [
          {'product_id': 2, 'quantity': 2},
        ],
        idempotencyKey: key,
      );

      final stockAfterFirst = DemoDataService.products.firstWhere((p) => p.id == 2).stockQuantity;
      expect(stockAfterFirst, equals(18)); // 20 - 2

      // 2nd Attempt (Retry / double tap)
      final res2 = await service.createCheckout(
        userId: 'test-idem-user',
        addressId: DemoDataService.addresses.first.id,
        cartItems: [
          {'product_id': 2, 'quantity': 2},
        ],
        idempotencyKey: key,
      );

      // Same order returned
      expect(res2['order_id'], equals(res1['order_id']));
      expect(res2['order_number'], equals(res1['order_number']));

      // Stock was NOT decremented again!
      final stockAfterSecond = DemoDataService.products.firstWhere((p) => p.id == 2).stockQuantity;
      expect(stockAfterSecond, equals(18));
    });

    test('Duplicate payment verification is idempotent and does not consume reservations twice', () async {
      final service = DemoTransactionService.instance;
      DemoDataService.updateDemoProduct(3, {'price': 40.0, 'sale_price': null, 'stock_quantity': 15});

      final checkoutRes = await service.createCheckout(
        userId: 'test-idem-verify',
        addressId: DemoDataService.addresses.first.id,
        cartItems: [
          {'product_id': 3, 'quantity': 1},
        ],
      );
      final orderId = checkoutRes['order_id'] as String;

      // 1st Verification
      final verify1 = await service.verifyPayment(
        orderId: orderId,
        providerPaymentId: 'pay_test_123',
        providerSignature: 'sig_test_123',
      );
      expect(verify1['success'], isTrue);
      expect(verify1['status'], equals('confirmed'));

      // 2nd Verification (Late or repeated webhook)
      final verify2 = await service.verifyPayment(
        orderId: orderId,
        providerPaymentId: 'pay_test_123',
        providerSignature: 'sig_test_123',
      );
      expect(verify2['success'], isTrue);
      expect(verify2['message'], contains('idempotent'));
    });

    test('Same refund request with idempotency key does not duplicate refund', () async {
      final service = DemoTransactionService.instance;
      DemoDataService.updateDemoProduct(4, {'price': 50.0, 'sale_price': null, 'stock_quantity': 10});

      final checkoutRes = await service.createCheckout(
        userId: 'test-refund-user',
        addressId: DemoDataService.addresses.first.id,
        cartItems: [
          {'product_id': 4, 'quantity': 2},
        ],
      );
      final orderId = checkoutRes['order_id'] as String;

      await service.verifyPayment(
        orderId: orderId,
        providerPaymentId: 'pay_ref_111',
        providerSignature: 'sig_ref_111',
      );

      const refundKey = 'refund-key-444';

      // 1st Refund
      final ref1 = await service.processRefund(
        orderId: orderId,
        amount: 50.0,
        reason: 'Damaged packaging',
        restock: true,
        idempotencyKey: refundKey,
      );
      expect(ref1['success'], isTrue);

      final stockAfterRef1 = DemoDataService.products.firstWhere((p) => p.id == 4).stockQuantity;

      // 2nd Refund (Duplicate retry)
      final ref2 = await service.processRefund(
        orderId: orderId,
        amount: 50.0,
        reason: 'Damaged packaging',
        restock: true,
        idempotencyKey: refundKey,
      );
      expect(ref2['success'], isTrue);
      expect(ref2['refund_id'], equals(ref1['refund_id']));

      // Stock was NOT restocked twice!
      final stockAfterRef2 = DemoDataService.products.firstWhere((p) => p.id == 4).stockQuantity;
      expect(stockAfterRef2, equals(stockAfterRef1));
    });
  });

  group('Failure Recovery & Reservation Expiry Tests', () {
    test('Payment failure releases reserved inventory and logs reservation_released', () async {
      final service = DemoTransactionService.instance;
      DemoDataService.updateDemoProduct(5, {'price': 70.0, 'sale_price': null, 'stock_quantity': 25});

      final initialStock = DemoDataService.products.firstWhere((p) => p.id == 5).stockQuantity;

      final checkoutRes = await service.createCheckout(
        userId: 'test-fail-user',
        addressId: DemoDataService.addresses.first.id,
        cartItems: [
          {'product_id': 5, 'quantity': 3},
        ],
      );
      final orderId = checkoutRes['order_id'] as String;

      // Stock held
      expect(DemoDataService.products.firstWhere((p) => p.id == 5).stockQuantity, equals(initialStock - 3));

      // Customer cancels / payment fails
      final failRes = await service.handlePaymentFailure(
        orderId: orderId,
        reason: 'User cancelled at UPI pin entry',
      );
      expect(failRes['success'], isTrue);

      // Stock is restored to exact initial quantity!
      expect(DemoDataService.products.firstWhere((p) => p.id == 5).stockQuantity, equals(initialStock));

      // Check ledger audit entry
      final ledger = service.inventoryLedger.where((l) => l['order_id'] == orderId).toList();
      expect(ledger.any((l) => l['change_type'] == 'reservation_released'), isTrue);
    });
  });
}
