import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:opem/models/profile.dart';
import 'package:opem/services/auth_service.dart';
import 'package:opem/services/profile_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProvider extends ChangeNotifier {
  Profile? _profile;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<Profile?>? _profileSubscription;

  Profile? get profile => _profile;
  String? get id => _profile?.id ?? authService.currentUserId;
  String? get email => _profile?.email ?? authService.currentUserEmail;
  String get name => _profile?.fullName ?? '';
  String? get phone => _profile?.phone;
  String? get avatarUrl => _profile?.avatarUrl;
  String get role => _profile?.role ?? 'customer';

  bool get isAdmin => role == 'admin';
  bool get isCustomer => role == 'customer';
  bool get isAuthenticated => authService.isSignedIn;

  UserProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    // Initial fetch if signed in
    loadProfile();

    // Listen to Supabase Auth state changes
    _authSubscription = authService.authStateChanges.listen((data) {
      final session = data.session;
      if (session != null) {
        _subscribeToProfile(session.user.id);
      } else {
        reset();
      }
    });
  }

  /// Subscribe to real-time profile row changes in PostgreSQL
  void _subscribeToProfile(String userId) {
    _profileSubscription?.cancel();
    _profileSubscription = profileService.watchProfile(userId).listen((updatedProfile) {
      if (updatedProfile != null) {
        _profile = updatedProfile;
        notifyListeners();
      }
    });
  }

  /// Load profile from database or demo mode
  Future<void> loadProfile() async {
    final uid = authService.currentUserId;
    if (uid == null) {
      _profile = null;
      notifyListeners();
      return;
    }

    try {
      final p = await profileService.fetchProfile(uid);
      if (p != null) {
        _profile = p;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Manually set profile (e.g. after profile edit)
  void setProfile(Profile profile) {
    _profile = profile;
    notifyListeners();
  }

  /// Legacy helper for existing UI screens
  void setFromAuth() {
    loadProfile();
  }

  /// Call on sign-out to clear user data
  void reset() {
    _profileSubscription?.cancel();
    _profile = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}
