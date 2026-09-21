import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:opem/demo/demo_data.dart';
import 'package:opem/models/profile.dart';
import 'package:opem/services/profile_service.dart';
import 'package:opem/utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  GoogleSignIn? _googleSignInInstance;
  GoogleSignIn get _googleSignIn => _googleSignInInstance ??= GoogleSignIn(
    clientId: kIsWeb ? (googleWebClientId.isNotEmpty ? googleWebClientId : null) : null,
    serverClientId: googleWebClientId.isNotEmpty ? googleWebClientId : null,
    scopes: ['email', 'profile'],
  );

  // ─── State Getters ─────────────────────────────────────────────────────────

  bool get isSignedIn {
    if (isDemoMode) return true; // In demo mode, treated as demo customer
    return Supabase.instance.client.auth.currentUser != null;
  }

  User? get currentUser {
    if (isDemoMode) return null;
    return Supabase.instance.client.auth.currentUser;
  }

  String? get currentUserId {
    if (isDemoMode) return DemoDataService.demoCustomerProfile.id;
    return currentUser?.id;
  }

  String? get currentUserEmail {
    if (isDemoMode) return DemoDataService.demoCustomerProfile.email;
    return currentUser?.email;
  }

  Stream<AuthState> get authStateChanges {
    if (isDemoMode) {
      return const Stream<AuthState>.empty();
    }
    return Supabase.instance.client.auth.onAuthStateChange;
  }

  // ─── Authentication Methods ────────────────────────────────────────────────

  /// Sign in with Email and Password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    if (isDemoMode) {
      return AuthResponse();
    }

    try {
      return await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  /// Sign up with Email and Password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    if (isDemoMode) {
      return AuthResponse();
    }

    try {
      return await Supabase.instance.client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          if (fullName != null && fullName.isNotEmpty) 'full_name': fullName.trim(),
        },
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  /// Sign In with Google
  /// Automatically uses native ID token on mobile and OAuth redirect on Web.
  Future<AuthResponse?> signInWithGoogle() async {
    if (isDemoMode) return AuthResponse();

    try {
      if (kIsWeb) {
        // Web OAuth Redirect
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: authRedirectUri,
        );
        return null;
      } else {
        // Native Google Sign-In on iOS / Android
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          // User cancelled the login flow
          return null;
        }

        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;
        final accessToken = googleAuth.accessToken;

        if (idToken == null) {
          throw const AuthException('No Google ID Token found from Google authentication.');
        }

        final response = await Supabase.instance.client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );

        return response;
      }
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    if (isDemoMode) return;

    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
    } catch (_) {}

    await Supabase.instance.client.auth.signOut();
  }

  /// Send password reset link to user email
  Future<void> resetPassword(String email) async {
    if (isDemoMode) return;

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: authRedirectUri,
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  /// Fetch full user profile of current logged-in user
  Future<Profile?> getCurrentProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;
    return profileService.fetchProfile(uid);
  }

  // ─── Error Handling ────────────────────────────────────────────────────────

  AuthException _mapAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') || msg.contains('invalid_grant')) {
      return const AuthException('Invalid email or password. Please try again.');
    } else if (msg.contains('user already registered') || msg.contains('already exists')) {
      return const AuthException('An account with this email already exists.');
    } else if (msg.contains('network') || msg.contains('connection')) {
      return const AuthException('Network error. Please check your internet connection.');
    }
    return e;
  }
}

final authService = AuthService();
