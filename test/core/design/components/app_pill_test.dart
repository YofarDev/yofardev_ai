import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:yofardev_ai/core/design/components/components.dart';

import '../../../helpers/golden_test_helper.dart';

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
        tester.getSemantics(find.byType(AppPill)),
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
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: GoldenTestHelper.makeTestableWidget(
              child: Center(
                child: SizedBox(
                  width: 120,
                  child: AppPill(
                    label: 'A rather long pill label',
                    icon: Icons.cloud,
                    onTap: () {},
                    selected: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
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
