import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:opem/models/order.dart';
import 'package:opem/provider/user_provider.dart';
import 'package:opem/services/order_service.dart';
import 'package:opem/widgets/drawer.dart';
import 'package:provider/provider.dart';

/// Shows all orders placed by the current logged-in user (buyer view).
class BOrders extends StatelessWidget {
  const BOrders({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<UserProvider>().id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      drawer: const GlobalDrawer(pageIndex: 3),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: orderService.watchBuyOrders(userId),
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
            return const Center(child: Text('No orders yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (_, index) => _BuyOrderTile(order: orders[index]),
          );
        },
      ),
    );
  }
}

class _BuyOrderTile extends StatelessWidget {
  final Order order;
  const _BuyOrderTile({required this.order});

  Future<void> _confirmReceived(BuildContext context) async {
    EasyLoading.show(status: 'Completing order…');
    try {
      await orderService.deleteOrder(order.id);
      EasyLoading.showSuccess('Order completed!');
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
            subtitle: Text('\$${order.price.toStringAsFixed(2)}'),
            trailing: order.sended
                ? ElevatedButton(
                    onPressed: () => _confirmReceived(context),
                    child: const Text('Order Received'),
                  )
                : Chip(
                    label: const Text('Awaiting Shipment'),
                    backgroundColor: Colors.orange.shade100,
                  ),
          ),
        ],
      ),
    );
  }
}
