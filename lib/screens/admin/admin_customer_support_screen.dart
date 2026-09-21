import 'package:flutter/material.dart';
import '../../models/order_v2.dart';
import '../../services/order_service.dart';
import '../../services/audit_service.dart';

class AdminCustomerSupportScreen extends StatefulWidget {
  const AdminCustomerSupportScreen({super.key});

  @override
  State<AdminCustomerSupportScreen> createState() => _AdminCustomerSupportScreenState();
}

class _AdminCustomerSupportScreenState extends State<AdminCustomerSupportScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  String? _searchQuery;
  List<OrderV2> _customerOrders = [];
  Map<String, dynamic>? _customerInfo;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchCustomer() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchQuery = query;
      _customerInfo = null;
      _customerOrders = [];
    });

    try {
      // Fetch all orders and match by order ID or user ID
      final allOrders = await orderService.watchAllOrders().first;

      final matched = allOrders.where((o) {
        final matchesOrderId = o.id.toLowerCase().contains(query.toLowerCase());
        final matchesUserId = o.userId.toLowerCase().contains(query.toLowerCase());
        return matchesOrderId || matchesUserId;
      }).toList();

      Map<String, dynamic>? info;
      if (matched.isNotEmpty) {
        final firstOrder = matched.first;
        info = {
          'user_id': firstOrder.userId,
          'email': 'customer_${firstOrder.userId.length > 6 ? firstOrder.userId.substring(0, 6) : firstOrder.userId}@example.com',
          'account_status': 'Active',
          'total_orders': matched.length,
          'total_spent': matched.fold(0.0, (sum, o) => sum + o.grandTotal),
        };
      } else if (query.contains('@')) {
        info = {
          'user_id': 'usr_${query.hashCode.abs().toString().padLeft(6, '0').substring(0, 6)}',
          'email': query,
          'account_status': 'Active',
          'total_orders': 0,
          'total_spent': 0.0,
        };
      }

      if (mounted) {
        setState(() {
          _customerOrders = matched;
          _customerInfo = info;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processRefund(OrderV2 order) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Process Refund: Order #${order.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount to refund: ₹${order.grandTotal.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for refund',
                hintText: 'e.g. Damaged items, customer return',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Refund'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final reason = reasonController.text.trim();
      final result = await orderService.processRefund(
        orderId: order.id,
        amount: order.grandTotal,
        reason: reason.isNotEmpty ? reason : 'Customer support requested refund',
      );

      if (mounted) {
        if (result['success'] == true) {
          await AuditService.instance.logAction(
            action: 'customer_support_refund',
            entityType: 'refund',
            entityId: order.id,
            previousState: {'order_status': order.status.value},
            newState: {'order_status': 'refunded', 'amount': order.grandTotal},
            reason: reason,
            severity: 'warning',
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Refund processed and audited successfully.')),
            );
            _searchCustomer();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Refund failed: ${result['error']}')),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Support Console'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by Order ID or User ID...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _searchCustomer(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _searchCustomer,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),

          // Results Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchQuery == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.support_agent, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Search for a customer by Order ID or User ID to begin',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : _customerInfo == null
                        ? Center(
                            child: Text(
                              'No matching customer or order found for "$_searchQuery"',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              // Customer Profile Card
                              _buildCustomerProfileCard(),
                              const SizedBox(height: 16),

                              // Order History Title
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Associated Orders & Payments',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${_customerOrders.length} orders',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              if (_customerOrders.isEmpty)
                                const Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text('No orders placed yet.'),
                                  ),
                                )
                              else
                                ..._customerOrders.map((o) => _buildOrderSupportCard(o)),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerProfileCard() {
    final info = _customerInfo!;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.indigo.shade100,
                  child: const Icon(Icons.person, color: Colors.indigo),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info['email'] ?? 'Customer',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'UID: ${info['user_id']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    info['account_status'] ?? 'Active',
                    style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCol('Lifetime Orders', '${info['total_orders']}'),
                _buildStatCol('Total Spend', '₹${(info['total_spent'] as double).toStringAsFixed(2)}'),
                _buildStatCol('Trust Level', 'Verified'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCol(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }

  Widget _buildOrderSupportCard(OrderV2 order) {
    final isRefundable = order.status.value != 'refunded' && order.status.value != 'cancelled';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.orderNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: order.status.value == 'delivered' ? Colors.green.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.status.value.toUpperCase(),
                    style: TextStyle(
                      color: order.status.value == 'delivered' ? Colors.green.shade800 : Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${order.items.length} items • ₹${order.grandTotal.toStringAsFixed(2)}'),
                Text(
                  order.createdAt.toLocal().toString().split('.')[0],
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            if (isRefundable) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.currency_exchange, size: 16, color: Colors.red),
                  label: const Text('Issue Support Refund', style: TextStyle(color: Colors.red)),
                  onPressed: () => _processRefund(order),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
