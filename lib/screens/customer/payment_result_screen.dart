import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:opem/core/router.dart';
import 'package:opem/core/theme.dart';

class PaymentResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;

  const PaymentResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final bool isSuccess = (result['success'] as bool?) ?? false;
    final String orderId = (result['order_id'] ?? '') as String;
    final String orderNumber = (result['order_number'] ?? 'ORD-UNKNOWN') as String;
    final double grandTotal = (result['grand_total'] as num?)?.toDouble() ?? 0.0;
    final String paymentId = (result['payment_id'] ?? '') as String;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isSuccess ? 'Order Confirmed' : 'Payment Failed'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Circle
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: isSuccess
                      ? AppColors.primaryLight.withValues(alpha: 0.5)
                      : AppColors.saleRedLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle : Icons.error_outline,
                  color: isSuccess ? AppColors.primary : AppColors.saleRed,
                  size: 54,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isSuccess ? 'Payment Successful!' : 'Payment Failed',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isSuccess
                    ? 'Your grocery order has been confirmed and placed with the store.'
                    : 'We could not verify your payment. Reserved inventory has been safely restored.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Transaction Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _DetailRow(title: 'Order Number', value: orderNumber),
                    const Divider(height: 16, color: AppColors.borderLight),
                    _DetailRow(title: 'Payment Status', value: isSuccess ? 'Captured' : 'Failed'),
                    const Divider(height: 16, color: AppColors.borderLight),
                    _DetailRow(title: 'Transaction Reference', value: paymentId.isNotEmpty ? paymentId : 'N/A'),
                    const Divider(height: 16, color: AppColors.borderLight),
                    _DetailRow(
                      title: 'Grand Total Paid',
                      value: '₹${grandTotal.toStringAsFixed(2)}',
                      isBold: true,
                      valueColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              if (isSuccess && orderId.isNotEmpty)
                ElevatedButton(
                  onPressed: () => context.go('${Routes.orders}/$orderId'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('View Order Details'),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go(Routes.home),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Continue Shopping'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String title;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _DetailRow({
    required this.title,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
