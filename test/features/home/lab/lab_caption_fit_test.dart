import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yofardev_ai/core/design/looks/looks.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_caption.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_config.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_stage_preview.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

/// The bundled app fonts (Storybook: Fraunces display, Manrope text), which
/// are the shipping fonts: every look is measured with their real metrics, so
/// the captions must fit the slot itself (no margin for a stand-in font).
TextTheme _bundledTextTheme(LookFonts _, ColorScheme scheme) =>
    googleFontsTextThemeBuilder(UiLooks.storybook.fonts, scheme);

Widget _emptyStage(BuildContext context, AvatarScene scene, TalkingState _) =>
    const SizedBox.expand();

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final UiLook look in UiLooks.all) {
    for (final LabLayout layout in LabLayout.values) {
      testWidgets('${look.id} ${layout.name}: captions fit two lines', (
        WidgetTester tester,
      ) async {
        for (final AvatarScene scene in AvatarScene.values) {
          final LabConfig config = LabConfig.initial.copyWith(
            lookId: look.id,
            layout: layout,
            scene: scene,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: buildLookTheme(
                look,
                scene,
                textThemeBuilder: _bundledTextTheme,
              ),
              home: Scaffold(
                body: LabStagePreview(
                  config: config,
                  stageBuilder: _emptyStage,
                ),
              ),
            ),
          );
          await tester.runAsync(() => GoogleFonts.pendingFonts());
          await tester.pump();

          final String caption = LabCaption.sampleFor(scene);
          final Finder text = find.text(caption);
          expect(text, findsOneWidget, reason: caption);
          final RenderParagraph paragraph = tester.renderObject(text);
          expect(paragraph.didExceedMaxLines, isFalse, reason: caption);

          // The slot is what the caption's balancing LayoutBuilder is given.
          final RenderBox slot = tester.renderObject(
            find.ancestor(of: text, matching: find.byType(LayoutBuilder)).first,
          );
          final double slotWidth = slot.constraints.maxWidth;
          final TextPainter painter = TextPainter(
            text: paragraph.text,
            textDirection: TextDirection.ltr,
            textScaler: paragraph.textScaler,
          )..layout(maxWidth: slotWidth);
          final int lines = painter.computeLineMetrics().length;
          painter.dispose();
          expect(
            lines,
            lessThanOrEqualTo(2),
            reason: '"$caption" in ${slotWidth.round()} px',
          );
        }
      });
    }
  }
}
