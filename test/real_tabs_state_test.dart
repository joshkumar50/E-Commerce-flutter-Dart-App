import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opem/provider/cart_provider.dart';
import 'package:opem/provider/user_provider.dart';
import 'package:opem/screens/customer/main_navigation_screen.dart';
import 'package:opem/utils/constants.dart';
import 'package:provider/provider.dart';

/// End-to-end proof on the REAL five tabs: scroll the Shop tab, switch to
/// another tab and back, and assert the exact same Scrollable element/state
/// — and the same pixel offset — survived, which is only possible if the tab
/// was never remounted.
///
/// Requires demo mode so the screen's services don't touch Supabase:
/// `flutter test --dart-define=DEMO_MODE=true` (skipped otherwise).
void main() {
  testWidgets(
    'Real tabs keep their scroll state across switches (demo mode)',
    (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => CartProvider()),
          ],
          child: const MaterialApp(home: MainNavigationScreen()),
        ),
      );

      // Let demo streams and background services settle on the fake clock.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));

      final Finder homeScrollable = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      final ScrollableState stateBefore =
          tester.state<ScrollableState>(homeScrollable);

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      final double offsetBefore = stateBefore.position.pixels;
      expect(offsetBefore, greaterThan(100));

      // Switch to another real tab and back.
      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byIcon(Icons.storefront_outlined));
      await tester.pump(const Duration(milliseconds: 400));

      // Same element, same State object, same scroll offset.
      final ScrollableState stateAfter =
          tester.state<ScrollableState>(homeScrollable);
      expect(identical(stateAfter, stateBefore), isTrue);
      expect(stateAfter.position.pixels, offsetBefore);

      // Flush remaining background-service timers before teardown.
      await tester.pump(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 30));
    },
    skip: !isDemoMode,
  );
}
