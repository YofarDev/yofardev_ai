import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yofardev_ai/core/design/rive/ui_kit_file.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/features/home/widgets/home_content_stack.dart';
import 'package:yofardev_ai/features/home/widgets/stage/scene_picker_sheet.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_composer.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_menu.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_tool_chip.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_top_bar.dart';

import '../../helpers/rive_test_assets.dart';
import 'stage_harness.dart';

/// M11 ruling 19: at text scale 1.0, 1.5 and 2.0 the top chips, the More
/// menu, the scene picker (two columns from 1.5, names on up to two lines),
/// the running-tool chip and the composer lay out without overflow, in
/// English and French, on a 390×844 phone and a small 360×640 one.
void main() {
  late StageHarness h;
  late AppLifecycleService lifecycle;

  setUp(() {
    serveFakeRiveAssets();
    UiKitFile.resetForTest();
    h = StageHarness();
    lifecycle = AppLifecycleService();
  });

  tearDown(() => lifecycle.dispose());

  Future<void> pumpStage(
    WidgetTester tester, {
    required double scale,
    required Size size,
    required Locale locale,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The platform's text scale, so routes (the menu, the picker) get it too.
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    h.chat.emit(h.chat.state.copyWith(activeTool: 'getCurrentWeather'));
    await tester.pumpWidget(
      h.app(
        Scaffold(
          resizeToAvoidBottomInset: false,
          body: HomeContentStack(
            speech: h.speech,
            lifecycle: lifecycle,
            onStartDemo: () {},
          ),
        ),
        locale: locale,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Every [Text] under [of] fits its lines (no ellipsis) and its box.
  void expectTextsFit(WidgetTester tester, Finder of, {String? reason}) {
    final Finder texts = find.descendant(of: of, matching: find.byType(Text));
    for (final Element text in texts.evaluate()) {
      final RenderObject? render = text.findRenderObject();
      if (render is! RenderParagraph) {
        continue;
      }
      expect(
        render.didExceedMaxLines,
        isFalse,
        reason: '${(text.widget as Text).data} is cut ($reason)',
      );
    }
  }

  const List<Size> sizes = <Size>[Size(390, 844), Size(360, 640)];
  const List<Locale> locales = <Locale>[Locale('en'), Locale('fr')];

  for (final double scale in <double>[1.0, 1.5, 2.0]) {
    for (final Size size in sizes) {
      for (final Locale locale in locales) {
        final String what =
            '×$scale, ${size.width.toInt()}×${size.height.toInt()}, '
            '${locale.languageCode}';

        testWidgets('the stage chrome lays out ($what)', (
          WidgetTester tester,
        ) async {
          await pumpStage(tester, scale: scale, size: size, locale: locale);
          expect(tester.takeException(), isNull);
          expect(find.byType(StageTopBar), findsOneWidget);
          expect(find.byType(StageToolChip), findsOneWidget);
          expect(find.byType(StageComposer), findsOneWidget);
          expectTextsFit(tester, find.byType(StageTopBar), reason: what);
          expectTextsFit(tester, find.byType(StageToolChip), reason: what);
          // the chrome stays on screen
          final Rect composer = tester.getRect(find.byType(StageComposer));
          expect(composer.left, greaterThanOrEqualTo(0));
          expect(composer.right, lessThanOrEqualTo(size.width));
          expect(composer.bottom, lessThanOrEqualTo(size.height));
          final Rect top = tester.getRect(find.byType(StageTopBar));
          expect(top.right, lessThanOrEqualTo(size.width));
        });

        testWidgets('the More menu lays out ($what)', (
          WidgetTester tester,
        ) async {
          await pumpStage(tester, scale: scale, size: size, locale: locale);
          await tester.tap(
            find.bySemanticsLabel(
              locale.languageCode == 'fr' ? 'Menu' : 'Menu',
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          expect(find.byType(StageMenuPanel), findsOneWidget);
          expect(find.byType(StageMenuRow), findsNWidgets(6));
          expectTextsFit(tester, find.byType(StageMenuPanel), reason: what);
          final Rect panel = tester.getRect(find.byType(StageMenuPanel));
          expect(panel.left, greaterThanOrEqualTo(0));
          expect(panel.right, lessThanOrEqualTo(size.width));
        });

        testWidgets('the scene picker lays out ($what)', (
          WidgetTester tester,
        ) async {
          await pumpStage(tester, scale: scale, size: size, locale: locale);
          await tester.tap(find.bySemanticsLabel('Menu'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(
            find.text(locale.languageCode == 'fr' ? 'Décors' : 'Scenes'),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull);
          expect(find.byType(ScenePickerSheet), findsOneWidget);
          final GridView grid = tester.widget<GridView>(
            find.descendant(
              of: find.byType(ScenePickerSheet),
              matching: find.byType(GridView),
            ),
          );
          final SliverGridDelegateWithFixedCrossAxisCount layout =
              grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
          expect(
            layout.crossAxisCount,
            scale >= 1.5 || size.width < 390 ? 2 : 3,
          );
          // every name shows whole, on at most two lines
          for (final AvatarScene scene in AvatarScene.values) {
            final Finder tile = find.byKey(
              ValueKey<String>('scene-tile-${scene.name}'),
            );
            expect(tile, findsOneWidget);
            expectTextsFit(tester, tile, reason: '$what, ${scene.name}');
          }
        });
      }
    }
  }
}
