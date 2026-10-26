import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:yofardev_ai/core/design/components/components.dart';

import '../../../helpers/golden_test_helper.dart';

void main() {
  setUpAll(() async {
    await GoldenTestHelper.init();
  });

  Widget harness(Widget child, {TextDirection? direction}) {
    Widget result = GoldenTestHelper.makeTestableWidget(
      child: Center(child: child),
    );
    if (direction != null) {
      result = Directionality(textDirection: direction, child: result);
    }
    return result;
  }

  group('AppIconButton', () {
    testWidgets('occupies a 48x48 hit area', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          AppIconButton(
            onPressed: () {},
            icon: Icons.close,
            semanticLabel: 'Close',
          ),
        ),
      );
      expect(tester.getSize(find.byType(AppIconButton)), const Size(48, 48));
    });

    testWidgets('taps outside the 36 dp visual still hit', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        harness(
          AppIconButton(
            onPressed: () => taps++,
            icon: Icons.close,
            semanticLabel: 'Close',
          ),
        ),
      );
      final Rect rect = tester.getRect(find.byType(AppIconButton));
      await tester.tapAt(rect.topLeft + const Offset(2, 2));
      expect(taps, 1);
    });

    testWidgets('one tap calls onPressed once', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        harness(
          AppIconButton(
            onPressed: () => taps++,
            icon: Icons.close,
            semanticLabel: 'Close',
          ),
        ),
      );
      await tester.tap(find.byType(AppIconButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('null onPressed is disabled for semantics and taps', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          const AppIconButton(
            onPressed: null,
            icon: Icons.close,
            semanticLabel: 'Close',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(AppIconButton)),
        isSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          label: 'Close',
        ),
      );
      await tester.tap(find.byType(AppIconButton));
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('enabled button exposes an enabled button semantics node', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          AppIconButton(
            onPressed: () {},
            icon: Icons.close,
            semanticLabel: 'Close',
            tooltip: 'Close it',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(AppIconButton)),
        isSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          label: 'Close',
        ),
      );
      handle.dispose();
    });

    testWidgets('survives 1.5x text scale and RTL', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: harness(
            AppIconButton(
              onPressed: () {},
              icon: Icons.close,
              semanticLabel: 'Close',
              tooltip: 'Close',
              active: true,
            ),
            direction: TextDirection.rtl,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AppIconButton)), const Size(48, 48));
    });
  });

  group('AppIconButton goldens', () {
    testGoldens('idle, active, disabled', (WidgetTester tester) async {
      await tester.pumpWidgetBuilder(
        GoldenTestHelper.makeTestableWidget(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AppIconButton(
                  onPressed: () {},
                  icon: Icons.settings,
                  semanticLabel: 'Idle',
                ),
                const SizedBox(width: 16),
                AppIconButton(
                  onPressed: () {},
                  icon: Icons.settings,
                  semanticLabel: 'Active',
                  active: true,
                ),
                const SizedBox(width: 16),
                const AppIconButton(
                  onPressed: null,
                  icon: Icons.settings,
                  semanticLabel: 'Disabled',
                ),
              ],
            ),
          ),
        ),
        surfaceSize: const Size(240, 96),
      );
      await GoldenTestHelper.matchGolden(tester, 'app_icon_button_states');
    });
  });
}
