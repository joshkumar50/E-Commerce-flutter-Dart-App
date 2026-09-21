import 'package:flutter/material.dart';
import 'package:opem/core/theme.dart';
import 'package:opem/models/order_v2.dart';
import 'package:opem/services/order_service.dart';
import 'package:opem/utils/formatters.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final OrderV2? initialOrder;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderV2? _order;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    if (_order == null) {
      _loadOrder();
    }
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);
    final order = await orderService.getOrder(widget.orderId);
    if (mounted) {
      setState(() {
        _order = order;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final order = _order;
    if (order == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(
          child: Text('Order not found', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(order.orderNumber),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── 1. Status Banner ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: order.status.badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: order.status.badgeColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  order.status == OrderStatus.completed
                      ? Icons.check_circle
                      : (order.status == OrderStatus.cancelled || order.status == OrderStatus.paymentFailed
                          ? Icons.cancel
                          : Icons.hourglass_top),
                  color: order.status.badgeColor,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.status.label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: order.status.badgeColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Placed on ${AppFormatters.formatDateTime(order.createdAt)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── 2. Line Items Snapshot ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Items (${order.items.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Divider(height: 16, color: AppColors.borderLight),
                ...order.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.imageUrlSnapshot,
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 46,
                              height: 46,
                              color: AppColors.surfaceMuted,
                              child: const Icon(Icons.local_grocery_store, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productNameSnapshot,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.quantity} x ₹${item.unitPrice.toStringAsFixed(2)} • ${item.unitSnapshot}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${item.lineTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── 3. Delivery Address Snapshot ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Delivery Address Snapshot',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  order.shippingAddress.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.shippingAddress.addressLine1}${order.shippingAddress.addressLine2.isNotEmpty ? ', ${order.shippingAddress.addressLine2}' : ''}\n${order.shippingAddress.city}, ${order.shippingAddress.state} - ${order.shippingAddress.postalCode}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
                ),
                const SizedBox(height: 4),
                Text(
                  'Phone: ${order.shippingAddress.phone}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                if (order.notes.isNotEmpty) ...[
                  const Divider(height: 16, color: AppColors.borderLight),
                  Text(
                    'Notes: ${order.notes}',
                    style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── 4. Price & Payment Summary ───────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Summary',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),
                _SummaryRow(title: 'Item Subtotal', value: '₹${order.subtotal.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                _SummaryRow(
                  title: 'Delivery Fee',
                  value: order.deliveryFee == 0.0 ? 'FREE' : '₹${order.deliveryFee.toStringAsFixed(2)}',
                  valueColor: order.deliveryFee == 0.0 ? AppColors.primary : null,
                ),
                const SizedBox(height: 8),
                _SummaryRow(title: 'Taxes / GST', value: '₹${order.taxTotal.toStringAsFixed(2)}'),
                if (order.discountTotal > 0) ...[
                  const SizedBox(height: 8),
                  _SummaryRow(
                    title: 'Discount',
                    value: '-₹${order.discountTotal.toStringAsFixed(2)}',
                    valueColor: AppColors.saleRed,
                  ),
                ],
                const Divider(height: 24, color: AppColors.border),
                _SummaryRow(
                  title: 'Grand Total',
                  value: '₹${order.grandTotal.toStringAsFixed(2)}',
                  isBold: true,
                  valueColor: AppColors.primary,
                ),
                const SizedBox(height: 8),
                _SummaryRow(
                  title: 'Payment Status',
                  value: order.paymentStatus.label,
                  valueColor: order.paymentStatus == PaymentStatus.captured ? AppColors.primary : AppColors.accent,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String title;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _SummaryRow({
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
        Text(
          title,
          style: TextStyle(
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 17 : 13,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
