import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:yofardev_ai/core/design/components/components.dart';
import 'package:yofardev_ai/core/design/design.dart';

import '../../../helpers/golden_test_helper.dart';

void main() {
  setUpAll(() async {
    await GoldenTestHelper.init();
  });

  group('GlassPanel', () {
    group('high contrast (M11 ruling 23)', () {
      Widget highContrast(Widget child) => GoldenTestHelper.makeTestableWidget(
        child: Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(highContrast: true),
            child: child,
          ),
        ),
      );

      testWidgets('draws the opaque surface, with no blur', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          highContrast(
            const GlassPanel(
              blur: true,
              level: AppGlassLevel.thick,
              child: Text('panel'),
            ),
          ),
        );
        expect(find.byType(BackdropFilter), findsNothing);
        expect(find.text('panel'), findsOneWidget);
        final BuildContext context = tester.element(find.text('panel'));
        final DecoratedBox box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(GlassPanel),
            matching: find.byType(DecoratedBox),
          ),
        );
        final BoxDecoration decoration = box.decoration as BoxDecoration;
        expect(decoration.gradient, isNull);
        expect(decoration.color, context.colors.surface);
        expect(decoration.color!.a, 1);
        expect(decoration.border!.top.color.a, 1);
      });

      testWidgets('a custom shape is solid too', (WidgetTester tester) async {
        await tester.pumpWidget(
          highContrast(
            const GlassPanel(
              blur: true,
              shape: StadiumBorder(),
              child: Text('pill'),
            ),
          ),
        );
        expect(find.byType(BackdropFilter), findsNothing);
        expect(find.byType(ClipPath), findsNothing);
        final DecoratedBox box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(GlassPanel),
            matching: find.byType(DecoratedBox),
          ),
        );
        final ShapeDecoration decoration = box.decoration as ShapeDecoration;
        expect(decoration.color!.a, 1);
        expect(decoration.gradient, isNull);
      });

      testWidgets('without it the panel stays translucent glass', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          GoldenTestHelper.makeTestableWidget(
            child: const GlassPanel(blur: true, child: Text('panel')),
          ),
        );
        final DecoratedBox box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(GlassPanel),
            matching: find.byType(DecoratedBox),
          ),
        );
        expect((box.decoration as BoxDecoration).gradient, isNotNull);
        expect(find.byType(BackdropFilter), findsOneWidget);
      });
    });

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

  group('GlassPanel shape', () {
    testWidgets('a StadiumBorder is painted with the glass outline', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        GoldenTestHelper.makeTestableWidget(
          child: const GlassPanel(
            shape: StadiumBorder(),
            child: SizedBox(width: 80, height: 30),
          ),
        ),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(GlassPanel),
          matching: find.byType(DecoratedBox),
        ),
      );
      final ShapeDecoration decoration = box.decoration as ShapeDecoration;
      final StadiumBorder shape = decoration.shape as StadiumBorder;
      final AppTokens tokens = tester.element(find.byType(GlassPanel)).tokens;
      expect(shape.side.width, tokens.outlineWidth);
      expect(
        shape.side.color.a,
        closeTo(tokens.glassRegular.borderAlpha, 0.02),
      );
      expect(decoration.gradient, isA<LinearGradient>());
    });

    testWidgets('blur is clipped to the shape', (WidgetTester tester) async {
      await tester.pumpWidget(
        GoldenTestHelper.makeTestableWidget(
          child: const GlassPanel(
            shape: StadiumBorder(),
            blur: true,
            child: SizedBox(width: 80, height: 30),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
      final ClipPath clip = tester.widget<ClipPath>(
        find.descendant(
          of: find.byType(GlassPanel),
          matching: find.byType(ClipPath),
        ),
      );
      expect(clip.clipper, isA<ShapeBorderClipper>());
      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets('without a shape it is still the rounded rectangle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        GoldenTestHelper.makeTestableWidget(
          child: const GlassPanel(blur: true, child: Text('panel')),
        ),
      );
      expect(find.byType(ClipRRect), findsOneWidget);
      expect(find.byType(ClipPath), findsNothing);
    });

    testWidgets('a speech bubble shape paints and its tail adds no clip', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        GoldenTestHelper.makeTestableWidget(
          child: const Center(
            child: GlassPanel(
              shape: SpeechBubbleBorder(),
              blur: true,
              padding: EdgeInsets.only(bottom: SpeechBubbleBorder.tailHeight),
              child: SizedBox(width: 120, height: 40),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(GlassPanel)),
        const Size(120, 40 + SpeechBubbleBorder.tailHeight),
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
