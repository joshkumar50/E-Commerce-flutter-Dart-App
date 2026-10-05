import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:opem/utils/observability.dart';

enum Environment {
  development,
  staging,
  production;

  bool get isDevelopment => this == Environment.development;
  bool get isStaging => this == Environment.staging;
  bool get isProduction => this == Environment.production;
}

/// Production Configuration & Environment Manager
///
/// ⚠️  SECURITY NOTICE ⚠️
/// All credentials are injected at build time via --dart-define or
/// --dart-define-from-file. No real secrets should ever appear as
/// defaultValue strings in this file. Violations will fail the
/// production startup validation below.
class AppEnvironment {
  static const String _rawEnv =
      String.fromEnvironment('APP_ENV', defaultValue: 'development');

  static final Environment current = switch (_rawEnv.toLowerCase()) {
    'production' || 'prod' => Environment.production,
    'staging' || 'stage' => Environment.staging,
    _ => Environment.development,
  };

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '', // Injected via --dart-define-from-file. No hardcoded fallback.
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '', // Injected via --dart-define-from-file. No hardcoded fallback.
  );
  static const String authRedirectUri = String.fromEnvironment(
    'AUTH_REDIRECT_URI',
    defaultValue: 'io.supabase.bbuys://login-callback',
  );

  static const bool isDemoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);

  /// Validates environment variables at application startup.
  /// Strictly prevents shipping a production build with missing or placeholder credentials.
  static void validate() {
    if (kDebugMode) {
      AppObservability.info(
        'Booting in ${current.name.toUpperCase()} mode (Demo: $isDemoMode)',
        operation: 'app_startup',
      );
    }

    // Always validate that keys were actually injected (in any environment)
    if (supabaseUrl.isEmpty && !isDemoMode) {
      throw StateError(
        'FATAL: App cannot boot without SUPABASE_URL. '
        'Run with: flutter run --dart-define-from-file=.env.development',
      );
    }

    if (current.isProduction) {
      if (supabaseUrl.isEmpty) {
        throw StateError(
          'FATAL: Production build cannot boot without a valid SUPABASE_URL. '
          'Provide it via --dart-define=SUPABASE_URL=... or --dart-define-from-file=.env.production',
        );
      }

      if (!supabaseUrl.startsWith('https://')) {
        throw StateError(
            'FATAL: Production SUPABASE_URL must use secure HTTPS protocol: $supabaseUrl');
      }

      final invalidSubstrings = ['your-project', 'placeholder', 'example.com', 'localhost'];
      for (final sub in invalidSubstrings) {
        if (supabaseUrl.contains(sub)) {
          throw StateError('FATAL: Production SUPABASE_URL contains invalid/placeholder value: $sub');
        }
      }

      final ipRegex = RegExp(r'^https?://\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}');
      if (ipRegex.hasMatch(supabaseUrl)) {
        throw StateError('FATAL: Production SUPABASE_URL cannot be an IP literal.');
      }

      if (supabaseAnonKey.isEmpty || supabaseAnonKey.contains('placeholder')) {
        throw StateError(
            'FATAL: Production build requires a valid SUPABASE_ANON_KEY');
      }

      // Decode JWT to ensure it's not a service_role key
      try {
        final parts = supabaseAnonKey.split('.');
        if (parts.length != 3) throw const FormatException('Invalid JWT parts length');
        final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
        final jsonPayload = jsonDecode(payload);
        if (jsonPayload['role'] != 'anon') {
           throw StateError('FATAL: SUPABASE_ANON_KEY must have role "anon", got "${jsonPayload['role']}"');
        }
      } catch (e) {
        throw StateError('FATAL: Could not parse SUPABASE_ANON_KEY as valid JWT: $e');
      }

      if (isDemoMode) {
        throw StateError('FATAL: Production build cannot run in DEMO_MODE.');
      }
    }
  }
}
