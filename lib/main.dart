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
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnvironment.validate();

  _configLoading();

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'FATAL: Supabase configuration is missing. The app requires a valid SUPABASE_URL and SUPABASE_ANON_KEY to operate online.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );

  // Phase 8 Operations & Telemetry initialization
  AnalyticsService.instance.init();
  await RemoteConfigService.instance.fetchConfig();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const BBuysApp(),
    ),
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
