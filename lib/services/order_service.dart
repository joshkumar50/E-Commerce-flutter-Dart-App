import 'dart:async';
import 'package:opem/demo/demo_transaction_service.dart';
import 'package:opem/models/order.dart';
import 'package:opem/models/order_v2.dart';
import 'package:opem/utils/constants.dart';
import 'package:opem/utils/observability.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class OrderService {
  final _uuid = const Uuid();

  // ─── Modern Grocery Transaction Engine (Phase 5 & 6) ────────────────────────

  /// Customer order stream: fetches orders with items resolved in a single batch query (0 N+1 queries).
  Stream<List<OrderV2>> watchCustomerOrders(String userId) {
    if (isDemoMode) {
      return DemoTransactionService.instance.watchCustomerOrders(userId);
    }

    return Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .asyncMap((rows) async {
          if (rows.isEmpty) return <OrderV2>[];

          final orderIds = rows.map((r) => r['id'] as String).toList();

          // Single batch query for all items belonging to these orders (1 network call instead of N)
          final itemsResponse = await Supabase.instance.client
              .from('order_items')
              .select('id, order_id, product_id, title, price, quantity, unit, subtotal, image_url')
              .inFilter('order_id', orderIds);

          final itemsByOrderId = <String, List<OrderItem>>{};
          for (final itemMap in (itemsResponse as List)) {
            final item = OrderItem.fromJson(itemMap as Map<String, dynamic>);
            itemsByOrderId.putIfAbsent(item.orderId, () => []).add(item);
          }

          return rows.map((row) {
            final oId = row['id'] as String;
            return OrderV2.fromJson(row, items: itemsByOrderId[oId] ?? []);
          }).toList();
        });
  }

  /// Admin order stream: fetches platform orders with items resolved in a single batch query (0 N+1 queries).
  Stream<List<OrderV2>> watchAllOrders() {
    if (isDemoMode) {
      return DemoTransactionService.instance.watchAllOrders();
    }

    return Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((rows) async {
          if (rows.isEmpty) return <OrderV2>[];

          final orderIds = rows.map((r) => r['id'] as String).toList();

          // Single batch query for all items across all orders (1 network call instead of N)
          final itemsResponse = await Supabase.instance.client
              .from('order_items')
              .select('id, order_id, product_id, title, price, quantity, unit, subtotal, image_url')
              .inFilter('order_id', orderIds);

          final itemsByOrderId = <String, List<OrderItem>>{};
          for (final itemMap in (itemsResponse as List)) {
            final item = OrderItem.fromJson(itemMap as Map<String, dynamic>);
            itemsByOrderId.putIfAbsent(item.orderId, () => []).add(item);
          }

          return rows.map((row) {
            final oId = row['id'] as String;
            return OrderV2.fromJson(row, items: itemsByOrderId[oId] ?? []);
          }).toList();
        });
  }

  /// Paginated customer order fetch (for scalable non-streaming history)
  Future<List<OrderV2>> fetchCustomerOrdersPaginated({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    if (isDemoMode) {
      final all = DemoTransactionService.instance.watchCustomerOrders(userId);
      final list = await all.first;
      final safeEnd = (offset + limit).clamp(0, list.length);
      if (offset >= list.length) return [];
      return list.sublist(offset, safeEnd);
    }

    return AppObservability.measure(
      operation: 'fetch_customer_orders_paginated',
      metadata: {'user_id': userId, 'limit': limit, 'offset': offset},
      action: (reqId) async {
        final safeLimit = limit.clamp(1, 100);
        final safeOffset = offset < 0 ? 0 : offset;

        // PostgREST joined query in 1 round trip
        final data = await Supabase.instance.client
            .from('orders')
            .select('*, order_items(*)')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .range(safeOffset, safeOffset + safeLimit - 1);

        return (data as List).map((row) {
          final itemsList = (row['order_items'] as List? ?? [])
              .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
              .toList();
          return OrderV2.fromJson(row as Map<String, dynamic>, items: itemsList);
        }).toList();
      },
    );
  }

  /// Fetch single order with its items and snapshots using PostgREST resource embedding
  Future<OrderV2?> getOrder(String orderId) async {
    if (isDemoMode) {
      final order = DemoTransactionService.instance.allOrders
          .where((o) => o.id == orderId)
          .firstOrNull;
      return order;
    }

    return AppObservability.measure(
      operation: 'get_order',
      metadata: {'order_id': orderId},
      action: (reqId) async {
        // Single round trip with embedded relation
        final row = await Supabase.instance.client
            .from('orders')
            .select('*, order_items(*)')
            .eq('id', orderId)
            .maybeSingle();

        if (row == null) return null;

        final itemsList = (row['order_items'] as List? ?? [])
            .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
            .toList();

        return OrderV2.fromJson(row, items: itemsList);
      },
    );
  }

  /// Admin operational status update (e.g. confirmed -> completed).
  Future<void> adminUpdateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    String notes = '',
  }) async {
    if (isDemoMode) {
      return await DemoTransactionService.instance.adminUpdateOrderStatus(
        orderId: orderId,
        newStatus: newStatus,
        notes: notes,
      );
    }

    await AppObservability.measure(
      operation: 'admin_update_order_status',
      metadata: {'order_id': orderId, 'new_status': newStatus.value},
      action: (reqId) async {
        await Supabase.instance.client.rpc(
          'rpc_admin_update_order_status',
          params: {
            'p_order_id': orderId,
            'p_new_status': newStatus.value,
            'p_notes': notes,
          },
        );
      },
    );
  }

  /// Admin refund processing with optional restock.
  Future<Map<String, dynamic>> processRefund({
    required String orderId,
    required double amount,
    required String reason,
    bool restock = false,
    String? idempotencyKey,
  }) async {
    if (isDemoMode) {
      return await DemoTransactionService.instance.processRefund(
        orderId: orderId,
        amount: amount,
        reason: reason,
        restock: restock,
        idempotencyKey: idempotencyKey,
      );
    }

    return AppObservability.measure(
      operation: 'admin_process_refund',
      metadata: {'order_id': orderId, 'amount': amount, 'restock': restock},
      action: (reqId) async {
        final response = await Supabase.instance.client.rpc(
          'rpc_process_refund',
          params: {
            'p_order_id': orderId,
            'p_amount': amount,
            'p_reason': reason,
            'p_restock': restock,
            'p_idempotency_key': idempotencyKey,
          },
        );

        if (response is Map<String, dynamic>) {
          return response;
        } else {
          throw Exception('Unexpected response format from refund RPC');
        }
      },
    );
  }

  // ─── Legacy Peer-to-Peer Order Methods (Preserved for Backward Compatibility) ──

  Stream<List<Map<String, dynamic>>> watchBuyOrders(String userId) {
    if (isDemoMode) return const Stream.empty();
    return Supabase.instance.client
        .from(tableOrders)
        .stream(primaryKey: ['id'])
        .eq('buyer', userId)
        .order('id');
  }

  Stream<List<Map<String, dynamic>>> watchSellOrders(String userId) {
    if (isDemoMode) return const Stream.empty();
    return Supabase.instance.client
        .from(tableOrders)
        .stream(primaryKey: ['id'])
        .eq('seller', userId)
        .order('id');
  }

  Future<void> placeOrder({
    required String productName,
    required double price,
    required String buyerId,
    required String sellerId,
    required String imageUrl,
  }) async {
    if (isDemoMode) return;
    final order = Order(
      id: 0,
      oid: _uuid.v4(),
      name: productName,
      seller: sellerId,
      buyer: buyerId,
      image: imageUrl,
      sended: false,
      price: price,
    );
    await Supabase.instance.client
        .from(tableOrders)
        .insert(order.toInsertJson());
  }

  Future<void> markShipped(int orderId) async {
    if (isDemoMode) return;
    await Supabase.instance.client
        .from(tableOrders)
        .update({'sended': true})
        .eq('id', orderId);
  }

  Future<void> deleteOrder(int orderId) async {
    if (isDemoMode) return;
    await Supabase.instance.client.from(tableOrders).delete().eq('id', orderId);
  }
}

final orderService = OrderService();
