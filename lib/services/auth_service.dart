import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
    try {
      return Supabase.instance.client.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  User? get currentUser {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  String? get currentUserId => currentUser?.id;

  String? get currentUserEmail => currentUser?.email;

  Stream<AuthState> get authStateChanges {
    try {
      return Supabase.instance.client.auth.onAuthStateChange;
    } catch (_) {
      return const Stream<AuthState>.empty();
    }
  }

  // ─── Authentication Methods ────────────────────────────────────────────────

  /// Sign in with Email and Password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
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
    try {
      if (kIsWeb) {
        // Web OAuth Redirect directly returns to the running browser origin
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
        );
        return null;
      } else if (googleWebClientId.isEmpty) {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: authRedirectUri,
        );
        return null;
      } else {
        // Native Google Sign-In with ID Token (When GOOGLE_CLIENT_ID_WEB is configured)
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
      debugPrint('[AuthService] Native Google Sign-In error ($e). Falling back to browser OAuth.');
      // Automatic fallback to universal OAuth redirect
      try {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: authRedirectUri,
        );
        return null;
      } catch (oauthErr) {
        debugPrint('[AuthService] Browser OAuth redirect failed: $oauthErr');
        throw AuthException('Google Sign-In failed: ${oauthErr.toString()}');
      }
    }
  }

  /// Send an SMS OTP code to a phone number.
  /// Format must be E.164 (e.g. +919876543210).
  Future<void> signInWithPhone({required String phone}) async {
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        phone: phone.trim(),
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Verify 6-digit SMS OTP code.
  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        phone: phone.trim(),
        token: token.trim(),
        type: OtpType.sms,
      );
      return response;
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Resend SMS OTP to the provided phone number.
  Future<void> resendPhoneOtp({required String phone}) async {
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.sms,
        phone: phone.trim(),
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
    } catch (_) {}

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }

  /// Send password reset link to user email
  Future<void> resetPassword(String email) async {
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
    } else if (msg.contains('token has expired') || msg.contains('otp expired') || msg.contains('invalid token')) {
      return const AuthException('Invalid or expired OTP code. Please request a new one.');
    } else if (msg.contains('sms') || msg.contains('provider') || msg.contains('unsupported phone provider')) {
      return const AuthException('SMS service is not yet enabled in Supabase Dashboard. Please configure an SMS provider (Twilio).');
    } else if (msg.contains('email_not_confirmed') || msg.contains('email not confirmed')) {
      return const AuthException('Email address is not confirmed. Please try signing up again now that confirmations are off.');
    } else if (msg.contains('rate limit') || msg.contains('too many requests')) {
      return const AuthException('Too many attempts. Please wait a moment before trying again.');
    } else if (msg.contains('network') || msg.contains('connection')) {
      return const AuthException('Network error. Please check your internet connection.');
    }
    return e;
  }
}

final authService = AuthService();

