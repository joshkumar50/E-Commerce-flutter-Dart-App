import 'package:flutter_test/flutter_test.dart';
import 'package:opem/models/fulfillment_location.dart';
import 'package:opem/models/outbox_event.dart';
import 'package:opem/models/product.dart';
import 'package:opem/services/fulfillment_service.dart';
import 'package:opem/services/outbox_service.dart';
import 'package:opem/services/product_service.dart';
import 'package:opem/services/remote_config_service.dart';
import 'package:opem/utils/circuit_breaker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Optimistic Concurrency Control (OCC) Tests', () {
    test('Product model supports version field with default value 1', () {
      const prod = Product(
        id: 101,
        name: 'Organic Honey',
        price: 9.99,
      );
      expect(prod.version, 1);

      final updated = prod.copyWith(name: 'Pure Organic Honey', version: 2);
      expect(updated.version, 2);
      expect(updated.name, 'Pure Organic Honey');
    });

    test('Product serialization preserves version', () {
      final json = {
        'id': 55,
        'name': 'Greek Yogurt',
        'price': 4.50,
        'stock_quantity': 30,
        'version': 4,
      };
      final prod = Product.fromJson(json);
      expect(prod.version, 4);

      final exported = prod.toJson();
      expect(exported['version'], 4);
    });

    test('Concurrent product update with stale version throws StaleVersionException', () async {
      final prodService = ProductService();

      // Product #1 is loaded with version 1
      const initialVersion = 1;

      // First admin updates successfully with expectedVersion 1 -> succeeds, version becomes 2
      await prodService.updateProduct(
        1,
        {'price': 2.79},
        expectedVersion: initialVersion,
      );

      // Second admin attempts to update with stale expectedVersion 1 -> must throw StaleVersionException
      expect(
        () => prodService.updateProduct(
          1,
          {'price': 2.99},
          expectedVersion: initialVersion,
        ),
        throwsA(isA<StaleVersionException>()),
      );
    });
  });

  group('Transactional Outbox Pattern Tests', () {
    test('OutboxEvent model serializes and deserializes correctly', () {
      final event = OutboxEvent(
        eventType: 'order.placed',
        aggregateType: 'order',
        aggregateId: 'ord_999',
        payload: {'total': 49.99, 'items': 4},
        correlationId: 'trace-abc-123',
      );

      final json = event.toJson();
      expect(json['event_type'], 'order.placed');
      expect(json['aggregate_type'], 'order');
      expect(json['aggregate_id'], 'ord_999');
      expect(json['correlation_id'], 'trace-abc-123');
      expect(json['status'], 'pending');

      final reconstructed = OutboxEvent.fromJson(json);
      expect(reconstructed.eventType, 'order.placed');
      expect(reconstructed.aggregateId, 'ord_999');
      expect(reconstructed.status, OutboxStatus.pending);
    });

    test('OutboxService publishes event and processes batch reliably', () async {
      final outbox = OutboxService.instance;

      final eventId = await outbox.publishEvent(
        eventType: 'inventory.allocated',
        aggregateType: 'inventory',
        aggregateId: 'prod_test_1',
        payload: {'quantity': 3},
      );

      expect(eventId, isNotEmpty);

      // Process batch
      final batchResult = await outbox.processBatch(batchSize: 10);
      expect(batchResult['success'], true);
      expect(batchResult['processed_count'], greaterThanOrEqualTo(1));

      // Verify event is now published
      final events = await outbox.fetchRecentEvents(limit: 10);
      final publishedEvent = events.firstWhere((e) => e.eventId == eventId);
      expect(publishedEvent.status, OutboxStatus.published);
      expect(publishedEvent.processedAt, isNotNull);
    });
  });

  group('Multi-Location Fulfillment & Inventory Tests', () {
    test('FulfillmentLocation parses serviced pincodes and address correctly', () {
      final json = {
        'id': 'wh_blr_central',
        'name': 'Bengaluru Central Dark Store',
        'type': 'dark_store',
        'address': {'city': 'Bengaluru', 'street': 'Indiranagar'},
        'serviced_pincodes': ['560038', '560008'],
        'is_active': true,
      };

      final location = FulfillmentLocation.fromJson(json);
      expect(location.id, 'wh_blr_central');
      expect(location.type, 'dark_store');
      expect(location.servicedPincodes, contains('560038'));
      expect(location.isActive, true);
    });

    test('LocationInventory calculates total stock and low-stock status', () {
      const inv = LocationInventory(
        id: 1,
        productId: 10,
        locationId: 'wh_blr_central',
        availableQuantity: 5,
        reservedQuantity: 3,
        reorderThreshold: 10,
      );

      expect(inv.totalStock, 8);
      expect(inv.isLowStock, true);
    });

    test('FulfillmentService returns active locations and handles allocation', () async {
      final service = FulfillmentService.instance;
      final locations = await service.fetchLocations();

      expect(locations, isNotEmpty);
      expect(locations.first.id, 'wh_blr_central');

      final alloc = await service.allocateLocationInventory(
        productId: 1,
        locationId: 'wh_blr_central',
        quantity: 2,
        orderId: 'ord_demo_test',
      );

      expect(alloc['success'], true);
      expect(alloc['allocated_quantity'], 2);
    });
  });

  group('Circuit Breaker Resilience Engine Tests', () {
    test('Circuit breaker trips to open after failure threshold and executes fallback', () async {
      final breaker = CircuitBreaker(
        name: 'test_payment_gateway',
        failureThreshold: 3,
        resetTimeout: const Duration(milliseconds: 100),
      );

      expect(breaker.state, CircuitState.closed);

      // Fail 1
      try {
        await breaker.execute(() async => throw Exception('Gateway timeout 1'));
      } catch (_) {}
      expect(breaker.state, CircuitState.closed);

      // Fail 2
      try {
        await breaker.execute(() async => throw Exception('Gateway timeout 2'));
      } catch (_) {}
      expect(breaker.state, CircuitState.closed);

      // Fail 3 -> threshold reached, trips to open
      try {
        await breaker.execute(() async => throw Exception('Gateway timeout 3'));
      } catch (_) {}
      expect(breaker.state, CircuitState.open);

      // Calls while open execute fallback immediately without calling main action
      final fallbackResult = await breaker.execute(
        () async => 'should not run',
        fallback: () async => 'fallback_cod_payment',
      );
      expect(fallbackResult, 'fallback_cod_payment');

      // Wait for reset timeout -> transitions to halfOpen
      await Future.delayed(const Duration(milliseconds: 120));
      expect(breaker.state, CircuitState.halfOpen);

      // Successful probe in halfOpen resets to closed
      final recovered = await breaker.execute(() async => 'healthy_response');
      expect(recovered, 'healthy_response');
      expect(breaker.state, CircuitState.closed);
    });

    test('CircuitBreakerRegistry provides singleton breaker instances', () {
      final b1 = CircuitBreakerRegistry.instance.get('razorpay');
      final b2 = CircuitBreakerRegistry.instance.get('razorpay');
      expect(identical(b1, b2), true);
    });
  });

  group('Service Levels & High-Traffic Load Shedding Tests', () {
    test('Platform transitions between FULL, DEGRADED, and CRITICAL_CHECKOUT_ONLY', () async {
      final config = RemoteConfigService.instance;

      expect(config.serviceLevel, ServiceLevel.full);
      expect(config.canLoadAuxiliaryFeatures, true);

      // Transition to degraded
      await config.setServiceLevel(ServiceLevel.degraded);
      expect(config.serviceLevel, ServiceLevel.degraded);
      expect(config.canLoadAuxiliaryFeatures, false);

      // Toggle high traffic mode
      await config.setHighTrafficMode(true);
      expect(config.isHighTrafficMode, true);

      // Transition to critical checkout only
      await config.setServiceLevel(ServiceLevel.criticalCheckoutOnly);
      expect(config.isCriticalCheckoutOnly, true);

      // Reset to full
      await config.setHighTrafficMode(false);
      await config.setServiceLevel(ServiceLevel.full);
      expect(config.serviceLevel, ServiceLevel.full);
      expect(config.canLoadAuxiliaryFeatures, true);
    });
  });
}
