import 'dart:async';
import 'package:opem/demo/demo_transaction_service.dart';
import 'package:opem/services/auth_service.dart';
import 'package:opem/utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Service orchestrating the server-authoritative checkout and payment flow.
/// NEVER computes final prices or marks orders paid from the client.
class CheckoutService {
  static const _uuid = Uuid();

  /// Initiates server-authoritative checkout.
  /// Locks product rows server-side, checks stock, decrements inventory, and creates pending order.
  Future<Map<String, dynamic>> initiateCheckout({
    required String addressId,
    required List<Map<String, dynamic>> cartItems,
    String? idempotencyKey,
    String notes = '',
  }) async {
    final key = idempotencyKey ?? _uuid.v4();

    if (isDemoMode) {
      final user = authService.currentUser;
      final userId = user?.id ?? 'demo-user-123';
      return await DemoTransactionService.instance.createCheckout(
        userId: userId,
        addressId: addressId,
        cartItems: cartItems,
        idempotencyKey: key,
        notes: notes,
      );
    }

    // Supabase RPC execution
    final response = await Supabase.instance.client.rpc(
      'rpc_create_checkout',
      params: {
        'p_address_id': addressId,
        'p_cart_items': cartItems,
        'p_idempotency_key': key,
        'p_notes': notes,
      },
    );

    if (response is Map<String, dynamic>) {
      return response;
    } else {
      throw Exception('Unexpected response format from checkout RPC');
    }
  }

  /// Verifies payment server-side using Razorpay signature and consumes reserved inventory.
  Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String providerPaymentId,
    required String providerSignature,
    String paymentMethod = 'upi',
  }) async {
    if (isDemoMode) {
      return await DemoTransactionService.instance.verifyPayment(
        orderId: orderId,
        providerPaymentId: providerPaymentId,
        providerSignature: providerSignature,
        method: paymentMethod,
      );
    }

    final response = await Supabase.instance.client.rpc(
      'rpc_verify_payment',
      params: {
        'p_order_id': orderId,
        'p_provider_payment_id': providerPaymentId,
        'p_provider_signature': providerSignature,
        'p_payment_method': paymentMethod,
      },
    );

    if (response is Map<String, dynamic>) {
      return response;
    } else {
      throw Exception('Unexpected response format from payment verification RPC');
    }
  }

  /// Handles payment failure or user cancellation: safely releases reserved stock.
  Future<Map<String, dynamic>> handlePaymentFailure({
    required String orderId,
    String reason = 'Payment was cancelled or declined by user',
  }) async {
    if (isDemoMode) {
      return await DemoTransactionService.instance.handlePaymentFailure(
        orderId: orderId,
        reason: reason,
      );
    }

    final response = await Supabase.instance.client.rpc(
      'rpc_handle_payment_failure',
      params: {
        'p_order_id': orderId,
        'p_reason': reason,
      },
    );

    if (response is Map<String, dynamic>) {
      return response;
    } else {
      throw Exception('Failed to record payment cancellation');
    }
  }

  /// Sweeps and releases expired inventory holds (>15 minutes).
  Future<int> sweepExpiredReservations() async {
    if (isDemoMode) {
      return await DemoTransactionService.instance.expireReservations();
    }

    final response = await Supabase.instance.client.rpc('rpc_expire_reservations');
    if (response is Map<String, dynamic>) {
      return (response['expired_reservations_count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }
}

final checkoutService = CheckoutService();
