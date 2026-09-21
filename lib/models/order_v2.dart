import 'package:flutter/material.dart';
import 'package:opem/core/theme.dart';

/// Explicit Finite State Machine for Orders.
enum OrderStatus {
  pendingPayment('pending_payment', 'Pending Payment'),
  paymentProcessing('payment_processing', 'Processing Payment'),
  paid('paid', 'Paid'),
  paymentFailed('payment_failed', 'Payment Failed'),
  cancelled('cancelled', 'Cancelled'),
  confirmed('confirmed', 'Confirmed'),
  completed('completed', 'Completed'),
  refundPending('refund_pending', 'Refund Pending'),
  refunded('refunded', 'Refunded'),
  partiallyRefunded('partially_refunded', 'Partially Refunded');

  final String value;
  final String label;
  const OrderStatus(this.value, this.label);

  static OrderStatus fromString(String val) {
    return OrderStatus.values.firstWhere(
      (e) => e.value == val,
      orElse: () => OrderStatus.pendingPayment,
    );
  }

  /// Finite State Machine validation: ensures transitions cannot be arbitrarily skipped or corrupted.
  bool canTransitionTo(OrderStatus next) {
    if (this == next) return true;
    switch (this) {
      case OrderStatus.pendingPayment:
        return next == OrderStatus.paymentProcessing ||
            next == OrderStatus.paid ||
            next == OrderStatus.confirmed ||
            next == OrderStatus.paymentFailed ||
            next == OrderStatus.cancelled;
      case OrderStatus.paymentProcessing:
        return next == OrderStatus.paid ||
            next == OrderStatus.confirmed ||
            next == OrderStatus.paymentFailed ||
            next == OrderStatus.cancelled;
      case OrderStatus.paid:
        return next == OrderStatus.confirmed ||
            next == OrderStatus.refundPending ||
            next == OrderStatus.refunded ||
            next == OrderStatus.partiallyRefunded;
      case OrderStatus.confirmed:
        return next == OrderStatus.completed ||
            next == OrderStatus.cancelled ||
            next == OrderStatus.refundPending ||
            next == OrderStatus.refunded ||
            next == OrderStatus.partiallyRefunded;
      case OrderStatus.completed:
        return next == OrderStatus.refundPending ||
            next == OrderStatus.refunded ||
            next == OrderStatus.partiallyRefunded;
      case OrderStatus.refundPending:
        return next == OrderStatus.refunded ||
            next == OrderStatus.partiallyRefunded;
      case OrderStatus.paymentFailed:
      case OrderStatus.cancelled:
      case OrderStatus.refunded:
      case OrderStatus.partiallyRefunded:
        return false; // Terminal or restricted states
    }
  }

  Color get badgeColor {
    switch (this) {
      case OrderStatus.pendingPayment:
      case OrderStatus.paymentProcessing:
        return AppColors.accent;
      case OrderStatus.paid:
      case OrderStatus.confirmed:
        return AppColors.primary;
      case OrderStatus.completed:
        return const Color(0xFF10B981);
      case OrderStatus.paymentFailed:
      case OrderStatus.cancelled:
        return AppColors.saleRed;
      case OrderStatus.refundPending:
      case OrderStatus.partiallyRefunded:
        return Colors.orange;
      case OrderStatus.refunded:
        return Colors.purple;
    }
  }
}

/// Explicit Finite State Machine for Payments.
enum PaymentStatus {
  created('created', 'Created'),
  pending('pending', 'Pending'),
  authorized('authorized', 'Authorized'),
  captured('captured', 'Captured'),
  failed('failed', 'Failed'),
  cancelled('cancelled', 'Cancelled'),
  refunded('refunded', 'Refunded'),
  partiallyRefunded('partially_refunded', 'Partially Refunded');

  final String value;
  final String label;
  const PaymentStatus(this.value, this.label);

  static PaymentStatus fromString(String val) {
    return PaymentStatus.values.firstWhere(
      (e) => e.value == val,
      orElse: () => PaymentStatus.created,
    );
  }

  bool canTransitionTo(PaymentStatus next) {
    if (this == next) return true;
    switch (this) {
      case PaymentStatus.created:
        return next == PaymentStatus.pending ||
            next == PaymentStatus.authorized ||
            next == PaymentStatus.captured ||
            next == PaymentStatus.failed ||
            next == PaymentStatus.cancelled;
      case PaymentStatus.pending:
      case PaymentStatus.authorized:
        return next == PaymentStatus.captured ||
            next == PaymentStatus.failed ||
            next == PaymentStatus.cancelled;
      case PaymentStatus.captured:
        return next == PaymentStatus.refunded ||
            next == PaymentStatus.partiallyRefunded;
      case PaymentStatus.failed:
      case PaymentStatus.cancelled:
      case PaymentStatus.refunded:
      case PaymentStatus.partiallyRefunded:
        return false;
    }
  }
}

/// Immutable Shipping Address Snapshot stored on the Order.
class AddressSnapshot {
  final String? addressId;
  final String label;
  final String fullName;
  final String phone;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String postalCode;
  final String country;

  const AddressSnapshot({
    this.addressId,
    required this.label,
    required this.fullName,
    required this.phone,
    required this.addressLine1,
    this.addressLine2 = '',
    required this.city,
    required this.state,
    required this.postalCode,
    this.country = 'India',
  });

  factory AddressSnapshot.fromJson(Map<String, dynamic> json) {
    return AddressSnapshot(
      addressId: json['address_id'] as String?,
      label: (json['label'] ?? 'Home') as String,
      fullName: (json['full_name'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      addressLine1: (json['address_line1'] ?? '') as String,
      addressLine2: (json['address_line2'] ?? '') as String,
      city: (json['city'] ?? '') as String,
      state: (json['state'] ?? '') as String,
      postalCode: (json['postal_code'] ?? '') as String,
      country: (json['country'] ?? 'India') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'address_id': addressId,
        'label': label,
        'full_name': fullName,
        'phone': phone,
        'address_line1': addressLine1,
        'address_line2': addressLine2,
        'city': city,
        'state': state,
        'postal_code': postalCode,
        'country': country,
      };

  String get formatted {
    final buffer = StringBuffer();
    buffer.writeln(fullName);
    buffer.writeln(phone);
    buffer.write(addressLine1);
    if (addressLine2.isNotEmpty) buffer.write(', $addressLine2');
    buffer.writeln();
    buffer.write('$city, $state - $postalCode');
    return buffer.toString();
  }
}

/// Immutable Pricing Calculation Snapshot stored on the Order.
class PricingSnapshot {
  final double subtotal;
  final double discountTotal;
  final double deliveryFee;
  final double taxTotal;
  final double grandTotal;
  final String currency;
  final int itemCount;
  final DateTime calculatedAt;

  const PricingSnapshot({
    required this.subtotal,
    required this.discountTotal,
    required this.deliveryFee,
    required this.taxTotal,
    required this.grandTotal,
    this.currency = 'INR',
    required this.itemCount,
    required this.calculatedAt,
  });

  factory PricingSnapshot.fromJson(Map<String, dynamic> json) {
    return PricingSnapshot(
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountTotal: (json['discount_total'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      taxTotal: (json['tax_total'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0.0,
      currency: (json['currency'] ?? 'INR') as String,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      calculatedAt: json['calculated_at'] != null
          ? DateTime.tryParse(json['calculated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'subtotal': subtotal,
        'discount_total': discountTotal,
        'delivery_fee': deliveryFee,
        'tax_total': taxTotal,
        'grand_total': grandTotal,
        'currency': currency,
        'item_count': itemCount,
        'calculated_at': calculatedAt.toIso8601String(),
      };
}

/// Order Line Item preserving product snapshot at purchase time.
class OrderItem {
  final String id;
  final String orderId;
  final int? productId;
  final String productNameSnapshot;
  final String unitSnapshot;
  final String imageUrlSnapshot;
  final double unitPrice;
  final int quantity;
  final double lineTotal;
  final DateTime createdAt;

  const OrderItem({
    required this.id,
    required this.orderId,
    this.productId,
    required this.productNameSnapshot,
    required this.unitSnapshot,
    required this.imageUrlSnapshot,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    required this.createdAt,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productId: (json['product_id'] as num?)?.toInt(),
      productNameSnapshot: (json['product_name_snapshot'] ?? '') as String,
      unitSnapshot: (json['unit_snapshot'] ?? 'item') as String,
      imageUrlSnapshot: (json['image_url_snapshot'] ?? '') as String,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'product_id': productId,
        'product_name_snapshot': productNameSnapshot,
        'unit_snapshot': unitSnapshot,
        'image_url_snapshot': imageUrlSnapshot,
        'unit_price': unitPrice,
        'quantity': quantity,
        'line_total': lineTotal,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Production-quality Grocery Order Model with immutable historical snapshots.
class OrderV2 {
  final String id;
  final String orderNumber;
  final String userId;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final String currency;
  final double subtotal;
  final double discountTotal;
  final double deliveryFee;
  final double taxTotal;
  final double grandTotal;
  final AddressSnapshot shippingAddress;
  final PricingSnapshot pricingSnapshot;
  final String? idempotencyKey;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem> items;

  const OrderV2({
    required this.id,
    required this.orderNumber,
    required this.userId,
    required this.status,
    required this.paymentStatus,
    this.currency = 'INR',
    required this.subtotal,
    this.discountTotal = 0.0,
    this.deliveryFee = 0.0,
    this.taxTotal = 0.0,
    required this.grandTotal,
    required this.shippingAddress,
    required this.pricingSnapshot,
    this.idempotencyKey,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  factory OrderV2.fromJson(Map<String, dynamic> json, {List<OrderItem> items = const []}) {
    return OrderV2(
      id: json['id'] as String,
      orderNumber: (json['order_number'] ?? '') as String,
      userId: (json['user_id'] ?? '') as String,
      status: OrderStatus.fromString((json['status'] ?? 'pending_payment') as String),
      paymentStatus: PaymentStatus.fromString((json['payment_status'] ?? 'created') as String),
      currency: (json['currency'] ?? 'INR') as String,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountTotal: (json['discount_total'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      taxTotal: (json['tax_total'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0.0,
      shippingAddress: json['shipping_address_snapshot'] is Map<String, dynamic>
          ? AddressSnapshot.fromJson(json['shipping_address_snapshot'] as Map<String, dynamic>)
          : const AddressSnapshot(
              label: 'Address',
              fullName: 'Customer',
              phone: '',
              addressLine1: '',
              city: '',
              state: '',
              postalCode: '',
            ),
      pricingSnapshot: json['pricing_snapshot'] is Map<String, dynamic>
          ? PricingSnapshot.fromJson(json['pricing_snapshot'] as Map<String, dynamic>)
          : PricingSnapshot(
              subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
              discountTotal: (json['discount_total'] as num?)?.toDouble() ?? 0.0,
              deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
              taxTotal: (json['tax_total'] as num?)?.toDouble() ?? 0.0,
              grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0.0,
              itemCount: items.length,
              calculatedAt: DateTime.now(),
            ),
      idempotencyKey: json['idempotency_key'] as String?,
      notes: (json['notes'] ?? '') as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      items: items,
    );
  }

  OrderV2 copyWith({
    OrderStatus? status,
    PaymentStatus? paymentStatus,
    List<OrderItem>? items,
    DateTime? updatedAt,
  }) {
    return OrderV2(
      id: id,
      orderNumber: orderNumber,
      userId: userId,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      currency: currency,
      subtotal: subtotal,
      discountTotal: discountTotal,
      deliveryFee: deliveryFee,
      taxTotal: taxTotal,
      grandTotal: grandTotal,
      shippingAddress: shippingAddress,
      pricingSnapshot: pricingSnapshot,
      idempotencyKey: idempotencyKey,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      items: items ?? this.items,
    );
  }
}
