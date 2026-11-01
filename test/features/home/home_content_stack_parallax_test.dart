import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart' show AccelerometerEvent;
import 'package:yofardev_ai/core/design/rive/ui_kit_file.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/services/motion/parallax_source.dart';
import 'package:yofardev_ai/core/services/power/power_saver_source.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/rive_scene_view.dart';
import 'package:yofardev_ai/features/home/widgets/home_content_stack.dart';

import '../../helpers/rive_test_assets.dart';
import 'stage_harness.dart';

class _NoPowerSaver implements PowerSaverSource {
  @override
  Future<bool> get isOn async => false;

  @override
  Stream<bool> get changes => const Stream<bool>.empty();
}

void main() {
  late StageHarness h;
  late ParallaxSource parallax;
  late List<Offset> seen;

  setUp(() {
    serveFakeRiveAssets();
    UiKitFile.resetForTest();
    h = StageHarness();
    parallax = ParallaxSource(
      reduceMotion: () => false,
      power: _NoPowerSaver(),
    );
    seen = <Offset>[];
    parallax.values.listen(seen.add);
  });

  tearDown(() async {
    await parallax.dispose();
  });

  Future<void> pumpStack(WidgetTester tester) async {
    await tester.pumpWidget(
      h.app(
        Scaffold(
          resizeToAvoidBottomInset: false,
          body: HomeContentStack(
            speech: h.speech,
            parallax: parallax,
            onStartDemo: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('hovering the stage reports the pointer, -1..1, +y up', (
    WidgetTester tester,
  ) async {
    await pumpStack(tester);
    final Rect stage = tester.getRect(find.byType(HomeContentStack));
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: stage.center);
    await mouse.moveTo(Offset(stage.right - 0.1, stage.top + 0.1));
    await tester.pump();
    expect(parallax.value.dx, closeTo(1, 1e-3));
    expect(parallax.value.dy, closeTo(1, 1e-3));

    await mouse.moveTo(Offset(stage.left + 0.1, stage.bottom - 0.1));
    await tester.pump();
    expect(parallax.value.dx, closeTo(-1, 1e-3));
    expect(parallax.value.dy, closeTo(-1, 1e-3));

    await mouse.moveTo(
      Offset(stage.left + stage.width * 0.75, stage.center.dy),
    );
    await tester.pump();
    expect(parallax.value.dx, closeTo(0.5, 1e-3));
    expect(parallax.value.dy, closeTo(0, 1e-3));
  });

  testWidgets('the pointer leaving the stage recentres it', (
    WidgetTester tester,
  ) async {
    await pumpStack(tester);
    final Rect stage = tester.getRect(find.byType(HomeContentStack));
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: stage.center);
    await mouse.moveTo(Offset(stage.right - 1, stage.center.dy));
    await tester.pump();
    expect(parallax.value.dx, greaterThan(0.9));
    await mouse.moveTo(const Offset(-50, -50));
    await tester.pump();
    expect(parallax.value, Offset.zero);
    await mouse.removePointer();
  });

  testWidgets('the scene view parks the sensors until a diorama is loaded', (
    WidgetTester tester,
  ) async {
    final ParallaxSource tilt = ParallaxSource(
      accel: const Stream<AccelerometerEvent>.empty(),
      reduceMotion: () => false,
      power: _NoPowerSaver(),
    );
    addTearDown(tilt.dispose);
    expect(tilt.active, isTrue);
    await tester.pumpWidget(
      h.app(
        Scaffold(
          body: RiveSceneView(
            scene: AvatarScene.campfire,
            sceneEvent: (sceneEvent: SceneEvent.flare, seq: 0),
            parallax: tilt,
          ),
        ),
      ),
    );
    // the file has not loaded: nothing to move yet
    expect(tilt.active, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(tilt.active, isFalse);
  });

  test('every scene is a diorama (M5)', () {
    expect(<AvatarScene>[
      for (final AvatarScene s in AvatarScene.values)
        if (s.isDiorama) s,
    ], AvatarScene.values);
  });

  testWidgets('without a parallax source the stack has no hover region', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      h.app(
        Scaffold(
          resizeToAvoidBottomInset: false,
          body: HomeContentStack(speech: h.speech, onStartDemo: () {}),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(HomeContentStack),
        matching: find.byWidgetPredicate(
          (Widget w) => w is MouseRegion && w.onHover != null,
        ),
      ),
      findsNothing,
    );
    expect(seen, isEmpty);
  });
}
