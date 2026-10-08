import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opem/core/design_tokens.dart';
import 'package:opem/widgets/ui/app_modals.dart';

void main() {
  testWidgets(
    'App dialog opens, dismisses, and returns its result with the app motion',
    (tester) async {
      bool? result;
      bool finished = false;
      Duration? enterDuration;
      Duration? exitDuration;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    finished = false;
                    result = await showAppDialog<bool>(
                      context: context,
                      builder: (dialogContext) {
                        final ModalRoute<dynamic> route =
                            ModalRoute.of(dialogContext)!;
                        enterDuration = route.transitionDuration;
                        exitDuration = route.reverseTransitionDuration;
                        return AlertDialog(
                          title: const Text('Delete item?'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Confirm'),
                            ),
                          ],
                        );
                      },
                    );
                    finished = true;
                  },
                  child: const Text('open dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Opens, with the dialog motion tokens applied to the real route.
      await tester.tap(find.text('open dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Delete item?'), findsOneWidget);
      expect(enterDuration, AppModalMotion.dialogDuration);
      expect(exitDuration, AppModalMotion.dialogDuration);

      // Confirming returns the dialog's result.
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
      expect(result, isTrue);
      expect(find.text('Delete item?'), findsNothing);

      // Barrier dismissal returns null.
      await tester.tap(find.text('open dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Delete item?'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
      expect(result, isNull);
      expect(find.text('Delete item?'), findsNothing);
    },
  );

  testWidgets(
    'App bottom sheet opens, dismisses, and returns its result with the app motion',
    (tester) async {
      String? result;
      bool finished = false;
      Duration? enterDuration;
      Duration? exitDuration;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    finished = false;
                    result = await showAppBottomSheet<String>(
                      context: context,
                      builder: (sheetContext) {
                        final ModalRoute<dynamic> route =
                            ModalRoute.of(sheetContext)!;
                        enterDuration = route.transitionDuration;
                        exitDuration = route.reverseTransitionDuration;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Pick a slot'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(sheetContext, 'morning'),
                              child: const Text('Morning'),
                            ),
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    );
                    finished = true;
                  },
                  child: const Text('open sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      // Opens, with the sheet's asymmetric token durations on the real route.
      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Pick a slot'), findsOneWidget);
      expect(enterDuration, AppModalMotion.sheetEnter);
      expect(exitDuration, AppModalMotion.sheetExit);

      // Picking an option returns the sheet's result.
      await tester.tap(find.text('Morning'));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
      expect(result, 'morning');
      expect(find.text('Pick a slot'), findsNothing);

      // Barrier dismissal returns null.
      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Pick a slot'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
      expect(result, isNull);
      expect(find.text('Pick a slot'), findsNothing);
    },
  );

  testWidgets(
    'AppModalMotion resolves token styles and zeroes them under reduced motion',
    (tester) async {
      late AnimationStyle dialog;
      late AnimationStyle sheet;
      late AnimationStyle reducedDialog;
      late AnimationStyle reducedSheet;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              dialog = AppModalMotion.dialogStyle(context);
              sheet = AppModalMotion.bottomSheetStyle(context);
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: Builder(
                  builder: (reducedContext) {
                    reducedDialog = AppModalMotion.dialogStyle(reducedContext);
                    reducedSheet =
                        AppModalMotion.bottomSheetStyle(reducedContext);
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(dialog.duration, AppMotion.fast);
      expect(dialog.reverseDuration, AppMotion.fast);
      expect(dialog.curve, AppMotion.decelerate);
      expect(dialog.reverseCurve, AppMotion.accelerate);

      expect(sheet.duration, AppMotion.normal);
      expect(sheet.reverseDuration, AppMotion.fast);
      expect(sheet.curve, AppMotion.decelerate);
      expect(sheet.reverseCurve, AppMotion.accelerate);

      expect(reducedDialog.duration, Duration.zero);
      expect(reducedDialog.reverseDuration, Duration.zero);
      expect(reducedSheet.duration, Duration.zero);
      expect(reducedSheet.reverseDuration, Duration.zero);
    },
  );

  testWidgets(
    'Modals still open and return results under reduced motion',
    (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Scaffold(
                body: Builder(
                  builder: (reducedContext) => Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        result = await showAppDialog<bool>(
                          context: reducedContext,
                          builder: (dialogContext) => AlertDialog(
                            content: const Text('Instant dialog'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('open instant dialog'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open instant dialog'));
      await tester.pump(); // one frame is enough: the route duration is zero
      expect(find.text('Instant dialog'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(find.text('Instant dialog'), findsNothing);
    },
  );

  test('every modal call site goes through the app wrappers', () {
    final List<String> offenders = <String>[];
    for (final FileSystemEntity entity
        in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('app_modals.dart')) continue;
      final String source = entity.readAsStringSync();
      if (source.contains('showDialog(') ||
          source.contains('showModalBottomSheet(')) {
        offenders.add(entity.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Use showAppDialog/showAppBottomSheet from app_modals.dart so '
          'every modal keeps the app motion language.',
    );
  });
}
