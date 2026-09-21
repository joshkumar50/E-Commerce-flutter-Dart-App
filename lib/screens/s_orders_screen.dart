import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:opem/models/order.dart';
import 'package:opem/provider/user_provider.dart';
import 'package:opem/services/order_service.dart';
import 'package:opem/widgets/drawer.dart';
import 'package:provider/provider.dart';

/// Shows all orders where the current user is the seller.
class SOrders extends StatelessWidget {
  const SOrders({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<UserProvider>().id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Sales Orders')),
      drawer: const GlobalDrawer(pageIndex: 4),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: orderService.watchSellOrders(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final orders =
              (snapshot.data ?? []).map((e) => Order.fromJson(e)).toList();

          if (orders.isEmpty) {
            return const Center(child: Text('No sales orders yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (_, index) => _SellOrderTile(order: orders[index]),
          );
        },
      ),
    );
  }
}

class _SellOrderTile extends StatelessWidget {
  final Order order;
  const _SellOrderTile({required this.order});

  Future<void> _markShipped(BuildContext context) async {
    EasyLoading.show(status: 'Marking shipped…');
    try {
      await orderService.markShipped(order.id);
      EasyLoading.showSuccess('Marked as shipped!');
    } catch (e) {
      EasyLoading.showError('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          if (order.image.isNotEmpty)
            CachedNetworkImage(
              imageUrl: order.image,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
            ),
          ListTile(
            title: Text(order.name),
            subtitle: Text('Buyer: ${order.buyer}\n\$${order.price.toStringAsFixed(2)}'),
            isThreeLine: true,
            trailing: order.sended
                ? const Chip(label: Text('Shipped ✓'))
                : ElevatedButton(
                    onPressed: () => _markShipped(context),
                    child: const Text('Mark Shipped'),
                  ),
          ),
        ],
      ),
    );
  }
}
