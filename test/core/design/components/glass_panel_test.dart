import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:yofardev_ai/core/design/components/components.dart';
import 'package:yofardev_ai/core/design/design.dart';

import '../../../helpers/golden_test_helper.dart';
import 'look_test_theme.dart';

void main() {
  setUpAll(() async {
    await GoldenTestHelper.init();
  });

  group('GlassPanel', () {
    testWidgets('has no BackdropFilter when blur is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        GoldenTestHelper.makeTestableWidget(
          child: const GlassPanel(child: Text('panel')),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('panel'), findsOneWidget);
    });

    testWidgets('has exactly one BackdropFilter when blur is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        GoldenTestHelper.makeTestableWidget(
          child: const GlassPanel(blur: true, child: Text('panel')),
        ),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('applies padding and the look outline width (1 px)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        GoldenTestHelper.makeTestableWidget(
          child: const Center(
            child: GlassPanel(
              padding: EdgeInsets.all(AppSpace.lg),
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        ),
      );
      final Size size = tester.getSize(find.byType(GlassPanel));
      expect(size, const Size(40 + 32, 20 + 32));
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(GlassPanel),
          matching: find.byType(DecoratedBox),
        ),
      );
      final BoxDecoration decoration = box.decoration as BoxDecoration;
      expect((decoration.border! as Border).top.width, 1);
    });
  });

  group('GlassPanel cel', () {
    Future<BoxDecoration> pumpCelPanel(
      WidgetTester tester, {
      bool blur = false,
    }) async {
      await tester.pumpWidget(
        GoldenTestHelper.makeLookTestable(
          theme: celTestTheme(),
          child: Center(
            child: GlassPanel(
              blur: blur,
              child: const SizedBox(width: 40, height: 20),
            ),
          ),
        ),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(GlassPanel),
          matching: find.byType(DecoratedBox),
        ),
      );
      return box.decoration as BoxDecoration;
    }

    testWidgets('is flat and opaque with a 2 px outline and hard shadow', (
      WidgetTester tester,
    ) async {
      final BoxDecoration decoration = await pumpCelPanel(tester);
      final AppTokens tokens = Theme.of(
        tester.element(find.byType(GlassPanel)),
      ).extension<AppTokens>()!;
      expect(decoration.gradient, isNull);
      expect(decoration.color, tokens.glassSurface);
      expect(decoration.color!.a, 1);
      final Border border = decoration.border! as Border;
      expect(border.top.width, 2);
      expect(border.top.color, tokens.glassBorder);
      expect(decoration.boxShadow, hasLength(1));
      final BoxShadow shadow = decoration.boxShadow!.single;
      expect(shadow.offset, const Offset(0, 3));
      expect(shadow.blurRadius, 0);
      expect(shadow.color, tokens.shadow.withValues(alpha: 0.6));
    });

    testWidgets('never blurs, even when blur is requested', (
      WidgetTester tester,
    ) async {
      await pumpCelPanel(tester, blur: true);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('scales the default radius with radiusScale', (
      WidgetTester tester,
    ) async {
      final BoxDecoration decoration = await pumpCelPanel(tester);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(AppRadius.lg * 1.35),
      );
    });
  });

  group('GlassPanel goldens', () {
    testGoldens('thin, regular, thick', (WidgetTester tester) async {
      await tester.pumpWidgetBuilder(
        GoldenTestHelper.makeTestableWidget(
          child: Builder(
            builder: (BuildContext context) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      context.tokens.background,
                      context.colors.surface,
                    ],
                  ),
                ),
                child: Padding(
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
              );
            },
          ),
        ),
        surfaceSize: const Size(300, 300),
      );
      await GoldenTestHelper.matchGolden(tester, 'glass_panel_levels');
    });
  });
}
