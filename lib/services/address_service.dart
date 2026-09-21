import 'package:opem/demo/demo_data.dart';
import 'package:opem/models/address.dart';
import 'package:opem/utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddressService {
  /// Realtime stream of customer addresses
  Stream<List<Address>> watchAddresses(String userId) {
    if (isDemoMode) {
      return Stream.value(DemoDataService.addresses);
    }

    return Supabase.instance.client
        .from(tableAddresses)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('is_default', ascending: false)
        .map((list) => list.map((e) => Address.fromJson(e)).toList());
  }

  /// Fetch all addresses for the user
  Future<List<Address>> fetchAddresses(String userId) async {
    if (isDemoMode) return DemoDataService.addresses;

    final data = await Supabase.instance.client
        .from(tableAddresses)
        .select()
        .eq('user_id', userId)
        .order('is_default', ascending: false);

    return (data as List).map((e) => Address.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Add a new delivery address
  Future<Address> addAddress(Address address) async {
    if (isDemoMode) return address;

    // If marked default, unset other defaults first
    if (address.isDefault) {
      await _clearDefault(address.userId);
    }

    final data = await Supabase.instance.client
        .from(tableAddresses)
        .insert(address.toJson())
        .select()
        .single();

    return Address.fromJson(data);
  }

  /// Update an existing address
  Future<void> updateAddress(Address address) async {
    if (isDemoMode) return;

    if (address.isDefault) {
      await _clearDefault(address.userId);
    }

    await Supabase.instance.client
        .from(tableAddresses)
        .update(address.toJson())
        .eq('id', address.id);
  }

  /// Set an address as the default delivery address
  Future<void> setDefaultAddress({
    required String userId,
    required String addressId,
  }) async {
    if (isDemoMode) return;

    await _clearDefault(userId);
    await Supabase.instance.client
        .from(tableAddresses)
        .update({'is_default': true})
        .eq('id', addressId);
  }

  /// Delete an address
  Future<void> deleteAddress(String addressId) async {
    if (isDemoMode) return;

    await Supabase.instance.client
        .from(tableAddresses)
        .delete()
        .eq('id', addressId);
  }

  Future<void> _clearDefault(String userId) async {
    await Supabase.instance.client
        .from(tableAddresses)
        .update({'is_default': false})
        .eq('user_id', userId);
  }
}

final addressService = AddressService();
