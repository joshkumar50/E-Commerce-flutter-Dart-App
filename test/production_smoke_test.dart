import 'package:flutter_test/flutter_test.dart';
import 'package:opem/core/app_environment.dart';
import 'package:opem/demo/demo_data.dart';
import 'package:opem/demo/demo_transaction_service.dart';
import 'package:opem/models/order_v2.dart';
import 'package:opem/services/audit_service.dart';
import 'package:opem/services/checkout_service.dart';
import 'package:opem/services/remote_config_service.dart';
import 'package:opem/utils/circuit_breaker.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uuid = Uuid();

  group('Phase 11: Production Smoke Testing & Go-Live Verification', () {
    late CheckoutService checkout;

    setUp(() {
      checkout = CheckoutService();
      DemoDataService.cartItems.clear();
      DemoDataService.updateDemoProduct(1, {'stock_quantity': 100, 'version': 1});
    });

    test('1. Environment Validation & Startup Smoke Test', () {
      expect(() => AppEnvironment.validate(), returnsNormally);
      expect(AppEnvironment.current, Environment.development);
      expect(AppEnvironment.isDemoMode, false);
    });

    test('2. Customer End-to-End Smoke Journey (Browse -> Cart -> Checkout -> Pay -> Order History)', () async {
      // Step A: Browse & Verify Product
      final product = DemoDataService.products.firstWhere((p) => p.id == 1);
      expect(product.stockQuantity, greaterThanOrEqualTo(10));
      expect(product.isActive, true);

      // Step B: Add to Cart via DemoDataService
      DemoDataService.addDemoCartItem(1, 2);
      expect(DemoDataService.cartItems.length, 1);
      expect(DemoDataService.cartItems.first.quantity, 2);

      // Step C: Initiate Server-Authoritative Checkout
      final checkoutResult = await checkout.initiateCheckout(
        addressId: 'addr-1',
        cartItems: [
          {'product_id': 1, 'quantity': 2}
        ],
        idempotencyKey: 'smoke-checkout-${uuid.v4()}',
      );

      expect(checkoutResult['success'], true);
      final orderId = checkoutResult['order_id'] as String;
      expect(checkoutResult['order_number'], startsWith('ORD-'));
      expect(checkoutResult['currency'], 'INR');

      // Cart cleared automatically upon checkout initiation
      expect(DemoDataService.cartItems.isEmpty, true);

      // Step D: Server Payment Signature Verification
      final paymentResult = await checkout.verifyPayment(
        orderId: orderId,
        providerPaymentId: 'rzp_pay_${uuid.v4()}',
        providerSignature: 'valid_prod_signature_sig',
        paymentMethod: 'upi',
      );

      expect(paymentResult['success'], true);
      expect(paymentResult['status'], 'confirmed');
      expect(paymentResult['payment_status'], 'captured');

      // Step E: Verify Customer Order History Stream
      final customerOrders = await DemoTransactionService.instance
          .watchCustomerOrders(DemoDataService.demoCustomerProfile.id)
          .first;

      final placedOrder = customerOrders.firstWhere((o) => o.id == orderId);
      expect(placedOrder.status, OrderStatus.confirmed);
      expect(placedOrder.paymentStatus, PaymentStatus.captured);
      expect(placedOrder.items.length, 1);
      expect(placedOrder.items.first.quantity, 2);
    });

    test('3. Admin End-to-End Operational Smoke Journey (OCC -> Stock -> Transition -> Refund -> Audit)', () async {
      final engine = DemoTransactionService.instance;
      final audit = AuditService.instance;

      // Step A: OCC Product Update
      final prodBefore = DemoDataService.products.firstWhere((p) => p.id == 1);
      final currentVersion = prodBefore.version;
      DemoDataService.updateDemoProduct(1, {
        'price': 65.0,
        'version': currentVersion + 1,
      });

      final prodAfter = DemoDataService.products.firstWhere((p) => p.id == 1);
      expect(prodAfter.price, 65.0);
      expect(prodAfter.version, currentVersion + 1);

      // Step B: Concurrency-Safe Stock Adjustment with Ledger Recording
      final newStock = await engine.adminAdjustStock(
        productId: 1,
        delta: 25,
        reason: 'Restock shipment received at central dark store',
      );
      expect(newStock, greaterThan(100));

      final latestLedger = engine.inventoryLedger.last;
      expect(latestLedger['change_type'], 'admin_adjustment');
      expect(latestLedger['quantity_change'], 25);

      // Step C: Create and Confirm Order for Operations Test
      final ordResult = await checkout.initiateCheckout(
        addressId: 'addr-1',
        cartItems: [
          {'product_id': 1, 'quantity': 1}
        ],
        idempotencyKey: 'admin-ops-${uuid.v4()}',
      );
      final orderId = ordResult['order_id'] as String;
      await checkout.verifyPayment(
        orderId: orderId,
        providerPaymentId: 'pay_ops_${uuid.v4()}',
        providerSignature: 'sig',
      );

      // Step D: Operational Status Transition to Completed
      await engine.adminUpdateOrderStatus(orderId: orderId, newStatus: OrderStatus.completed);

      final completedOrder = engine.allOrders.firstWhere((o) => o.id == orderId);
      expect(completedOrder.status, OrderStatus.completed);

      // Step E: Admin Refund with Restock
      final refundResult = await engine.processRefund(
        orderId: orderId,
        amount: completedOrder.grandTotal,
        reason: 'Customer return accepted at hub',
        restock: true,
        idempotencyKey: 'refund-ops-${uuid.v4()}',
      );

      expect(refundResult['success'], true);
      expect(refundResult['status'], 'processed');
      expect(refundResult['restocked'], true);

      // Verify refund ledger entry
      final refundLedger = engine.inventoryLedger.last;
      expect(refundLedger['change_type'], 'refund_restock');

      // Step F: Immutable Audit Log Verification
      await audit.logPriceChange(
        productId: 1,
        productName: 'Organic Whole Milk',
        oldPrice: 60.0,
        newPrice: 65.0,
        reason: 'Inflation adjustment',
      );

      final auditLogs = await audit.fetchAuditLogs(limit: 5);
      expect(auditLogs.isNotEmpty, true);
      expect(auditLogs.first.action, 'update_price');
    });

    test('4. Emergency Kill Switches & Remote Config Smoke Test', () async {
      final remoteConfig = RemoteConfigService.instance;

      // Verify defaults
      expect(remoteConfig.isMaintenanceMode, false);
      expect(remoteConfig.isCheckoutDisabled, false);
      expect(remoteConfig.isHighTrafficMode, false);

      // Emergency Kill Switch: Maintenance Mode
      await remoteConfig.setMaintenanceMode(true, message: 'Scheduled DB Maintenance');
      expect(remoteConfig.isMaintenanceMode, true);
      expect(remoteConfig.maintenanceMessage, contains('Scheduled DB Maintenance'));

      // Restore Maintenance Mode
      await remoteConfig.setMaintenanceMode(false);
      expect(remoteConfig.isMaintenanceMode, false);

      // Emergency Kill Switch: Checkout Disabled
      await remoteConfig.setKillSwitch('disable_checkout', true);
      expect(remoteConfig.isCheckoutDisabled, true);

      // Restore Checkout
      await remoteConfig.setKillSwitch('disable_checkout', false);
      expect(remoteConfig.isCheckoutDisabled, false);

      // High Traffic & Degradation Levels
      await remoteConfig.setServiceLevel(ServiceLevel.degraded);
      expect(remoteConfig.serviceLevel, ServiceLevel.degraded);

      await remoteConfig.setServiceLevel(ServiceLevel.criticalCheckoutOnly);
      expect(remoteConfig.serviceLevel, ServiceLevel.criticalCheckoutOnly);
      expect(remoteConfig.isCriticalCheckoutOnly, true);

      // Restore Full Service Level
      await remoteConfig.setServiceLevel(ServiceLevel.full);
      expect(remoteConfig.serviceLevel, ServiceLevel.full);
      expect(remoteConfig.canLoadAuxiliaryFeatures, true);
    });

    test('5. Circuit Breaker State Isolation & Fail-Fast Recovery Smoke Test', () async {
      final breaker = CircuitBreaker(
        name: 'payment_gateway_smoke_breaker',
        failureThreshold: 3,
        resetTimeout: const Duration(milliseconds: 100),
      );

      expect(breaker.state, CircuitState.closed);

      // Simulate 3 consecutive failures
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('Payment Gateway 504 Gateway Timeout'));
        } catch (_) {}
      }

      // Breaker trips to OPEN
      expect(breaker.state, CircuitState.open);

      // Subsequent call fails fast without executing action
      bool actionExecuted = false;
      try {
        await breaker.execute(() async {
          actionExecuted = true;
          return 'ok';
        });
      } catch (e) {
        expect(e.toString(), contains('OPEN'));
      }
      expect(actionExecuted, false, reason: 'Circuit breaker must fail fast when OPEN');

      // Wait for reset timeout -> transitions to HALF_OPEN
      await Future.delayed(const Duration(milliseconds: 150));
      expect(breaker.state, CircuitState.halfOpen);

      // Successful call resets to CLOSED
      final result = await breaker.execute(() async => 'recovered');
      expect(result, 'recovered');
      expect(breaker.state, CircuitState.closed);
    });
  });
}
