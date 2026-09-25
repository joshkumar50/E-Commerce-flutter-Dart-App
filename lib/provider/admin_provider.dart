import 'package:flutter/foundation.dart';
import 'package:opem/demo/demo_data.dart';
import 'package:opem/models/profile.dart';
import 'package:opem/services/auth_service.dart';
import 'package:opem/services/profile_service.dart';
import 'package:opem/utils/constants.dart';

class AdminProvider extends ChangeNotifier {
  Profile? _profile;
  bool _isLoading = true;
  String? _errorMessage;

  Profile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _profile != null;
  bool get isAdmin => _profile?.role == 'admin';

  AdminProvider() {
    initAdminSession();
  }

  /// Check active session and verify that the user possesses the 'admin' role
  Future<void> initAdminSession() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (isDemoMode) {
      // In Demo mode, default to the Store Admin profile
      _profile = DemoDataService.demoAdminProfile;
      _isLoading = false;
      notifyListeners();
      return;
    }

    final currentUser = authService.currentUser;
    if (currentUser == null) {
      _profile = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final p = await profileService.fetchProfile(currentUser.id);
      if (p != null && p.role == 'admin') {
        _profile = p;
        _errorMessage = null;
      } else {
        // Logged in user is NOT an admin in the database!
        _profile = p;
        _errorMessage = 'Admin access required. Your account (${currentUser.email}) has role "${p?.role ?? 'customer'}" in the database. Please run: UPDATE public.profiles SET role = \'admin\' WHERE email = \'${currentUser.email}\'; in Supabase SQL Editor.';
      }
    } catch (e) {
      _errorMessage = 'Failed to verify admin credentials: $e';
      _profile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with Email and Password and verify admin role
  Future<bool> signInAsAdmin(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (isDemoMode) {
      // In demo mode: check if email contains "customer" to simulate access denial
      if (email.toLowerCase().contains('customer') || email.toLowerCase().contains('alex')) {
        _profile = DemoDataService.demoCustomerProfile;
        _errorMessage = 'Admin access required. This account is a Customer.';
        _isLoading = false;
        notifyListeners();
        return false;
      } else {
        _profile = DemoDataService.demoAdminProfile;
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    }

    try {
      final res = await authService.signIn(email: email, password: password);
      final user = res.user;
      if (user == null) {
        _errorMessage = 'Invalid credentials';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final p = await profileService.fetchProfile(user.id);
      if (p != null && p.role == 'admin') {
        _profile = p;
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // Customer attempted to log in as admin -> Deny and sign out!
        await authService.signOut();
        _profile = null;
        _errorMessage = 'Admin access required. Your account (${user.email}) has role "${p?.role ?? 'customer'}" in the database. Please run: UPDATE public.profiles SET role = \'admin\' WHERE email = \'${user.email}\'; in Supabase SQL Editor.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _profile = null;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// For testing in demo mode: simulate customer login to test the Access Denied screen
  void simulateCustomerLoginInDemo() {
    if (!isDemoMode) return;
    _profile = DemoDataService.demoCustomerProfile;
    _errorMessage = 'Admin access required. Your account does not have administrator privileges.';
    notifyListeners();
  }

  /// For testing in demo mode: switch back to Admin
  void simulateAdminLoginInDemo() {
    if (!isDemoMode) return;
    _profile = DemoDataService.demoAdminProfile;
    _errorMessage = null;
    notifyListeners();
  }

  /// Logout from Admin App
  Future<void> signOut() async {
    if (!isDemoMode) {
      await authService.signOut();
    }
    _profile = null;
    _errorMessage = null;
    notifyListeners();
  }
}
