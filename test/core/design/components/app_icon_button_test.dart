import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:yofardev_ai/core/design/components/components.dart';
import 'package:yofardev_ai/core/design/design.dart';

import '../../../helpers/golden_test_helper.dart';
import 'component_test_harness.dart';
import 'look_test_theme.dart';

void main() {
  setUpAll(() async {
    await GoldenTestHelper.init();
  });

  Widget harness(Widget child, {bool rtl = false, double textScale = 1}) {
    return componentHarness(child, rtl: rtl, textScale: textScale);
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
        tester.getSemantics(find.bySemanticsLabel('Close')),
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
        tester.getSemantics(find.bySemanticsLabel('Close')),
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
        harness(
          AppIconButton(
            onPressed: () {},
            icon: Icons.close,
            semanticLabel: 'Close',
            tooltip: 'Close',
            active: true,
          ),
          rtl: true,
          textScale: 1.5,
        ),
      );
      final BuildContext context = tester.element(find.byType(AppIconButton));
      expect(Directionality.of(context), TextDirection.rtl);
      expect(MediaQuery.textScalerOf(context), const TextScaler.linear(1.5));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AppIconButton)), const Size(48, 48));
    });

    testWidgets('disabled is dimmed to 0.4, enabled is opaque', (
      WidgetTester tester,
    ) async {
      Finder opacity() => find.descendant(
        of: find.byType(AppIconButton),
        matching: find.byType(Opacity),
      );
      await tester.pumpWidget(
        harness(
          AppIconButton(
            onPressed: () {},
            icon: Icons.close,
            semanticLabel: 'Close',
          ),
        ),
      );
      expect(tester.widget<Opacity>(opacity()).opacity, 1);

      await tester.pumpWidget(
        harness(
          const AppIconButton(
            onPressed: null,
            icon: Icons.close,
            semanticLabel: 'Close',
          ),
        ),
      );
      expect(tester.widget<Opacity>(opacity()).opacity, 0.4);
    });

    testWidgets('a callback swapped to null stops firing', (
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
      await tester.tap(find.byType(AppIconButton));
      await tester.pumpAndSettle();
      expect(taps, 1);

      await tester.pumpWidget(
        harness(
          const AppIconButton(
            onPressed: null,
            icon: Icons.close,
            semanticLabel: 'Close',
          ),
        ),
      );
      await tester.tap(find.byType(AppIconButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('mid-press rebuild with onPressed null returns to idle', (
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
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppIconButton)),
      );
      await tester.pump();
      await tester.pumpWidget(
        harness(
          const AppIconButton(
            onPressed: null,
            icon: Icons.close,
            semanticLabel: 'Close',
          ),
        ),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Enter on a focused button fires once', (
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
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('AppIconButton cel', () {
    Future<BoxDecoration> pumpButton(
      WidgetTester tester, {
      bool active = false,
    }) async {
      await tester.pumpWidget(
        GoldenTestHelper.makeLookTestable(
          theme: celTestTheme(),
          child: Center(
            child: AppIconButton(
              onPressed: () {},
              icon: Icons.settings,
              semanticLabel: 'Settings',
              active: active,
            ),
          ),
        ),
      );
      final Container container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppIconButton),
          matching: find.byType(Container),
        ),
      );
      return container.decoration! as BoxDecoration;
    }

    AppTokens tokensOf(WidgetTester tester) {
      return Theme.of(
        tester.element(find.byType(AppIconButton)),
      ).extension<AppTokens>()!;
    }

    testWidgets('idle is flat, outlined and has a hard shadow', (
      WidgetTester tester,
    ) async {
      final BoxDecoration decoration = await pumpButton(tester);
      final AppTokens tokens = tokensOf(tester);
      expect(decoration.gradient, isNull);
      expect(decoration.color, tokens.glassSurface);
      expect((decoration.border! as Border).top.width, 2);
      expect(decoration.boxShadow!.single.offset, const Offset(0, 3));
      expect(decoration.boxShadow!.single.blurRadius, 0);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(AppRadius.md * 1.35),
      );
    });

    testWidgets('active fills with the scene accent and draws onAccent', (
      WidgetTester tester,
    ) async {
      final BoxDecoration decoration = await pumpButton(tester, active: true);
      final AppTokens tokens = tokensOf(tester);
      expect(decoration.color, tokens.scene.accent);
      final Icon icon = tester.widget<Icon>(find.byIcon(Icons.settings));
      expect(icon.color, tokens.scene.onAccent);
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
