import 'dart:async';
import 'package:opem/demo/demo_data.dart';
import 'package:opem/models/order_v2.dart';
import 'package:opem/models/payment.dart';
import 'package:uuid/uuid.dart';

/// High-fidelity in-memory transaction engine for offline demo mode.
/// Enforces identical row-locking simulation, stock reservation, idempotency,
/// and finite state machine rules as the PostgreSQL migration.
class DemoTransactionService {
  static final DemoTransactionService instance = DemoTransactionService._();
  DemoTransactionService._() {
    _seedInitialOrders();
  }

  static const _uuid = Uuid();

  final List<OrderV2> _orders = [];
  final List<Map<String, dynamic>> _reservations = [];
  final List<Map<String, dynamic>> _inventoryLedger = [];
  final List<PaymentRecord> _payments = [];
  final List<RefundRecord> _refunds = [];
  final Map<String, Map<String, dynamic>> _idempotencyKeys = {};
  final Map<String, Map<String, dynamic>> _paymentEvents = {};

  final StreamController<List<OrderV2>> _ordersStreamController =
      StreamController<List<OrderV2>>.broadcast();

  Stream<List<OrderV2>> watchCustomerOrders(String userId) {
    // Immediately emit current orders for user
    Future.microtask(() {
      _ordersStreamController.add(List.unmodifiable(_orders));
    });
    return _ordersStreamController.stream.map(
      (all) => all.where((o) => o.userId == userId).toList(),
    );
  }

  Stream<List<OrderV2>> watchAllOrders() {
    Future.microtask(() {
      _ordersStreamController.add(List.unmodifiable(_orders));
    });
    return _ordersStreamController.stream;
  }

  List<OrderV2> get allOrders => List.unmodifiable(_orders);
  List<Map<String, dynamic>> get inventoryLedger => List.unmodifiable(_inventoryLedger);

  void _seedInitialOrders() {
    final now = DateTime.now();
    final address = AddressSnapshot.fromJson(DemoDataService.addresses.first.toJson());

    final order1 = OrderV2(
      id: 'demo-ord-1001',
      orderNumber: 'ORD-20260920-A1B2C3',
      userId: DemoDataService.demoCustomerProfile.id,
      status: OrderStatus.completed,
      paymentStatus: PaymentStatus.captured,
      currency: 'INR',
      subtotal: 180.0,
      discountTotal: 0.0,
      deliveryFee: 40.0,
      taxTotal: 9.0,
      grandTotal: 229.0,
      shippingAddress: address,
      pricingSnapshot: PricingSnapshot(
        subtotal: 180.0,
        discountTotal: 0.0,
        deliveryFee: 40.0,
        taxTotal: 9.0,
        grandTotal: 229.0,
        currency: 'INR',
        itemCount: 2,
        calculatedAt: now.subtract(const Duration(days: 1)),
      ),
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(days: 1)),
      items: [
        OrderItem(
          id: 'item-101',
          orderId: 'demo-ord-1001',
          productId: 1,
          productNameSnapshot: 'Organic Whole Milk',
          unitSnapshot: '1 Litre',
          imageUrlSnapshot: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=640&q=80',
          unitPrice: 60.0,
          quantity: 2,
          lineTotal: 120.0,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        OrderItem(
          id: 'item-102',
          orderId: 'demo-ord-1001',
          productId: 7,
          productNameSnapshot: 'Farm Fresh Brown Eggs',
          unitSnapshot: 'Pack of 12',
          imageUrlSnapshot: 'https://images.unsplash.com/photo-1516467508483-a7212febe31a?w=640&q=80',
          unitPrice: 60.0,
          quantity: 1,
          lineTotal: 60.0,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ],
    );

    _orders.add(order1);
  }

  /// Atomic checkout creation with sorted product locking, server pricing, stock hold, and idempotency.
  Future<Map<String, dynamic>> createCheckout({
    required String userId,
    required String addressId,
    required List<Map<String, dynamic>> cartItems,
    String? idempotencyKey,
    String notes = '',
  }) async {
    // 1. Idempotency Check
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      final cacheKey = '$userId:checkout:$idempotencyKey';
      if (_idempotencyKeys.containsKey(cacheKey)) {
        final existing = _idempotencyKeys[cacheKey]!;
        if (existing['status'] == 'completed') {
          return existing['response'] as Map<String, dynamic>;
        } else if (existing['status'] == 'in_progress') {
          throw Exception('Checkout already in progress for this request key');
        }
      }
      _idempotencyKeys[cacheKey] = {
        'status': 'in_progress',
        'created_at': DateTime.now(),
      };
    }

    // 2. Validate Address
    final address = DemoDataService.addresses.firstWhere(
      (a) => a.id == addressId,
      orElse: () => DemoDataService.addresses.first,
    );
    final addressSnapshot = AddressSnapshot(
      addressId: address.id,
      label: address.label,
      fullName: address.fullName,
      phone: address.phone,
      addressLine1: address.addressLine1,
      addressLine2: address.addressLine2,
      city: address.city,
      state: address.state,
      postalCode: address.postalCode,
      country: address.country,
    );

    // 3. Sort items by product ID (Deadlock prevention)
    final sortedItems = List<Map<String, dynamic>>.from(cartItems)
      ..sort((a, b) => (a['product_id'] as int).compareTo(b['product_id'] as int));

    // 4. Server-Side Recalculation & Stock Verification
    double subtotal = 0.0;
    final List<Map<String, dynamic>> validatedLineItems = [];

    for (final item in sortedItems) {
      final productId = item['product_id'] as int;
      final quantity = item['quantity'] as int;

      if (quantity <= 0) {
        throw Exception('Quantity must be greater than 0');
      }

      final product = DemoDataService.products.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('Product $productId not found'),
      );

      if (!product.isActive) {
        throw Exception('Product "${product.name}" is inactive');
      }

      if (product.stockQuantity < quantity) {
        throw Exception('Insufficient stock for "${product.name}". Available: ${product.stockQuantity}, Requested: $quantity');
      }

      final effectivePrice = product.salePrice ?? product.price;
      final lineTotal = double.parse((effectivePrice * quantity).toStringAsFixed(2));
      subtotal += lineTotal;

      validatedLineItems.add({
        'product': product,
        'quantity': quantity,
        'unitPrice': effectivePrice,
        'lineTotal': lineTotal,
      });
    }

    // Standard business rules
    final double deliveryFee = subtotal >= 500.0 ? 0.0 : 40.0;
    final double taxTotal = double.parse((subtotal * 0.05).toStringAsFixed(2));
    final double grandTotal = double.parse((subtotal + deliveryFee + taxTotal).toStringAsFixed(2));

    final orderId = _uuid.v4();
    final orderNumber = 'ORD-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${orderId.substring(0, 6).toUpperCase()}';
    final expiresAt = DateTime.now().add(const Duration(minutes: 15));

    final pricingSnapshot = PricingSnapshot(
      subtotal: subtotal,
      discountTotal: 0.0,
      deliveryFee: deliveryFee,
      taxTotal: taxTotal,
      grandTotal: grandTotal,
      currency: 'INR',
      itemCount: validatedLineItems.length,
      calculatedAt: DateTime.now(),
    );

    // 5. Decrement Stock & Create Reservations
    final List<OrderItem> orderItems = [];

    for (final line in validatedLineItems) {
      final product = line['product'] as dynamic;
      final quantity = line['quantity'] as int;
      final unitPrice = line['unitPrice'] as double;
      final lineTotal = line['lineTotal'] as double;

      // Atomic stock decrement
      final stockBefore = product.stockQuantity;
      final stockAfter = stockBefore - quantity;
      DemoDataService.updateDemoProduct(product.id, {'stock_quantity': stockAfter});

      // Create reservation
      final resId = _uuid.v4();
      _reservations.add({
        'id': resId,
        'order_id': orderId,
        'product_id': product.id,
        'quantity': quantity,
        'status': 'reserved',
        'expires_at': expiresAt,
        'created_at': DateTime.now(),
      });

      // Write inventory ledger
      _inventoryLedger.add({
        'id': _uuid.v4(),
        'product_id': product.id,
        'order_id': orderId,
        'reservation_id': resId,
        'change_type': 'purchase_reserved',
        'quantity_change': -quantity,
        'stock_before': stockBefore,
        'stock_after': stockAfter,
        'reason': 'Held for order $orderNumber',
        'created_at': DateTime.now(),
      });

      orderItems.add(OrderItem(
        id: _uuid.v4(),
        orderId: orderId,
        productId: product.id,
        productNameSnapshot: product.name,
        unitSnapshot: product.unit,
        imageUrlSnapshot: product.imageUrl,
        unitPrice: unitPrice,
        quantity: quantity,
        lineTotal: lineTotal,
        createdAt: DateTime.now(),
      ));
    }

    // 6. Create Order & Payment Record
    final order = OrderV2(
      id: orderId,
      orderNumber: orderNumber,
      userId: userId,
      status: OrderStatus.pendingPayment,
      paymentStatus: PaymentStatus.created,
      currency: 'INR',
      subtotal: subtotal,
      discountTotal: 0.0,
      deliveryFee: deliveryFee,
      taxTotal: taxTotal,
      grandTotal: grandTotal,
      shippingAddress: addressSnapshot,
      pricingSnapshot: pricingSnapshot,
      idempotencyKey: idempotencyKey,
      notes: notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      items: orderItems,
    );
    _orders.insert(0, order);

    final providerOrderId = 'rzp_order_${_uuid.v4().replaceAll('-', '').substring(0, 14)}';
    final payment = PaymentRecord(
      id: _uuid.v4(),
      orderId: orderId,
      provider: 'razorpay',
      providerOrderId: providerOrderId,
      amount: grandTotal,
      currency: 'INR',
      status: PaymentStatus.created,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _payments.add(payment);

    // 7. Clear Demo Cart
    DemoDataService.cartItems.clear();

    final response = {
      'success': true,
      'order_id': orderId,
      'order_number': orderNumber,
      'payment_id': payment.id,
      'provider_order_id': providerOrderId,
      'grand_total': grandTotal,
      'currency': 'INR',
      'subtotal': subtotal,
      'delivery_fee': deliveryFee,
      'tax_total': taxTotal,
      'expires_at': expiresAt.toIso8601String(),
    };

    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      final cacheKey = '$userId:checkout:$idempotencyKey';
      _idempotencyKeys[cacheKey] = {
        'status': 'completed',
        'response': response,
        'created_at': DateTime.now(),
      };
    }

    _ordersStreamController.add(List.unmodifiable(_orders));
    return response;
  }

  /// Authoritative server-side payment verification
  Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String providerPaymentId,
    required String providerSignature,
    String method = 'upi',
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) throw Exception('Order not found');

    final order = _orders[index];

    // Idempotent check
    if (order.status == OrderStatus.confirmed || order.status == OrderStatus.completed) {
      return {
        'success': true,
        'message': 'Order already paid and confirmed (idempotent replay)',
        'order_id': order.id,
        'status': order.status.value,
      };
    }

    if (!order.status.canTransitionTo(OrderStatus.confirmed)) {
      throw Exception('Invalid state transition from ${order.status.value} to confirmed');
    }

    // Update payment
    final pIndex = _payments.indexWhere((p) => p.orderId == orderId);
    if (pIndex != -1) {
      _payments[pIndex] = PaymentRecord(
        id: _payments[pIndex].id,
        orderId: orderId,
        provider: 'razorpay',
        providerOrderId: _payments[pIndex].providerOrderId,
        providerPaymentId: providerPaymentId,
        amount: _payments[pIndex].amount,
        currency: _payments[pIndex].currency,
        status: PaymentStatus.captured,
        method: method,
        signatureVerified: true,
        createdAt: _payments[pIndex].createdAt,
        updatedAt: DateTime.now(),
      );
    }

    // Consume reservations
    for (var i = 0; i < _reservations.length; i++) {
      if (_reservations[i]['order_id'] == orderId && _reservations[i]['status'] == 'reserved') {
        _reservations[i]['status'] = 'consumed';
        _inventoryLedger.add({
          'id': _uuid.v4(),
          'product_id': _reservations[i]['product_id'],
          'order_id': orderId,
          'reservation_id': _reservations[i]['id'],
          'change_type': 'purchase_committed',
          'quantity_change': 0,
          'reason': 'Payment verified. Inventory consumption committed.',
          'created_at': DateTime.now(),
        });
      }
    }

    // Transition Order
    _orders[index] = order.copyWith(
      status: OrderStatus.confirmed,
      paymentStatus: PaymentStatus.captured,
      updatedAt: DateTime.now(),
    );

    _ordersStreamController.add(List.unmodifiable(_orders));
    return {
      'success': true,
      'order_id': orderId,
      'order_number': order.orderNumber,
      'status': OrderStatus.confirmed.value,
      'payment_status': PaymentStatus.captured.value,
    };
  }

  /// Safe payment failure handler restoring held stock
  Future<Map<String, dynamic>> handlePaymentFailure({
    required String orderId,
    String reason = 'Payment cancelled or failed',
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return {'success': false, 'message': 'Order not found'};

    final order = _orders[index];
    if (order.status == OrderStatus.confirmed || order.status == OrderStatus.completed) {
      return {'success': false, 'message': 'Order already confirmed'};
    }

    // Release reservations and restore product stock
    for (var i = 0; i < _reservations.length; i++) {
      if (_reservations[i]['order_id'] == orderId && _reservations[i]['status'] == 'reserved') {
        final productId = _reservations[i]['product_id'] as int;
        final qty = _reservations[i]['quantity'] as int;

        final prod = DemoDataService.products.firstWhere((p) => p.id == productId);
        final stockBefore = prod.stockQuantity;
        final stockAfter = stockBefore + qty;
        DemoDataService.updateDemoProduct(productId, {'stock_quantity': stockAfter});

        _reservations[i]['status'] = 'released';
        _reservations[i]['released_at'] = DateTime.now();

        _inventoryLedger.add({
          'id': _uuid.v4(),
          'product_id': productId,
          'order_id': orderId,
          'reservation_id': _reservations[i]['id'],
          'change_type': 'reservation_released',
          'quantity_change': qty,
          'stock_before': stockBefore,
          'stock_after': stockAfter,
          'reason': 'Payment failed: $reason',
          'created_at': DateTime.now(),
        });
      }
    }

    _orders[index] = order.copyWith(
      status: OrderStatus.paymentFailed,
      paymentStatus: PaymentStatus.failed,
      updatedAt: DateTime.now(),
    );

    _ordersStreamController.add(List.unmodifiable(_orders));
    return {'success': true, 'order_id': orderId, 'status': 'payment_failed'};
  }

  /// Automated Sweeper for Expired Reservations (Bounded Batching)
  Future<int> expireReservations({int batchSize = 50}) async {
    final now = DateTime.now();
    int count = 0;
    final maxBatch = batchSize.clamp(1, 100);

    for (var i = 0; i < _reservations.length; i++) {
      if (count >= maxBatch) break;
      final res = _reservations[i];
      if (res['status'] == 'reserved' && (res['expires_at'] as DateTime).isBefore(now)) {
        final productId = res['product_id'] as int;
        final qty = res['quantity'] as int;
        final orderId = res['order_id'] as String?;

        final prod = DemoDataService.products.firstWhere((p) => p.id == productId);
        final stockBefore = prod.stockQuantity;
        final stockAfter = stockBefore + qty;
        DemoDataService.updateDemoProduct(productId, {'stock_quantity': stockAfter});

        res['status'] = 'expired';
        res['released_at'] = now;

        _inventoryLedger.add({
          'id': _uuid.v4(),
          'product_id': productId,
          'order_id': orderId,
          'reservation_id': res['id'],
          'change_type': 'reservation_expired',
          'quantity_change': qty,
          'stock_before': stockBefore,
          'stock_after': stockAfter,
          'reason': 'Reservation timed out after 15 minutes',
          'created_at': now,
        });

        if (orderId != null) {
          final oIdx = _orders.indexWhere((o) => o.id == orderId);
          if (oIdx != -1 && _orders[oIdx].status == OrderStatus.pendingPayment) {
            _orders[oIdx] = _orders[oIdx].copyWith(
              status: OrderStatus.cancelled,
              updatedAt: now,
            );
          }
        }
        count++;
      }
    }

    if (count > 0) {
      _ordersStreamController.add(List.unmodifiable(_orders));
    }
    return count;
  }

  /// Admin Refund execution with optional Restock
  Future<Map<String, dynamic>> processRefund({
    required String orderId,
    required double amount,
    required String reason,
    bool restock = false,
    String? idempotencyKey,
  }) async {
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      final existing = _refunds.where((r) => r.idempotencyKey == idempotencyKey).firstOrNull;
      if (existing != null) {
        return {
          'success': true,
          'refund_id': existing.id,
          'amount': existing.amount,
          'status': existing.status,
          'message': 'Refund already processed (idempotent replay)',
        };
      }
    }

    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) throw Exception('Order not found');

    final order = _orders[index];
    if (amount <= 0 || amount > order.grandTotal) {
      throw Exception('Invalid refund amount: $amount');
    }

    final refundId = _uuid.v4();
    final providerRefundId = 'rfnd_${_uuid.v4().replaceAll('-', '').substring(0, 14)}';

    final refund = RefundRecord(
      id: refundId,
      paymentId: 'demo-pay-ref',
      orderId: orderId,
      providerRefundId: providerRefundId,
      amount: amount,
      status: 'processed',
      restocked: restock,
      reason: reason,
      idempotencyKey: idempotencyKey,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _refunds.add(refund);

    // Restock if requested
    if (restock) {
      for (final item in order.items) {
        if (item.productId != null) {
          final prod = DemoDataService.products.firstWhere((p) => p.id == item.productId);
          final stockBefore = prod.stockQuantity;
          final stockAfter = stockBefore + item.quantity;
          DemoDataService.updateDemoProduct(item.productId!, {'stock_quantity': stockAfter});

          _inventoryLedger.add({
            'id': _uuid.v4(),
            'product_id': item.productId!,
            'order_id': orderId,
            'change_type': 'refund_restock',
            'quantity_change': item.quantity,
            'stock_before': stockBefore,
            'stock_after': stockAfter,
            'reason': 'Admin restocked on refund: $reason',
            'created_at': DateTime.now(),
          });
        }
      }
    }

    final newStatus = (amount >= order.grandTotal) ? OrderStatus.refunded : OrderStatus.partiallyRefunded;
    final newPaymentStatus = (amount >= order.grandTotal) ? PaymentStatus.refunded : PaymentStatus.partiallyRefunded;

    _orders[index] = order.copyWith(
      status: newStatus,
      paymentStatus: newPaymentStatus,
      updatedAt: DateTime.now(),
    );

    _ordersStreamController.add(List.unmodifiable(_orders));
    return {
      'success': true,
      'refund_id': refundId,
      'provider_refund_id': providerRefundId,
      'amount': amount,
      'status': 'processed',
      'restocked': restock,
    };
  }

  /// Admin Operational Status Transition
  Future<void> adminUpdateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    String notes = '',
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) throw Exception('Order not found');

    final order = _orders[index];

    // Check state machine
    if (!order.status.canTransitionTo(newStatus)) {
      throw Exception('Cannot transition order from ${order.status.value} to ${newStatus.value}');
    }

    // Security: Admin cannot manually fake payment
    if (newStatus == OrderStatus.paid) {
      throw Exception('Payment state cannot be manually modified by admin. Must verify via payment provider.');
    }

    _orders[index] = order.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );

    _ordersStreamController.add(List.unmodifiable(_orders));
  }

  /// Concurrency-safe stock adjustment
  Future<int> adminAdjustStock({
    required int productId,
    required int delta,
    required String reason,
  }) async {
    final prod = DemoDataService.products.firstWhere((p) => p.id == productId);
    final stockBefore = prod.stockQuantity;
    final stockAfter = stockBefore + delta;
    if (stockAfter < 0) {
      throw Exception('Stock cannot be adjusted below 0 (target: $stockAfter)');
    }

    DemoDataService.updateDemoProduct(productId, {'stock_quantity': stockAfter});

    _inventoryLedger.add({
      'id': _uuid.v4(),
      'product_id': productId,
      'change_type': 'admin_adjustment',
      'quantity_change': delta,
      'stock_before': stockBefore,
      'stock_after': stockAfter,
      'reason': reason,
      'created_at': DateTime.now(),
    });

    return stockAfter;
  }

  /// High-fidelity webhook processing with deduplication check
  Future<Map<String, dynamic>> processPaymentWebhook({
    required String providerEventId,
    required String eventType,
    required String orderId,
    required String providerPaymentId,
    Map<String, dynamic>? payload,
  }) async {
    // 1. Deduplication check
    if (_paymentEvents.containsKey(providerEventId)) {
      return {
        'success': true,
        'duplicate': true,
        'message': 'Webhook event already processed (idempotent replay)',
        'provider_event_id': providerEventId,
      };
    }

    _paymentEvents[providerEventId] = {
      'event_id': _uuid.v4(),
      'event_type': eventType,
      'order_id': orderId,
      'provider_payment_id': providerPaymentId,
      'payload': payload ?? {},
      'processed_at': DateTime.now(),
    };

    if (eventType == 'payment.captured' || eventType == 'order.paid') {
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index == -1) {
        return {
          'success': false,
          'message': 'Order not found for webhook event',
          'order_id': orderId,
        };
      }

      final order = _orders[index];
      if (order.status == OrderStatus.confirmed || order.status == OrderStatus.completed) {
        return {
          'success': true,
          'duplicate': false,
          'message': 'Order already paid and confirmed',
          'order_id': orderId,
          'status': order.status.value,
        };
      }

      // Update payment
      final pIndex = _payments.indexWhere((p) => p.orderId == orderId);
      if (pIndex != -1) {
        _payments[pIndex] = PaymentRecord(
          id: _payments[pIndex].id,
          orderId: orderId,
          provider: 'razorpay',
          providerOrderId: _payments[pIndex].providerOrderId,
          providerPaymentId: providerPaymentId,
          amount: _payments[pIndex].amount,
          currency: _payments[pIndex].currency,
          status: PaymentStatus.captured,
          method: 'webhook',
          signatureVerified: true,
          createdAt: _payments[pIndex].createdAt,
          updatedAt: DateTime.now(),
        );
      }

      // Consume reservations
      for (var i = 0; i < _reservations.length; i++) {
        if (_reservations[i]['order_id'] == orderId && _reservations[i]['status'] == 'reserved') {
          _reservations[i]['status'] = 'consumed';
          _inventoryLedger.add({
            'id': _uuid.v4(),
            'product_id': _reservations[i]['product_id'],
            'order_id': orderId,
            'reservation_id': _reservations[i]['id'],
            'change_type': 'purchase_committed',
            'quantity_change': 0,
            'reason': 'Webhook payment verified. Inventory consumption confirmed.',
            'created_at': DateTime.now(),
          });
        }
      }

      // Transition order
      _orders[index] = order.copyWith(
        status: OrderStatus.confirmed,
        paymentStatus: PaymentStatus.captured,
        updatedAt: DateTime.now(),
      );

      _ordersStreamController.add(List.unmodifiable(_orders));
      return {
        'success': true,
        'duplicate': false,
        'order_id': orderId,
        'status': 'confirmed',
        'provider_event_id': providerEventId,
      };
    } else if (eventType == 'payment.failed') {
      await handlePaymentFailure(orderId: orderId, reason: 'Payment failed via webhook');
      return {
        'success': true,
        'duplicate': false,
        'order_id': orderId,
        'status': 'payment_failed',
      };
    }

    return {
      'success': true,
      'duplicate': false,
      'message': 'Webhook event logged',
    };
  }

  /// System data consistency and health check
  Future<Map<String, dynamic>> reconcileSystemData() async {
    final cleanedReservations = await expireReservations();
    int negativeStock = 0;
    for (final p in DemoDataService.products) {
      if (p.stockQuantity < 0) negativeStock++;
    }

    return {
      'success': true,
      'reconciled_at': DateTime.now().toIso8601String(),
      'expired_reservations_cleaned': cleanedReservations,
      'stuck_payments_failed': 0,
      'negative_stock_anomalies': negativeStock,
      'dead_letter_outbox_count': 0,
    };
  }
}
