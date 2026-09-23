import 'package:flutter/foundation.dart';
import 'package:opem/utils/observability.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum Environment {
  development,
  staging,
  production;

  bool get isDevelopment => this == Environment.development;
  bool get isStaging => this == Environment.staging;
  bool get isProduction => this == Environment.production;
}

/// Production Configuration & Environment Manager
class AppEnvironment {
  static const String _rawEnv = String.fromEnvironment('APP_ENV', defaultValue: 'development');

  static final Environment current = switch (_rawEnv.toLowerCase()) {
    'production' || 'prod' => Environment.production,
    'staging' || 'stage' => Environment.staging,
    _ => Environment.development,
  };

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://eqhkqkewhpvxfwaggkmt.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVxaGtxa2V3aHB2eGZ3YWdna210Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwODAxMDMsImV4cCI6MjEwNTY1NjEwM30.Oqxw8a7YC4DacRPO4ZZPXI_rbtCwHkyNrHMdkephAmc',
  );
  static const String authRedirectUri = String.fromEnvironment(
    'AUTH_REDIRECT_URI',
    defaultValue: 'io.supabase.bbuys://login-callback',
  );

  static bool get isDemoMode {
    try {
      Supabase.instance;
      return false;
    } catch (_) {
      return true;
    }
  }

  /// Validates environment variables at application startup.
  /// Strictly prevents shipping a production build with missing or placeholder credentials.
  static void validate() {
    if (kDebugMode) {
      AppObservability.info(
        'Booting in ${current.name.toUpperCase()} mode (Demo: $isDemoMode)',
        operation: 'app_startup',
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
        throw StateError('FATAL: Production SUPABASE_URL must use secure HTTPS protocol: $supabaseUrl');
      }

      if (supabaseUrl.contains('your-project') || supabaseUrl.contains('placeholder')) {
        throw StateError('FATAL: Production SUPABASE_URL contains placeholder value: $supabaseUrl');
      }

      if (supabaseAnonKey.isEmpty || supabaseAnonKey.contains('placeholder')) {
        throw StateError('FATAL: Production build requires a valid SUPABASE_ANON_KEY');
      }
    }
  }
}
