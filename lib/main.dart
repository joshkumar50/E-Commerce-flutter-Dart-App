import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:opem/core/app_environment.dart';
import 'package:opem/core/router.dart';
import 'package:opem/core/theme.dart';
import 'package:opem/provider/cart_provider.dart';
import 'package:opem/provider/user_provider.dart';
import 'package:opem/services/analytics_service.dart';
import 'package:opem/services/remote_config_service.dart';
import 'package:opem/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:opem/utils/observability.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    AppEnvironment.validate();
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'FATAL: Supabase configuration is missing. The app requires a valid SUPABASE_URL and SUPABASE_ANON_KEY to operate online.',
      );
    }
  } catch (e) {
    runApp(ConfigurationErrorScreen(error: e.toString()));
    return;
  }

  _configLoading();

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  } catch (e) {
    runApp(
        ConfigurationErrorScreen(error: 'Database Initialization Error: $e'));
    return;
  }

  // Phase 8 Operations & Telemetry initialization
  AnalyticsService.instance.init();
  await RemoteConfigService.instance.fetchConfig();

  const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.sendDefaultPii = false;
        options.beforeSend = (event, hint) {
          final scrubbedBreadcrumbs = event.breadcrumbs?.map((b) {
            final data = b.data != null
                ? AppObservability.sanitize(b.data!) as Map<String, dynamic>?
                : null;
            final message = b.message != null
                ? AppObservability.sanitize({'message': b.message})['message']
                    as String?
                : null;
            return b.copyWith(data: data, message: message);
          }).toList();
          return event.copyWith(breadcrumbs: scrubbedBreadcrumbs);
        };
      },
      appRunner: () => runApp(_buildApp()),
    );
  } else {
    runApp(_buildApp());
  }
}

Widget _buildApp() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => UserProvider()),
      ChangeNotifierProvider(create: (_) => CartProvider()),
    ],
    child: const BBuysApp(),
  );
}

void _configLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.dark
    ..indicatorSize = 45.0
    ..radius = 10.0
    ..userInteractions = false
    ..dismissOnTap = false;
}

class BBuysApp extends StatelessWidget {
  const BBuysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: appName,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      builder: EasyLoading.init(),
      theme: AppTheme.lightTheme,
    );
  }
}

class ConfigurationErrorScreen extends StatelessWidget {
  final String error;
  const ConfigurationErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.red[50],
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Configuration Error',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
