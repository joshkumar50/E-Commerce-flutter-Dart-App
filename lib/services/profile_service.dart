import 'package:opem/demo/demo_data.dart';
import 'package:opem/models/profile.dart';
import 'package:opem/utils/constants.dart';
import 'package:opem/utils/observability.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  /// Fetch a single user profile by user UUID
  Future<Profile?> fetchProfile(String userId) async {
    if (isDemoMode) return DemoDataService.demoCustomerProfile;

    return AppObservability.measure(
      operation: 'fetch_profile',
      metadata: {'user_id': userId},
      action: (reqId) async {
        final data = await Supabase.instance.client
            .from(tableProfiles)
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (data == null) return null;
        return Profile.fromJson(data);
      },
    );
  }

  /// Watch real-time profile changes for the logged in user
  Stream<Profile?> watchProfile(String userId) {
    if (isDemoMode) {
      return Stream.value(DemoDataService.demoCustomerProfile);
    }

    return Supabase.instance.client
        .from(tableProfiles)
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((list) => list.isNotEmpty ? Profile.fromJson(list.first) : null);
  }

  /// Update customer profile details (full_name, avatar_url, phone)
  Future<void> updateProfile({
    required String userId,
    required String fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    if (isDemoMode) return;

    final updates = <String, dynamic>{
      'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };

    await AppObservability.measure(
      operation: 'update_profile',
      metadata: {'user_id': userId},
      action: (reqId) async {
        await Supabase.instance.client
            .from(tableProfiles)
            .update(updates)
            .eq('id', userId);
      },
    );
  }

  /// Admin only: Paginated fetch of all user profiles
  Future<List<Profile>> fetchAllProfiles({
    int limit = 50,
    int offset = 0,
  }) async {
    if (isDemoMode) {
      final list = [DemoDataService.demoCustomerProfile, DemoDataService.demoAdminProfile];
      final safeEnd = (offset + limit).clamp(0, list.length);
      if (offset >= list.length) return [];
      return list.sublist(offset, safeEnd);
    }

    return AppObservability.measure(
      operation: 'admin_fetch_all_profiles',
      metadata: {'limit': limit, 'offset': offset},
      action: (reqId) async {
        final safeLimit = limit.clamp(1, 100);
        final safeOffset = offset < 0 ? 0 : offset;

        final data = await Supabase.instance.client
            .from(tableProfiles)
            .select()
            .order('created_at', ascending: false)
            .range(safeOffset, safeOffset + safeLimit - 1);

        return (data as List).map((e) => Profile.fromJson(e as Map<String, dynamic>)).toList();
      },
    );
  }
}

final profileService = ProfileService();
