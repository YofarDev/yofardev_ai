import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yofardev_ai/core/design/components/components.dart';
import 'package:yofardev_ai/core/design/design.dart';
import 'package:yofardev_ai/core/design/looks/looks.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/home/screens/ui_lab_screen.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_service_extension.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

/// Fake builder: no font is ever loaded.
TextTheme _fakeTextTheme(LookFonts fonts, ColorScheme scheme) =>
    ThemeData.dark().textTheme;

/// Records the face the stage avatar would be given, without decoding any
/// Rive file.
class _FaceProbe {
  final List<FaceFrame?> faces = <FaceFrame?>[];

  FaceFrame? get last => faces.last;

  Widget build(
    BuildContext context,
    AvatarScene scene,
    TalkingState talking,
    FaceFrame? face,
  ) {
    faces.add(face);
    return const SizedBox.expand();
  }
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<_FaceProbe> pumpLab(WidgetTester tester, {Size? size}) async {
    final Size logical = size ?? const Size(390, 844);
    tester.view.physicalSize = logical * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final _FaceProbe probe = _FaceProbe();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: UiLabScreen(
          textThemeBuilder: _fakeTextTheme,
          stageBuilder: probe.build,
        ),
      ),
    );
    await tester.pump();
    return probe;
  }

  Future<void> open(WidgetTester tester, String section) async {
    final Finder button = find.bySemanticsLabel('Show $section');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('the face section starts folded, on the live face', (
    WidgetTester tester,
  ) async {
    final _FaceProbe probe = await pumpLab(tester);
    expect(find.text('Face'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('lab-face-auJawDrop')),
      findsNothing,
    );
    expect(probe.last, isNull);
  });

  testWidgets('dragging auJawDrop overrides the stage avatar face', (
    WidgetTester tester,
  ) async {
    final _FaceProbe probe = await pumpLab(tester);
    await open(tester, 'Face');
    await open(tester, 'Action units');
    final Finder slider = find.byKey(
      const ValueKey<String>('lab-face-auJawDrop'),
    );
    await tester.ensureVisible(slider);
    await tester.pump();
    await tester.drag(slider, const Offset(400, 0));
    await tester.pump();

    final FaceFrame face = probe.last!;
    expect(face.au.jawDrop, 1);
    expect(face.autoBlink, isFalse);
    expect(activeUiLabConfig!.value.face, face);
    expect(find.text('Override'), findsOneWidget);

    // Reset goes back to the live face.
    final Finder reset = find.widgetWithText(AppPill, 'Reset');
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pump();
    expect(probe.last, isNull);
    expect(activeUiLabConfig!.value.face, isNull);
  });

  testWidgets('a side offset slider spans -1..1', (WidgetTester tester) async {
    final _FaceProbe probe = await pumpLab(tester);
    await open(tester, 'Face');
    await open(tester, "Sides (viewer's L / R)");
    final Finder slider = find.byKey(
      const ValueKey<String>('lab-face-auBrowOuterUpR'),
    );
    await tester.ensureVisible(slider);
    await tester.pump();
    await tester.drag(slider, const Offset(-400, 0));
    await tester.pump();
    expect(probe.last!.right.browOuterUp, -1);
  });

  testWidgets('mood, viseme and blink build the override', (
    WidgetTester tester,
  ) async {
    final _FaceProbe probe = await pumpLab(tester);
    await open(tester, 'Face');

    // The composer row also has a Thinking pill; the mood row comes last.
    final Finder thinking = find.widgetWithText(AppPill, 'Thinking').last;
    await tester.ensureVisible(thinking);
    await tester.tap(thinking);
    await tester.pump();
    expect(probe.last!.right.browOuterUp, 0.35);

    final Finder ff = find.widgetWithText(AppPill, 'ff');
    await tester.ensureVisible(ff);
    await tester.tap(ff);
    await tester.pump();
    expect(probe.last!.lipTuck, 1);
    expect(probe.last!.right.browOuterUp, 0.35);

    final Finder blink = find.widgetWithText(AppPill, 'Blink');
    await tester.ensureVisible(blink);
    await tester.tap(blink);
    await tester.pump();
    expect(probe.last!.blinkSerial, 1);
    expect(probe.last!.lipTuck, 1);
  });

  testWidgets('the open face section fits a 360 px wide phone', (
    WidgetTester tester,
  ) async {
    await pumpLab(tester, size: const Size(360, 740));
    await open(tester, 'Face');
    await open(tester, 'Action units');
    await open(tester, "Sides (viewer's L / R)");
    await open(tester, 'Mouth & head');
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey<String>('lab-face-auLipCornerDepressR')),
      findsOneWidget,
    );
  });
}
