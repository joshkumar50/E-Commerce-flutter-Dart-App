import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:opem/core/design_tokens.dart';
import 'package:opem/provider/cart_provider.dart';
import 'package:opem/widgets/ui/animated_quantity_stepper.dart';
import 'package:opem/widgets/ui/empty_state_view.dart';
import 'package:opem/widgets/ui/error_state_view.dart';
import 'package:opem/widgets/ui/floating_cart_bar.dart';
import 'package:opem/widgets/ui/pressable_scale.dart';
import 'package:opem/widgets/ui/shimmer_loading.dart';

void main() {
  group('Master UI/UX Transformation Widget Test Suite', () {
    testWidgets('1. PressableScale renders child and triggers onTap callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PressableScale(
              onTap: () => tapped = true,
              child: const Text('Tap Me'),
            ),
          ),
        ),
      );

      expect(find.text('Tap Me'), findsOneWidget);
      await tester.tap(find.text('Tap Me'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('2. AnimatedQuantityStepper renders ADD button when quantity is 0', (tester) async {
      bool addCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedQuantityStepper(
              quantity: 0,
              onAdd: () => addCalled = true,
              onIncrement: () {},
              onDecrement: () {},
            ),
          ),
        ),
      );

      expect(find.text('ADD'), findsOneWidget);
      await tester.tap(find.text('ADD'));
      await tester.pumpAndSettle();
      expect(addCalled, isTrue);
    });

    testWidgets('3. AnimatedQuantityStepper renders stepper controls when quantity > 0', (tester) async {
      bool incrementCalled = false;
      bool decrementCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedQuantityStepper(
              quantity: 3,
              onAdd: () {},
              onIncrement: () => incrementCalled = true,
              onDecrement: () => decrementCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(incrementCalled, isTrue);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
      expect(decrementCalled, isTrue);
    });

    testWidgets('4. EmptyStateView renders icon, title, message, and action CTA', (tester) async {
      bool ctaPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateView(
              icon: Icons.shopping_basket_outlined,
              title: 'Your cart is empty',
              message: 'Add some fresh vegetables and fruits to get started.',
              actionLabel: 'Shop Now',
              onAction: () => ctaPressed = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.shopping_basket_outlined), findsOneWidget);
      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Add some fresh vegetables and fruits to get started.'), findsOneWidget);
      expect(find.text('Shop Now'), findsOneWidget);

      await tester.tap(find.text('Shop Now'));
      await tester.pumpAndSettle();
      expect(ctaPressed, isTrue);
    });

    testWidgets('5. ErrorStateView renders title, message, and retry button', (tester) async {
      bool retryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorStateView(
              title: 'Network Timeout',
              message: 'Failed to connect to catalog service.',
              onRetry: () => retryPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Network Timeout'), findsOneWidget);
      expect(find.text('Failed to connect to catalog service.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(retryPressed, isTrue);
    });

    testWidgets('6. ShimmerLoading and Skeletons render smoothly without overflow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ProductCardSkeleton(),
                  SizedBox(height: 16),
                  CategoryChipSkeleton(),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ProductCardSkeleton), findsOneWidget);
      expect(find.byType(CategoryChipSkeleton), findsOneWidget);
    });

    testWidgets('7. AppCurrency formats correctly with Indian Rupee symbol', (tester) async {
      expect(AppCurrency.format(0), '₹0');
      expect(AppCurrency.format(150), '₹150');
      expect(AppCurrency.format(49.50), '₹49.50');
      expect(AppCurrency.format(49.50, showDecimals: false), '₹49');
    });

    testWidgets('8. FloatingCartBar animates and handles empty cart gracefully', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<CartProvider>(
          create: (_) => CartProvider(),
          child: const MaterialApp(
            home: Scaffold(
              body: FloatingCartBar(),
            ),
          ),
        ),
      );

      // Cart is initially empty in provider
      expect(find.byType(FloatingCartBar), findsOneWidget);
    });
  });
}
