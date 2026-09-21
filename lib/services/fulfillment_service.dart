import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fulfillment_location.dart';
import '../utils/constants.dart';
import '../utils/observability.dart';

/// Service managing multi-warehouse and dark-store fulfillment locations.
class FulfillmentService {
  static final FulfillmentService instance = FulfillmentService._();
  FulfillmentService._();

  final List<FulfillmentLocation> _demoLocations = [
    const FulfillmentLocation(
      id: 'wh_blr_central',
      name: 'Bengaluru Central Dark Store',
      type: 'dark_store',
      address: {
        'street': '100 Feet Road, Indiranagar',
        'city': 'Bengaluru',
        'state': 'Karnataka',
        'postal_code': '560038'
      },
      servicedPincodes: ['560038', '560008', '560075', '560001', '560025'],
      isActive: true,
    ),
    const FulfillmentLocation(
      id: 'wh_blr_north',
      name: 'Hebbal Distribution Hub',
      type: 'retail_hub',
      address: {
        'street': 'Bellary Road, Hebbal',
        'city': 'Bengaluru',
        'state': 'Karnataka',
        'postal_code': '560024'
      },
      servicedPincodes: ['560024', '560092', '560032', '560045'],
      isActive: true,
    ),
    const FulfillmentLocation(
      id: 'wh_blr_south',
      name: 'Koramangala Express Store',
      type: 'dark_store',
      address: {
        'street': '80 Feet Road, 4th Block, Koramangala',
        'city': 'Bengaluru',
        'state': 'Karnataka',
        'postal_code': '560034'
      },
      servicedPincodes: ['560034', '560095', '560047', '560068'],
      isActive: true,
    ),
  ];

  /// Fetch all active fulfillment locations
  Future<List<FulfillmentLocation>> fetchLocations() async {
    if (isDemoMode) {
      return List.unmodifiable(_demoLocations);
    }

    try {
      final rows = await Supabase.instance.client
          .from(tableFulfillmentLocations)
          .select()
          .eq('is_active', true)
          .order('name');

      return (rows as List)
          .map((e) => FulfillmentLocation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppObservability.error('Failed to fetch fulfillment locations: $e');
      return [];
    }
  }

  /// Allocate inventory at a specific dark store or warehouse
  Future<Map<String, dynamic>> allocateLocationInventory({
    required int productId,
    required String locationId,
    required int quantity,
    required String orderId,
  }) async {
    if (isDemoMode) {
      return {
        'success': true,
        'product_id': productId,
        'location_id': locationId,
        'allocated_quantity': quantity,
        'available_remaining': 95,
      };
    }

    return AppObservability.measure(
      operation: 'allocate_location_inventory',
      metadata: {
        'product_id': productId,
        'location_id': locationId,
        'quantity': quantity,
        'order_id': orderId,
      },
      action: (reqId) async {
        final res = await Supabase.instance.client.rpc(
          'rpc_allocate_location_inventory',
          params: {
            'p_product_id': productId,
            'p_location_id': locationId,
            'p_quantity': quantity,
            'p_order_id': orderId,
          },
        );

        if (res is Map) {
          return Map<String, dynamic>.from(res);
        }
        return {'success': false, 'error': 'Unexpected response format'};
      },
    );
  }
}
