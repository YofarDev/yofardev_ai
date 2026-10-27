import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:yofardev_ai/core/design/components/components.dart';

import '../../../helpers/golden_test_helper.dart';
import 'component_test_harness.dart';

void main() {
  setUpAll(() async {
    await GoldenTestHelper.init();
  });

  group('AppPill', () {
    testWidgets('renders its label and calls onTap once per tap', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        GoldenTestHelper.makeTestableWidget(
          child: Center(
            child: AppPill(label: 'Weather', onTap: () => taps++),
          ),
        ),
      );
      expect(find.text('Weather'), findsOneWidget);
      await tester.tap(find.byType(AppPill));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('exposes selected state in semantics', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        GoldenTestHelper.makeTestableWidget(
          child: Center(
            child: AppPill(label: 'Weather', onTap: () {}, selected: true),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Weather')),
        isSemantics(
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          label: 'Weather',
        ),
      );
      handle.dispose();
    });

    testWidgets('does not overflow with RTL, 1.5x text and a tight width', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        componentHarness(
          SizedBox(
            width: 120,
            child: AppPill(
              label: 'A rather long pill label',
              icon: Icons.cloud,
              onTap: () {},
              selected: true,
            ),
          ),
          rtl: true,
          textScale: 1.5,
        ),
      );
      final BuildContext context = tester.element(find.byType(AppPill));
      expect(Directionality.of(context), TextDirection.rtl);
      expect(MediaQuery.textScalerOf(context), const TextScaler.linear(1.5));
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(AppPill)).width,
        lessThanOrEqualTo(120),
      );
      // RTL: the leading icon sits to the right of the label.
      expect(
        tester.getCenter(find.byIcon(Icons.cloud)).dx,
        greaterThan(tester.getCenter(find.byType(Text)).dx),
      );
    });

    testWidgets('tap area is at least 48 dp tall', (WidgetTester tester) async {
      await tester.pumpWidget(
        componentHarness(AppPill(label: 'Tall', onTap: () {})),
      );
      expect(tester.getSize(find.byType(AppPill)).height, 48);
    });

    testWidgets('a callback swapped to null stops firing', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        componentHarness(AppPill(label: 'Pill', onTap: () => taps++)),
      );
      await tester.tap(find.byType(AppPill));
      await tester.pumpAndSettle();
      expect(taps, 1);

      await tester.pumpWidget(componentHarness(const AppPill(label: 'Pill')));
      await tester.tap(find.byType(AppPill));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('mid-press rebuild with onTap null returns to idle', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        componentHarness(AppPill(label: 'Pill', onTap: () => taps++)),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppPill)),
      );
      await tester.pump();
      await tester.pumpWidget(componentHarness(const AppPill(label: 'Pill')));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 0);
      expect(tester.takeException(), isNull);

      // Re-enabling must not show a stale pressed look: tap works normally.
      await tester.pumpWidget(
        componentHarness(AppPill(label: 'Pill', onTap: () => taps++)),
      );
      await tester.tap(find.byType(AppPill));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('Enter on a focused pill fires once', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        componentHarness(AppPill(label: 'Pill', onTap: () => taps++)),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('works in an unbounded row', (WidgetTester tester) async {
      await tester.pumpWidget(
        GoldenTestHelper.makeTestableWidget(
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[AppPill(label: 'One', icon: Icons.cloud)],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AppPill goldens', () {
    testGoldens('idle, selected, with icon', (WidgetTester tester) async {
      await tester.pumpWidgetBuilder(
        GoldenTestHelper.makeTestableWidget(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AppPill(label: 'Idle', onTap: () {}),
                const SizedBox(width: 12),
                AppPill(label: 'Selected', onTap: () {}, selected: true),
                const SizedBox(width: 12),
                AppPill(label: 'Icon', icon: Icons.cloud, onTap: () {}),
              ],
            ),
          ),
        ),
        surfaceSize: const Size(400, 96),
      );
      await GoldenTestHelper.matchGolden(tester, 'app_pill_states');
    });
  });
}
