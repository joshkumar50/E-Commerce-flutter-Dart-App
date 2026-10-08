import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opem/widgets/ui/app_animations.dart';

/// Stateful dummy page: counts taps and records each initState, so a test can
/// prove the element was never re-inflated.
class _Counter extends StatefulWidget {
  final String id;
  final List<String> created;

  const _Counter({required this.id, required this.created});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    widget.created.add(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _count++),
      child: Center(child: Text('${widget.id}: $_count')),
    );
  }
}

/// Reproduces the defective switching structure this primitive replaced:
/// an AnimatedSwitcher whose child is keyed by index, so every switch mounts
/// a FRESH IndexedStack (fresh scroll positions, fresh subscriptions) and
/// disposes the old one.
///
/// It exists purely as a negative control: each state-preservation test below
/// asserts that this structure LOSES the state the real primitive keeps, so
/// the tests cannot pass for the wrong reason.
class _LegacyTabSwitcher extends StatelessWidget {
  const _LegacyTabSwitcher({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey<int>(index),
        child: IndexedStack(index: index, children: children),
      ),
    );
  }
}

Widget _host({
  required int index,
  required List<Widget> children,
  bool legacy = false,
}) {
  return MaterialApp(
    home: legacy
        ? _LegacyTabSwitcher(index: index, children: children)
        : TabCrossFade(index: index, children: children),
  );
}

void main() {
  testWidgets(
    'TabCrossFade keeps child state and elements alive across switches',
    (tester) async {
      final created = <String>[];
      final Widget tab0 = _Counter(id: 'tab-0', created: created);
      final Widget tab1 = _Counter(id: 'tab-1', created: created);
      final children = <Widget>[tab0, tab1];

      // Like IndexedStack, every child is mounted up-front.
      await tester.pumpWidget(_host(index: 0, children: children));
      expect(created, ['tab-0', 'tab-1']);
      expect(find.text('tab-0: 0'), findsOneWidget);

      // Mutate tab 0's state.
      await tester.tap(find.text('tab-0: 0'));
      await tester.pump();
      await tester.tap(find.text('tab-0: 1'));
      await tester.pump();
      expect(find.text('tab-0: 2'), findsOneWidget);

      // Switch to tab 1: mid-transition both layers are painted.
      await tester.pumpWidget(_host(index: 1, children: children));
      expect(find.text('tab-0: 2'), findsOneWidget);
      expect(find.text('tab-1: 0'), findsOneWidget);

      await tester.pumpAndSettle();
      // Settled: only the selected tab is onstage.
      expect(find.text('tab-1: 0'), findsOneWidget);
      expect(find.text('tab-0: 2'), findsNothing);

      // Switch back: tab 0's counter must have survived, and no child may
      // have been re-instantiated.
      await tester.pumpWidget(_host(index: 0, children: children));
      await tester.pumpAndSettle();
      expect(find.text('tab-0: 2'), findsOneWidget);
      expect(find.text('tab-1: 0'), findsNothing);
      expect(created, ['tab-0', 'tab-1']);
    },
  );

  testWidgets(
    'TabCrossFade preserves a real scroll offset across switches (and the '
    'legacy structure demonstrably loses it)',
    (tester) async {
      // keepScrollOffset: false removes the PageStorage restore path, so the
      // only thing that can preserve the offset is the element staying alive.
      final scrollController = ScrollController(keepScrollOffset: false);
      addTearDown(scrollController.dispose);

      final Widget scrollTab = ListView.builder(
        controller: scrollController,
        itemCount: 60,
        itemExtent: 40,
        itemBuilder: (context, i) => Text('row-$i'),
      );
      final children = <Widget>[scrollTab, const SizedBox.expand()];

      // ── The real primitive: offset survives away-and-back ────────────────
      await tester.pumpWidget(_host(index: 0, children: children));
      await tester.drag(find.byType(ListView), const Offset(0, -240));
      await tester.pumpAndSettle();

      final offsetBefore = scrollController.offset;
      expect(offsetBefore, greaterThan(150));

      await tester.pumpWidget(_host(index: 1, children: children));
      await tester.pumpAndSettle();
      expect(scrollController.offset, offsetBefore); // survives while hidden

      await tester.pumpWidget(_host(index: 0, children: children));
      await tester.pumpAndSettle();
      expect(scrollController.offset, offsetBefore);

      // ── Negative control: the old structure must lose it ─────────────────
      await tester.pumpWidget(
        _host(index: 0, children: children, legacy: true),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -240));
      await tester.pumpAndSettle();
      expect(scrollController.offset, greaterThan(150));

      await tester.pumpWidget(
        _host(index: 1, children: children, legacy: true),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _host(index: 0, children: children, legacy: true),
      );
      await tester.pumpAndSettle();
      // The defect, demonstrated: the fresh element restarts at zero.
      expect(scrollController.offset, 0);
    },
  );

  testWidgets(
    'TabCrossFade subscribes a child stream exactly once across switches '
    '(and the legacy structure demonstrably re-subscribes)',
    (tester) async {
      final listens = <int>[];
      final stream = Stream<int>.multi((controller) {
        listens.add(1);
        controller.add(listens.length);
      });

      final Widget streamingTab = StreamBuilder<int>(
        stream: stream,
        builder: (context, snapshot) => Center(
          child: Text('value: ${snapshot.data}'),
        ),
      );
      final children = <Widget>[streamingTab, const SizedBox.expand()];

      // ── The real primitive: exactly one subscription, ever ───────────────
      await tester.pumpWidget(_host(index: 0, children: children));
      await tester.pump();
      expect(listens.length, 1);

      await tester.pumpWidget(_host(index: 1, children: children));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_host(index: 0, children: children));
      await tester.pumpAndSettle();
      expect(listens.length, 1);

      // ── Negative control: the old structure must re-subscribe ────────────
      await tester.pumpWidget(
        _host(index: 1, children: children, legacy: true),
      );
      await tester.pumpAndSettle();
      final listensBeforeLegacyRoundTrip = listens.length;

      await tester.pumpWidget(
        _host(index: 0, children: children, legacy: true),
      );
      await tester.pumpAndSettle();
      expect(listens.length, greaterThan(listensBeforeLegacyRoundTrip));
    },
  );

  testWidgets(
    'TabCrossFade honors reduced motion while still preserving state',
    (tester) async {
      final created = <String>[];
      final Widget tab0 = _Counter(id: 'rm-0', created: created);
      final Widget tab1 = _Counter(id: 'rm-1', created: created);

      Widget host({required int index}) => MaterialApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: TabCrossFade(
                  index: index,
                  children: [tab0, tab1],
                ),
              ),
            ),
          );

      await tester.pumpWidget(host(index: 0));
      await tester.tap(find.text('rm-0: 0'));
      await tester.pump();

      // One frame after the switch the swap must already be complete.
      await tester.pumpWidget(host(index: 1));
      await tester.pump();
      expect(find.text('rm-0: 1'), findsNothing);
      expect(find.text('rm-1: 0'), findsOneWidget);

      // And round-tripping still preserves state.
      await tester.pumpWidget(host(index: 0));
      await tester.pump();
      expect(find.text('rm-0: 1'), findsOneWidget);
      expect(created, ['rm-0', 'rm-1']);
    },
  );

  testWidgets(
    'StaggeredEntrance does not replay when an item is rebuilt with the same index',
    (tester) async {
      AppEntranceRegistry.reset();
      addTearDown(AppEntranceRegistry.reset);

      const entranceKey = ValueKey<String>('entrance');
      final Finder opacityFinder = find.descendant(
        of: find.byKey(entranceKey),
        matching: find.byType(Opacity),
      );

      Widget host({required bool present}) => MaterialApp(
            home: SizedBox(
              child: present
                  ? const StaggeredEntrance(
                      key: entranceKey,
                      scope: 'test-grid',
                      index: 3,
                      child: Text('item'),
                    )
                  : const SizedBox.shrink(),
            ),
          );

      // First appearance: entrance starts from fully transparent, then runs
      // once its stagger delay has elapsed.
      await tester.pumpWidget(host(present: true));
      expect(tester.widget<Opacity>(opacityFinder).opacity, lessThan(1.0));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<Opacity>(opacityFinder).opacity, lessThan(1.0));

      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(opacityFinder).opacity, 1.0);

      // Dispose (e.g. scrolled far off-screen)...
      await tester.pumpWidget(host(present: false));
      expect(find.byKey(entranceKey), findsNothing);

      // ...then remount with the same index: must render settled, not replay.
      await tester.pumpWidget(host(present: true));
      expect(tester.widget<Opacity>(opacityFinder).opacity, 1.0);
    },
  );
}
