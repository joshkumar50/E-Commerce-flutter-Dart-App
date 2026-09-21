import 'package:flutter/material.dart';
import 'package:opem/core/admin_theme.dart';
import 'package:opem/models/order_v2.dart';
import 'package:opem/services/order_service.dart';
import 'package:opem/utils/formatters.dart';
import 'package:uuid/uuid.dart';

class AdminOrderDetailScreen extends StatefulWidget {
  final OrderV2 order;

  const AdminOrderDetailScreen({super.key, required this.order});

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  late OrderV2 _order;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _updateStatus(OrderStatus newStatus) async {
    setState(() => _isProcessing = true);
    try {
      await orderService.adminUpdateOrderStatus(
        orderId: _order.id,
        newStatus: newStatus,
        notes: 'Status updated to ${newStatus.label} by Store Admin',
      );
      final refreshed = await orderService.getOrder(_order.id);
      if (mounted) {
        setState(() {
          if (refreshed != null) _order = refreshed;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order marked as ${newStatus.label}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AdminColors.error,
          ),
        );
      }
    }
  }

  void _showRefundDialog() {
    final amountController = TextEditingController(text: _order.grandTotal.toStringAsFixed(2));
    final reasonController = TextEditingController();
    bool restock = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.currency_rupee, color: AdminColors.primary),
                  SizedBox(width: 8),
                  Text('Process Refund'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${_order.orderNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Refund Amount (₹)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason for Refund',
                        hintText: 'e.g. Out of stock / Quality defect',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: restock,
                      onChanged: (val) => setDialogState(() => restock = val ?? true),
                      title: const Text('Restock products to inventory', style: TextStyle(fontSize: 13)),
                      subtitle: const Text(
                        'Atomically restores product stock and writes an audit ledger entry',
                        style: TextStyle(fontSize: 11, color: AdminColors.textMuted),
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                    final reason = reasonController.text.trim();

                    if (amount <= 0 || amount > _order.grandTotal) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid refund amount')),
                      );
                      return;
                    }

                    if (reason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a refund reason')),
                      );
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(dialogContext);
                    setState(() => _isProcessing = true);

                    try {
                      final idempotencyKey = const Uuid().v4();
                      await orderService.processRefund(
                        orderId: _order.id,
                        amount: amount,
                        reason: reason,
                        restock: restock,
                        idempotencyKey: idempotencyKey,
                      );

                      final refreshed = await orderService.getOrder(_order.id);
                      if (mounted) {
                        setState(() {
                          if (refreshed != null) _order = refreshed;
                          _isProcessing = false;
                        });
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Refund of ₹${amount.toStringAsFixed(2)} processed successfully${restock ? ' (Items restocked)' : ''}',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() => _isProcessing = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Refund failed: $e'),
                            backgroundColor: AdminColors.error,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AdminColors.error),
                  child: const Text('Confirm Refund'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: Text(_order.orderNumber),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Status & Quick Actions Card ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Operational Status',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _order.status.badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _order.status.badgeColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _order.status.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _order.status.badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Placed: ${AppFormatters.formatDateTime(_order.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                ),
                const SizedBox(height: 16),

                // Operational Action Buttons
                if (_isProcessing)
                  const Center(child: CircularProgressIndicator())
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_order.status == OrderStatus.confirmed)
                        ElevatedButton.icon(
                          onPressed: () => _updateStatus(OrderStatus.completed),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Mark Completed'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                        ),
                      if (_order.status == OrderStatus.confirmed || _order.status == OrderStatus.pendingPayment)
                        OutlinedButton.icon(
                          onPressed: () => _updateStatus(OrderStatus.cancelled),
                          icon: const Icon(Icons.close, size: 16, color: AdminColors.error),
                          label: const Text('Cancel Order', style: TextStyle(color: AdminColors.error)),
                        ),
                      if ((_order.status == OrderStatus.confirmed || _order.status == OrderStatus.completed) &&
                          _order.paymentStatus == PaymentStatus.captured)
                        OutlinedButton.icon(
                          onPressed: _showRefundDialog,
                          icon: const Icon(Icons.currency_rupee, size: 16, color: Colors.orange),
                          label: const Text('Issue Refund', style: TextStyle(color: Colors.orange)),
                        ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── Customer & Shipping Address Snapshot ─────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person, size: 18, color: AdminColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Customer & Delivery Address',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _order.shippingAddress.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_order.shippingAddress.addressLine1}${_order.shippingAddress.addressLine2.isNotEmpty ? ', ${_order.shippingAddress.addressLine2}' : ''}\n${_order.shippingAddress.city}, ${_order.shippingAddress.state} - ${_order.shippingAddress.postalCode}',
                  style: const TextStyle(fontSize: 13, color: AdminColors.textSecondary, height: 1.3),
                ),
                const SizedBox(height: 4),
                Text(
                  'Phone: ${_order.shippingAddress.phone}',
                  style: const TextStyle(fontSize: 12, color: AdminColors.textMuted),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── Line Items Snapshot ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Purchased Items (${_order.items.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Divider(height: 16, color: AdminColors.surfaceMuted),
                ..._order.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: item.imageUrlSnapshot.isNotEmpty
                              ? Image.network(
                                  item.imageUrlSnapshot,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 40,
                                    height: 40,
                                    color: AdminColors.surfaceMuted,
                                    child: const Icon(Icons.shopping_basket, size: 20),
                                  ),
                                )
                              : Container(
                                  width: 40,
                                  height: 40,
                                  color: AdminColors.surfaceMuted,
                                  child: const Icon(Icons.shopping_basket, size: 20),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productNameSnapshot,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                '${item.quantity} x ₹${item.unitPrice.toStringAsFixed(2)} • ${item.unitSnapshot}',
                                style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${item.lineTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── Financial Snapshot ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Financial Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 10),
                _AdminSummaryRow(title: 'Subtotal', value: '₹${_order.subtotal.toStringAsFixed(2)}'),
                const SizedBox(height: 6),
                _AdminSummaryRow(title: 'Delivery Fee', value: '₹${_order.deliveryFee.toStringAsFixed(2)}'),
                const SizedBox(height: 6),
                _AdminSummaryRow(title: 'Taxes / GST', value: '₹${_order.taxTotal.toStringAsFixed(2)}'),
                const Divider(height: 20, color: AdminColors.surfaceMuted),
                _AdminSummaryRow(
                  title: 'Grand Total',
                  value: '₹${_order.grandTotal.toStringAsFixed(2)}',
                  isBold: true,
                  valueColor: AdminColors.primary,
                ),
                const SizedBox(height: 6),
                _AdminSummaryRow(
                  title: 'Payment Status',
                  value: _order.paymentStatus.label,
                  valueColor: _order.paymentStatus == PaymentStatus.captured ? AdminColors.primary : Colors.orange,
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

class _AdminSummaryRow extends StatelessWidget {
  final String title;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _AdminSummaryRow({
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
            color: isBold ? AdminColors.textPrimary : AdminColors.textSecondary,
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 16 : 12,
            color: valueColor ?? AdminColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
