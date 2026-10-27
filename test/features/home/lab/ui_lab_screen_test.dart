import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yofardev_ai/core/design/design.dart';
import 'package:yofardev_ai/core/design/looks/looks.dart';
import 'package:yofardev_ai/features/home/screens/ui_lab_screen.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_config.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_stage_preview.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_surfaces_preview.dart';
import 'package:yofardev_ai/core/design/components/components.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

/// Fake builder: no font is ever loaded.
TextTheme _fakeTextTheme(LookFonts fonts, ColorScheme scheme) =>
    ThemeData.dark().textTheme;

/// Fake stage: no Rive file is ever decoded.
Widget _fakeStage(BuildContext context, AvatarScene scene, TalkingState _) =>
    SizedBox.expand(key: ValueKey<AvatarScene>(scene));

/// The lab on its Surfaces tab.
final LabConfig _surfaces = LabConfig.initial.copyWith(tab: LabTab.surfaces);

Widget _harness({LabConfig? initial}) => MaterialApp(
  theme: AppTheme.dark,
  home: UiLabScreen(
    textThemeBuilder: _fakeTextTheme,
    initialConfig: initial ?? _surfaces,
    stageBuilder: _fakeStage,
  ),
);

AppTokens _previewTokens(WidgetTester tester) => Theme.of(
  tester.element(find.byType(LabSurfacesPreview)),
).extension<AppTokens>()!;

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpLab(WidgetTester tester, {LabConfig? initial}) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_harness(initial: initial));
    await tester.pump();
  }

  testWidgets('shows the controls and the surfaces preview', (
    WidgetTester tester,
  ) async {
    await pumpLab(tester);
    for (final String label in <String>[
      'Look',
      'Scene',
      'Layout',
      'Composer',
      'Accent hue',
      'Glass',
      'Radius',
      'Copy config',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.byType(LabSurfacesPreview), findsOneWidget);
    expect(find.text('Searched the web · 3 results'), findsOneWidget);
  });

  testWidgets('switching the look to cel changes the preview surface style', (
    WidgetTester tester,
  ) async {
    await pumpLab(tester);
    expect(_previewTokens(tester).surfaceStyle, AppSurfaceStyle.glass);

    await tester.tap(find.widgetWithText(AppPill, 'Cel'));
    await tester.pump();

    expect(_previewTokens(tester).surfaceStyle, AppSurfaceStyle.cel);
    expect(_previewTokens(tester).radiusScale, UiLooks.cel.radiusScale);
  });

  testWidgets('opens on the stage tab, a mock Home over the stage', (
    WidgetTester tester,
  ) async {
    await pumpLab(tester, initial: LabConfig.initial);
    expect(find.byType(LabStagePreview), findsOneWidget);
    expect(
      find.byKey(const ValueKey<AvatarScene>(AvatarScene.livingRoom)),
      findsOneWidget,
    );
    expect(find.byType(LabSurfacesPreview), findsNothing);

    await tester.tap(find.widgetWithText(AppPill, 'Beach'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<AvatarScene>(AvatarScene.beach)),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(AppPill, 'Surfaces'));
    await tester.pump();
    expect(find.byType(LabStagePreview), findsNothing);
    expect(find.byType(LabSurfacesPreview), findsOneWidget);
  });

  testWidgets('enables font fetching while mounted and restores it after', (
    WidgetTester tester,
  ) async {
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
    await pumpLab(tester);
    expect(GoogleFonts.config.allowRuntimeFetching, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
  });

  testWidgets('applies the hue override to the preview accent', (
    WidgetTester tester,
  ) async {
    await pumpLab(tester, initial: _surfaces.copyWith(accentHueOverride: 300));
    final HSVColor accent = HSVColor.fromColor(
      _previewTokens(tester).scene.accent,
    );
    expect(accent.hue, closeTo(300, 1));
  });
}
