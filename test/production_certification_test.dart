import 'package:flutter_test/flutter_test.dart';
import 'package:opem/demo/demo_data.dart';
import 'package:opem/demo/demo_transaction_service.dart';
import 'package:opem/models/order_v2.dart';
import 'package:opem/services/checkout_service.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uuid = Uuid();

  group('Phase 10 — Production Certification Test Suite', () {
    late CheckoutService checkout;

    setUp(() {
      checkout = CheckoutService();
      // Reset demo cart
      DemoDataService.cartItems.clear();
      // Ensure test product stock
      DemoDataService.updateDemoProduct(1, {'stock_quantity': 50});
    });

    test('1. Webhook Deduplication: 5x delivery produces exactly ONE logical payment effect', () async {
      final orderResult = await checkout.initiateCheckout(
        addressId: 'addr-1',
        cartItems: [
          {'product_id': 1, 'quantity': 2}
        ],
        idempotencyKey: 'cert-idem-${uuid.v4()}',
      );

      expect(orderResult['success'], true);
      final orderId = orderResult['order_id'] as String;
      final providerEventId = 'evt_${uuid.v4()}';
      final providerPaymentId = 'pay_${uuid.v4()}';

      // First webhook delivery
      final delivery1 = await checkout.processPaymentWebhook(
        providerEventId: providerEventId,
        eventType: 'payment.captured',
        orderId: orderId,
        providerPaymentId: providerPaymentId,
      );

      expect(delivery1['success'], true);
      expect(delivery1['duplicate'], false);
      expect(delivery1['status'], 'confirmed');

      // Subsequent 4 deliveries of identical event
      for (int i = 2; i <= 5; i++) {
        final duplicateDelivery = await checkout.processPaymentWebhook(
          providerEventId: providerEventId,
          eventType: 'payment.captured',
          orderId: orderId,
          providerPaymentId: providerPaymentId,
        );

        expect(duplicateDelivery['success'], true, reason: 'Duplicate delivery #$i should succeed idempotently');
        expect(duplicateDelivery['duplicate'], true, reason: 'Duplicate delivery #$i must be flagged as duplicate');
      }

      // Verify order final state in transaction engine
      final allOrders = DemoTransactionService.instance.allOrders;
      final order = allOrders.firstWhere((o) => o.id == orderId);
      expect(order.status, OrderStatus.confirmed);
      expect(order.paymentStatus, PaymentStatus.captured);
    });

    test('2. App Crash After Payment Recovery: Webhook transitions order to confirmed safely', () async {
      // Step A: Customer initiates checkout
      final orderResult = await checkout.initiateCheckout(
        addressId: 'addr-1',
        cartItems: [
          {'product_id': 1, 'quantity': 1}
        ],
        idempotencyKey: 'crash-idem-${uuid.v4()}',
      );
      final orderId = orderResult['order_id'] as String;

      // Step B: Customer app crashes (no verifyPayment call made from client)
      // Step C: Payment provider sends webhook asynchronously
      final webhookResult = await checkout.processPaymentWebhook(
        providerEventId: 'evt_crash_recovery_${uuid.v4()}',
        eventType: 'payment.captured',
        orderId: orderId,
        providerPaymentId: 'pay_crash_resolved_${uuid.v4()}',
      );

      expect(webhookResult['success'], true);
      expect(webhookResult['status'], 'confirmed');

      // Step D: Customer reopens app / queries orders -> order is confirmed
      final allOrders = DemoTransactionService.instance.allOrders;
      final recoveredOrder = allOrders.firstWhere((o) => o.id == orderId);
      expect(recoveredOrder.status, OrderStatus.confirmed);
      expect(recoveredOrder.paymentStatus, PaymentStatus.captured);
    });

    test('3. Client Payment Verification Idempotency: Duplicate verify calls return replay', () async {
      final orderResult = await checkout.initiateCheckout(
        addressId: 'addr-1',
        cartItems: [
          {'product_id': 1, 'quantity': 1}
        ],
        idempotencyKey: 'verify-idem-${uuid.v4()}',
      );
      final orderId = orderResult['order_id'] as String;

      // First verification
      final res1 = await checkout.verifyPayment(
        orderId: orderId,
        providerPaymentId: 'pay_first_${uuid.v4()}',
        providerSignature: 'valid_sig_123',
      );
      expect(res1['success'], true);
      expect(res1['status'], 'confirmed');

      // Immediate second verification (double-click)
      final res2 = await checkout.verifyPayment(
        orderId: orderId,
        providerPaymentId: 'pay_second_${uuid.v4()}',
        providerSignature: 'valid_sig_123',
      );
      expect(res2['success'], true);
      expect(res2['message'], contains('already paid and confirmed'));
    });

    test('4. Cross-User Account Isolation: User B cannot observe User A orders', () async {
      const userA = 'user-alpha-123';
      const userB = 'user-beta-456';

      await DemoTransactionService.instance.createCheckout(
        userId: userA,
        addressId: 'addr-1',
        cartItems: [
          {'product_id': 1, 'quantity': 1}
        ],
        idempotencyKey: 'iso-${uuid.v4()}',
      );

      // Listen to User B order stream
      final userBOrders = await DemoTransactionService.instance
          .watchCustomerOrders(userB)
          .first;

      // Verify none of User A's orders leak into User B's stream
      final leaked = userBOrders.any((o) => o.userId == userA);
      expect(leaked, false, reason: "User B must not see User A's orders");
    });

    test('5. Automated Data Reconciliation & Negative Stock Audit', () async {
      // Reconcile system
      final report = await checkout.reconcileSystemData();

      expect(report['success'], true);
      expect(report['negative_stock_anomalies'], 0, reason: 'Negative stock must never occur');
      expect(report.containsKey('expired_reservations_cleaned'), true);
      expect(report.containsKey('reconciled_at'), true);
    });
  });
}
