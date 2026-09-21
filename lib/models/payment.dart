import 'package:opem/models/order_v2.dart';

/// Payment Record tracking provider, amount, signature verification, and lifecycle.
class PaymentRecord {
  final String id;
  final String orderId;
  final String provider;
  final String? providerOrderId;
  final String? providerPaymentId;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final String method;
  final bool signatureVerified;
  final Map<String, dynamic> rawResponse;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentRecord({
    required this.id,
    required this.orderId,
    this.provider = 'razorpay',
    this.providerOrderId,
    this.providerPaymentId,
    required this.amount,
    this.currency = 'INR',
    required this.status,
    this.method = '',
    this.signatureVerified = false,
    this.rawResponse = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      provider: (json['provider'] ?? 'razorpay') as String,
      providerOrderId: json['provider_order_id'] as String?,
      providerPaymentId: json['provider_payment_id'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: (json['currency'] ?? 'INR') as String,
      status: PaymentStatus.fromString((json['status'] ?? 'created') as String),
      method: (json['method'] ?? '') as String,
      signatureVerified: (json['signature_verified'] as bool?) ?? false,
      rawResponse: (json['raw_response'] is Map<String, dynamic>)
          ? json['raw_response'] as Map<String, dynamic>
          : {},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'provider': provider,
        'provider_order_id': providerOrderId,
        'provider_payment_id': providerPaymentId,
        'amount': amount,
        'currency': currency,
        'status': status.value,
        'method': method,
        'signature_verified': signatureVerified,
        'raw_response': rawResponse,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// Refund Record documenting admin refunds and restocking.
class RefundRecord {
  final String id;
  final String paymentId;
  final String orderId;
  final String? providerRefundId;
  final double amount;
  final String status;
  final bool restocked;
  final String reason;
  final String? idempotencyKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RefundRecord({
    required this.id,
    required this.paymentId,
    required this.orderId,
    this.providerRefundId,
    required this.amount,
    this.status = 'processed',
    this.restocked = false,
    this.reason = '',
    this.idempotencyKey,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RefundRecord.fromJson(Map<String, dynamic> json) {
    return RefundRecord(
      id: json['id'] as String,
      paymentId: json['payment_id'] as String,
      orderId: json['order_id'] as String,
      providerRefundId: json['provider_refund_id'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: (json['status'] ?? 'processed') as String,
      restocked: (json['restocked'] as bool?) ?? false,
      reason: (json['reason'] ?? '') as String,
      idempotencyKey: json['idempotency_key'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
