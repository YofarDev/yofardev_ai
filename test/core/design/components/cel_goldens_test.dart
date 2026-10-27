import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:yofardev_ai/core/design/components/components.dart';
import 'package:yofardev_ai/core/design/design.dart';

import '../../../helpers/golden_test_helper.dart';
import 'look_test_theme.dart';

/// Goldens of the kit components under the Cel look (lab look goldens only).
void main() {
  setUpAll(() async {
    await GoldenTestHelper.init();
  });

  Widget celApp(Widget child) {
    return GoldenTestHelper.makeLookTestable(
      theme: celTestTheme(),
      child: Builder(
        builder: (BuildContext context) {
          return ColoredBox(color: context.tokens.background, child: child);
        },
      ),
    );
  }

  group('Cel goldens', () {
    testGoldens('glass panel levels', (WidgetTester tester) async {
      await tester.pumpWidgetBuilder(
        celApp(
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                for (final AppGlassLevel level in AppGlassLevel.values)
                  GlassPanel(
                    level: level,
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(level.name),
                    ),
                  ),
              ],
            ),
          ),
        ),
        surfaceSize: const Size(300, 300),
      );
      await GoldenTestHelper.matchGolden(tester, 'glass_panel_levels_cel');
    });

    testGoldens('pill states', (WidgetTester tester) async {
      await tester.pumpWidgetBuilder(
        celApp(
          Center(
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
      await GoldenTestHelper.matchGolden(tester, 'app_pill_states_cel');
    });

    testGoldens('icon button states', (WidgetTester tester) async {
      await tester.pumpWidgetBuilder(
        celApp(
          Center(
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
      await GoldenTestHelper.matchGolden(tester, 'app_icon_button_states_cel');
    });
  });
}
