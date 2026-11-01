import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yofardev_ai/core/design/design.dart';
import 'package:yofardev_ai/core/design/looks/looks.dart';
import 'package:yofardev_ai/core/services/world/world_state_service.dart';
import 'package:yofardev_ai/features/home/screens/ui_lab_screen.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_config.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_service_extension.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_stage_layouts.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_stage_preview.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_surfaces_preview.dart';
import 'package:yofardev_ai/core/design/components/components.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

/// Fake builder: no font is ever loaded.
TextTheme _fakeTextTheme(LookFonts fonts, ColorScheme scheme) =>
    ThemeData.dark().textTheme;

/// Fake stage: no Rive file is ever decoded.
Widget _fakeStage(
  BuildContext context,
  AvatarScene scene,
  TalkingState _,
  FaceFrame? _,
) => SizedBox.expand(key: ValueKey<AvatarScene>(scene));

/// The lab on its Surfaces tab.
final LabConfig _surfaces = LabConfig.initial.copyWith(tab: LabTab.surfaces);

Widget _harness({LabConfig? initial, WorldStateService? world}) => MaterialApp(
  theme: AppTheme.dark,
  home: UiLabScreen(
    textThemeBuilder: _fakeTextTheme,
    initialConfig: initial ?? _surfaces,
    stageBuilder: _fakeStage,
    world: world,
  ),
);

AppTokens _previewTokens(WidgetTester tester) => Theme.of(
  tester.element(find.byType(LabSurfacesPreview)),
).extension<AppTokens>()!;

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpLab(
    WidgetTester tester, {
    LabConfig? initial,
    Size logicalSize = const Size(450, 900),
    WorldStateService? world,
  }) async {
    tester.view.physicalSize = logicalSize * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_harness(initial: initial, world: world));
    await tester.pump();
  }

  testWidgets('shows the controls and the surfaces preview', (
    WidgetTester tester,
  ) async {
    await pumpLab(tester);
    for (final String label in <String>[
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

  testWidgets('has no look switcher and previews Storybook night', (
    WidgetTester tester,
  ) async {
    await pumpLab(tester);
    expect(find.text('Look'), findsNothing);
    expect(find.widgetWithText(AppPill, 'Neon'), findsNothing);
    expect(find.widgetWithText(AppPill, 'Cel'), findsNothing);

    final AppTokens tokens = _previewTokens(tester);
    expect(tokens.radiusScale, UiLooks.storybook.radiusScale);
    expect(tokens.outlineWidth, UiLooks.storybook.outlineWidth);
    expect(tokens.background, UiLooks.storybook.ink);
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

  testWidgets('the stage lays out at phone size, scaled down only visually', (
    WidgetTester tester,
  ) async {
    // A small window with the controls open leaves about 200 px for the
    // preview.
    await pumpLab(
      tester,
      initial: LabConfig.initial,
      logicalSize: const Size(900, 922),
    );
    final Finder stage = find.byType(LabStageLayout);
    expect(tester.getSize(stage), LabStagePreview.canvas);
    expect(tester.getRect(stage).width, lessThan(LabStagePreview.canvas.width));
  });

  testWidgets('the surfaces preview is phone wide in a wide window', (
    WidgetTester tester,
  ) async {
    await pumpLab(tester, logicalSize: const Size(1400, 1000));
    expect(
      tester.getSize(find.byType(LabSurfacesPreview)).width,
      LabStagePreview.canvas.width,
    );
  });

  testWidgets('panelCollapsed hides the controls; the chevron toggles it', (
    WidgetTester tester,
  ) async {
    await pumpLab(tester, initial: _surfaces.copyWith(panelCollapsed: true));
    expect(find.text('Scene'), findsNothing);
    expect(find.widgetWithText(AppPill, 'Stage'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Show controls'));
    await tester.pump();
    expect(find.text('Scene'), findsOneWidget);
    expect(activeUiLabConfig!.value.panelCollapsed, isFalse);

    await tester.tap(find.bySemanticsLabel('Hide controls'));
    await tester.pump();
    expect(find.text('Scene'), findsNothing);
    expect(activeUiLabConfig!.value.panelCollapsed, isTrue);

    // The service extension drives the same flag.
    activeUiLabConfig!.value = activeUiLabConfig!.value.copyWith(
      panelCollapsed: false,
    );
    await tester.pump();
    expect(find.text('Scene'), findsOneWidget);
  });

  testWidgets('never turns on runtime font fetching', (
    WidgetTester tester,
  ) async {
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
    await pumpLab(tester);
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
  });

  testWidgets('closing the lab leaves the world dry', (
    WidgetTester tester,
  ) async {
    final WorldStateService world = WorldStateService();
    addTearDown(world.dispose);
    await pumpLab(tester, world: world);
    world.setRain(1);
    expect(world.rain.value, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(world.rain.value, 0);
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
