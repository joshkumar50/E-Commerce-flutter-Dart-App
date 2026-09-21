import 'package:flutter/material.dart';
import 'package:opem/screens/customer/main_navigation_screen.dart';

/// Legacy entry-point wrapper that delegates directly to the modern
/// Customer [MainNavigationScreen]. This ensures that Hot Reload instantly
/// updates any open browser instance to the new modern grocery interface.
class BuyScreen extends StatelessWidget {
  const BuyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainNavigationScreen();
  }
}
