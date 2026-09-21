import 'package:flutter/material.dart';
import 'package:opem/core/admin_theme.dart';
import 'package:opem/models/order_v2.dart';
import 'package:opem/screens/admin/admin_order_detail_screen.dart';
import 'package:opem/services/order_service.dart';
import 'package:opem/utils/formatters.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Pending',
    'Confirmed',
    'Completed',
    'Cancelled',
    'Refunded',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shopping_bag_outlined, size: 20),
            SizedBox(width: 8),
            Text('Order Management'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ─── Search & Status Filters ──────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by order # or customer name...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: AdminColors.surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((f) {
                      final isSelected = _selectedFilter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(f),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedFilter = f),
                          selectedColor: AdminColors.primaryLight.withValues(alpha: 0.2),
                          checkmarkColor: AdminColors.primary,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AdminColors.primary : AdminColors.textSecondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ─── Live Orders Stream ───────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<OrderV2>>(
              stream: orderService.watchAllOrders(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allOrders = snapshot.data ?? [];

                // Filter by search and status
                final filtered = allOrders.where((order) {
                  // Search query matching
                  final matchesSearch = _searchQuery.isEmpty ||
                      order.orderNumber.toLowerCase().contains(_searchQuery) ||
                      order.shippingAddress.fullName.toLowerCase().contains(_searchQuery) ||
                      order.shippingAddress.phone.contains(_searchQuery);

                  if (!matchesSearch) return false;

                  // Status filter matching
                  switch (_selectedFilter) {
                    case 'Pending':
                      return order.status == OrderStatus.pendingPayment ||
                          order.status == OrderStatus.paymentProcessing;
                    case 'Confirmed':
                      return order.status == OrderStatus.confirmed ||
                          order.status == OrderStatus.paid;
                    case 'Completed':
                      return order.status == OrderStatus.completed;
                    case 'Cancelled':
                      return order.status == OrderStatus.cancelled ||
                          order.status == OrderStatus.paymentFailed;
                    case 'Refunded':
                      return order.status == OrderStatus.refunded ||
                          order.status == OrderStatus.partiallyRefunded;
                    default:
                      return true;
                  }
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inbox_outlined, size: 56, color: AdminColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty ? 'No matching orders found' : 'No orders in this category',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = filtered[index];
                    return _AdminOrderCard(
                      order: order,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminOrderDetailScreen(order: order),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminOrderCard extends StatelessWidget {
  final OrderV2 order;
  final VoidCallback onTap;

  const _AdminOrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                Expanded(
                  child: Text(
                    order.orderNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: order.status.badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: order.status.badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    order.status.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: order.status.badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: AdminColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  order.shippingAddress.fullName,
                  style: const TextStyle(fontSize: 13, color: AdminColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  AppFormatters.formatDateTime(order.createdAt),
                  style: const TextStyle(fontSize: 11, color: AdminColors.textMuted),
                ),
              ],
            ),
            const Divider(height: 20, color: AdminColors.surfaceMuted),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'}',
                  style: const TextStyle(color: AdminColors.textSecondary, fontSize: 13),
                ),
                Text(
                  AppFormatters.formatCurrency(order.grandTotal),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AdminColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
