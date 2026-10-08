import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opem/core/app_environment.dart';
import 'package:opem/provider/cart_provider.dart';
import 'package:opem/provider/user_provider.dart';
import 'package:opem/screens/login_screen.dart';
import 'package:opem/screens/phone_login_screen.dart';
import 'package:opem/screens/register_screen.dart';
import 'package:opem/utils/constants.dart';
import 'package:provider/provider.dart';

Widget _createTestWidget(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => UserProvider()),
      ChangeNotifierProvider(create: (_) => CartProvider()),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  group('Online Mode & Authentication Suite', () {
    test('1. Supabase live configuration is securely empty by default', () {
      expect(supabaseUrl.isEmpty, isTrue);
      expect(supabaseAnonKey.isEmpty, isTrue);
    });

    testWidgets('2. LoginScreen displays Phone and Google Auth buttons', (tester) async {
      await tester.pumpWidget(_createTestWidget(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Continue with Phone'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byIcon(Icons.phone_iphone_rounded), findsOneWidget);
      expect(find.byIcon(Icons.g_mobiledata), findsOneWidget);
    });

    testWidgets('3. RegisterScreen displays Phone and Google Auth options', (tester) async {
      await tester.pumpWidget(_createTestWidget(const RegisterScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsWidgets);
      expect(find.text('Sign up with Phone'), findsOneWidget);
      expect(find.text('Sign up with Google'), findsOneWidget);
    });

    testWidgets('4. PhoneLoginScreen renders phone input, country code and CTA', (tester) async {
      await tester.pumpWidget(_createTestWidget(const PhoneLoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Login with Phone'), findsOneWidget);
      expect(find.text('IN (+91)'), findsOneWidget);
      expect(find.text('Get OTP'), findsOneWidget);
      expect(find.text('Continue with Email'), findsOneWidget);
    });
  });
}
