import 'package:flutter_test/flutter_test.dart';
import 'package:opem/models/analytics_event.dart';
import 'package:opem/models/admin_audit_log.dart';
import 'package:opem/services/analytics_service.dart';
import 'package:opem/services/audit_service.dart';
import 'package:opem/services/data_health_service.dart';
import 'package:opem/services/remote_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 8: Post-Launch Analytics & Funnel Telemetry', () {
    test('AnalyticsService tracks events non-blockingly without throwing', () async {
      final analytics = AnalyticsService.instance;
      analytics.init();

      // Emit multiple business funnel events
      expect(() => analytics.trackAppOpened(), returnsNormally);
      expect(
        () => analytics.trackProductViewed(
          productId: 101,
          productName: 'Organic Alphonso Mangoes',
          price: 299.0,
          categoryId: 'fruits',
        ),
        returnsNormally,
      );
      expect(
        () => analytics.trackCartItemAdded(
          productId: 101,
          productName: 'Organic Alphonso Mangoes',
          quantity: 2,
          price: 299.0,
        ),
        returnsNormally,
      );
      expect(
        () => analytics.trackCheckoutStarted(totalAmount: 598.0, itemCount: 2),
        returnsNormally,
      );
      expect(
        () => analytics.trackPaymentStarted(
          orderId: 'ord-test-123',
          amount: 598.0,
          method: 'upi',
        ),
        returnsNormally,
      );
      expect(
        () => analytics.trackOrderCreated(
          orderId: 'ord-test-123',
          totalAmount: 598.0,
          itemCount: 2,
        ),
        returnsNormally,
      );
      expect(
        () => analytics.trackSearchPerformed(query: 'mango', resultCount: 3),
        returnsNormally,
      );

      // Flush buffer
      await expectLater(analytics.flush(), completes);
    });

    test('Business Funnel calculation returns valid conversion and drop-off rates', () async {
      final analytics = AnalyticsService.instance;
      final funnel = await analytics.fetchBusinessFunnel();

      expect(funnel, contains('stages'));
      expect(funnel, contains('dropoffs'));
      expect(funnel, contains('overall_conversion_percent'));

      final stages = funnel['stages'] as Map<String, dynamic>;
      expect(stages['app_opened'], isNotNull);
      expect(stages['product_viewed'], isNotNull);
      expect(stages['cart_item_added'], isNotNull);
      expect(stages['checkout_started'], isNotNull);
      expect(stages['payment_started'], isNotNull);
      expect(stages['order_completed'], isNotNull);

      // Verify overall conversion rate is a valid percentage string
      final conversionPct = double.tryParse(funnel['overall_conversion_percent'].toString());
      expect(conversionPct, isNotNull);
      expect(conversionPct! >= 0.0 && conversionPct <= 100.0, isTrue);
    });

    test('AnalyticsEvent serialization and deserialization preserves properties', () {
      final event = AnalyticsEvent(
        eventType: 'product_viewed',
        entityType: 'product',
        entityId: '42',
        properties: {'name': 'Avocado', 'price': 150.0},
        appVersion: '1.0.0',
        platform: 'android',
      );

      final json = event.toJson();
      expect(json['event_type'], equals('product_viewed'));
      expect(json['entity_type'], equals('product'));
      expect(json['entity_id'], equals('42'));
      expect(json['properties']['price'], equals(150.0));

      final deserialized = AnalyticsEvent.fromJson(json);
      expect(deserialized.eventType, equals(event.eventType));
      expect(deserialized.properties['name'], equals('Avocado'));
    });
  });

  group('Phase 8: Remote Config & Emergency Kill Switches', () {
    test('Reads default feature flags and emergency kill switches correctly', () async {
      final config = RemoteConfigService.instance;
      await config.fetchConfig();

      expect(config.isLoaded, isTrue);
      expect(config.isFeatureEnabled('recommendations', defaultValue: true), isTrue);
      expect(config.isFeatureEnabled('new_checkout', defaultValue: true), isTrue);
      expect(config.isFeatureEnabled('deals_banner', defaultValue: true), isTrue);

      // Kill switches should default to false (safe operational state)
      expect(config.isCheckoutDisabled, isFalse);
      expect(config.isPaymentsDisabled, isFalse);
      expect(config.isRefundsDisabled, isFalse);
      expect(config.isMaintenanceMode, isFalse);
    });

    test('Toggling feature flag updates cache and logs audit record', () async {
      final config = RemoteConfigService.instance;

      final success = await config.updateFeatureFlag('review_system', true);
      expect(success, isTrue);
      expect(config.isFeatureEnabled('review_system'), isTrue);

      // Restore to false
      await config.updateFeatureFlag('review_system', false);
      expect(config.isFeatureEnabled('review_system'), isFalse);
    });

    test('Engaging emergency kill switch instantly reflects in gate getters', () async {
      final config = RemoteConfigService.instance;

      await config.setKillSwitch('disable_checkout', true);
      expect(config.isCheckoutDisabled, isTrue);

      // Disengage emergency switch
      await config.setKillSwitch('disable_checkout', false);
      expect(config.isCheckoutDisabled, isFalse);
    });

    test('Maintenance mode toggle updates status and custom message', () async {
      final config = RemoteConfigService.instance;

      await config.setMaintenanceMode(true, message: 'Server upgrade in progress');
      expect(config.isMaintenanceMode, isTrue);
      expect(config.maintenanceMessage, equals('Server upgrade in progress'));

      // Restore
      await config.setMaintenanceMode(false);
      expect(config.isMaintenanceMode, isFalse);
    });

    test('Minimum version gate correctly compares SemVer strings', () {
      final config = RemoteConfigService.instance;

      // Current 1.0.0 matches min 1.0.0
      expect(config.isVersionSupported('1.0.0', platform: 'android'), isTrue);

      // Newer 1.1.0 supported
      expect(config.isVersionSupported('1.1.0', platform: 'android'), isTrue);

      // Older 0.9.0 blocked
      expect(config.isVersionSupported('0.9.0', platform: 'android'), isFalse);
    });
  });

  group('Phase 8: Immutable Admin Audit Logging', () {
    test('Logs mutations and retrieves them with correct attributes', () async {
      final audit = AuditService.instance;

      await audit.logAction(
        action: 'test_mutation',
        entityType: 'catalog',
        entityId: 'item-99',
        previousState: {'price': 100},
        newState: {'price': 80},
        reason: 'Promotional markdown',
        severity: 'info',
      );

      final logs = await audit.fetchAuditLogs(entityType: 'catalog');
      expect(logs.isNotEmpty, isTrue);

      final first = logs.first;
      expect(first.action, equals('test_mutation'));
      expect(first.entityType, equals('catalog'));
      expect(first.entityId, equals('item-99'));
      expect(first.severity, equals('info'));
    });

    test('Helper methods log price change and stock adjustment with structured state', () async {
      final audit = AuditService.instance;

      await audit.logPriceChange(
        productId: 55,
        productName: 'Shimla Apples',
        oldPrice: 200.0,
        newPrice: 180.0,
        reason: 'Market price drop',
      );

      await audit.logStockAdjustment(
        productId: 55,
        productName: 'Shimla Apples',
        oldStock: 10,
        newStock: 50,
        reason: 'Fresh warehouse shipment',
      );

      final logs = await audit.fetchAuditLogs();
      expect(logs.any((l) => l.action == 'update_price'), isTrue);
      expect(logs.any((l) => l.action == 'adjust_stock'), isTrue);
    });

    test('AdminAuditLog serialization and deserialization', () {
      final log = AdminAuditLog(
        actorId: 'usr-admin-1',
        actorEmail: 'admin@bbuys.com',
        action: 'deactivate_product',
        entityType: 'product',
        entityId: '10',
        previousState: {'is_active': true},
        newState: {'is_active': false},
        reason: 'Supplier out of stock',
        severity: 'warning',
      );

      final json = log.toJson();
      expect(json['action'], equals('deactivate_product'));
      expect(json['severity'], equals('warning'));

      final fromJson = AdminAuditLog.fromJson(json);
      expect(fromJson.actorEmail, equals('admin@bbuys.com'));
      expect(fromJson.entityType, equals('product'));
    });
  });

  group('Phase 8: Data Quality Health & Fraud Detection Engine', () {
    test('DataHealthService runs database health check returning structured report', () async {
      final healthService = DataHealthService.instance;
      final report = await healthService.runHealthCheck();

      expect(report, contains('status'));
      expect(report, contains('checks'));
      expect(report, contains('action_required_count'));

      final checks = report['checks'] as Map<String, dynamic>;
      expect(checks.containsKey('negative_stock'), isTrue);
      expect(checks.containsKey('invalid_prices'), isTrue);
      expect(checks.containsKey('stuck_reservations'), isTrue);
      expect(checks.containsKey('orphaned_order_items'), isTrue);
      expect(checks.containsKey('orphaned_payments'), isTrue);
    });

    test('Fraud engine detects repeated payment failures', () {
      final healthService = DataHealthService.instance;

      final payments = [
        {'id': 'p1', 'user_id': 'fraud-user-1', 'status': 'failed'},
        {'id': 'p2', 'user_id': 'fraud-user-1', 'status': 'failed'},
        {'id': 'p3', 'user_id': 'fraud-user-1', 'status': 'failed'},
      ];

      final signals = healthService.evaluateAbuseSignals(
        recentOrders: [],
        recentPayments: payments,
      );

      expect(signals.any((s) => s.signal == 'REPEATED_PAYMENT_FAILURE'), isTrue);
      final failureSignal = signals.firstWhere((s) => s.signal == 'REPEATED_PAYMENT_FAILURE');
      expect(failureSignal.evidence['failed_attempts'], equals(3));
      expect(failureSignal.actionRecommendation, contains('Inspect payment gateway'));
    });

    test('Fraud engine detects abnormal order velocity', () {
      final healthService = DataHealthService.instance;
      final now = DateTime.now();

      final orders = [
        {'id': 'o1', 'user_id': 'fast-user', 'status': 'confirmed', 'created_at': now.subtract(const Duration(minutes: 8)).toIso8601String()},
        {'id': 'o2', 'user_id': 'fast-user', 'status': 'confirmed', 'created_at': now.subtract(const Duration(minutes: 6)).toIso8601String()},
        {'id': 'o3', 'user_id': 'fast-user', 'status': 'confirmed', 'created_at': now.subtract(const Duration(minutes: 4)).toIso8601String()},
        {'id': 'o4', 'user_id': 'fast-user', 'status': 'confirmed', 'created_at': now.subtract(const Duration(minutes: 2)).toIso8601String()},
      ];

      final signals = healthService.evaluateAbuseSignals(
        recentOrders: orders,
        recentPayments: [],
      );

      expect(signals.any((s) => s.signal == 'ABNORMAL_ORDER_VELOCITY'), isTrue);
      final velocitySignal = signals.firstWhere((s) => s.signal == 'ABNORMAL_ORDER_VELOCITY');
      expect(velocitySignal.evidence['order_count'], equals(4));
    });

    test('Fraud engine detects excessive refund ratio', () {
      final healthService = DataHealthService.instance;

      final orders = [
        {'id': 'o1', 'status': 'refunded'},
        {'id': 'o2', 'status': 'refunded'},
        {'id': 'o3', 'status': 'delivered'},
      ];

      final signals = healthService.evaluateAbuseSignals(
        recentOrders: orders,
        recentPayments: [],
      );

      expect(signals.any((s) => s.signal == 'HIGH_REFUND_RATIO'), isTrue);
    });

    test('Admin Dashboard aggregated metrics returns complete business and operational KPIs', () async {
      final healthService = DataHealthService.instance;
      final metrics = await healthService.fetchAdminDashboardMetrics();

      expect(metrics, contains('customers'));
      expect(metrics, contains('catalog'));
      expect(metrics, contains('orders'));
      expect(metrics, contains('payments'));

      final payments = metrics['payments'] as Map<String, dynamic>;
      expect(payments['successful'], isNotNull);
      expect(payments['failure_rate_pct'], isNotNull);
    });
  });
}
