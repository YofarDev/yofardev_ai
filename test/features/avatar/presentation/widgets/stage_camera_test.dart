import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/shot.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/stage_framing.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/stage_camera.dart';

const Size _stage = Size(390, 844);

void main() {
  late ValueNotifier<CameraShot> shot;
  late List<double> scales;

  setUp(() {
    shot = ValueNotifier<CameraShot>(CameraShot.initial);
    scales = <double>[];
    addTearDown(shot.dispose);
  });

  Future<void> mount(
    WidgetTester tester, {
    Size size = _stage,
    double dpr = 1,
  }) async {
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(size: size, devicePixelRatio: dpr),
          child: Center(
            child: SizedBox.fromSize(
              size: size,
              child: StageCamera(
                shot: shot,
                child: Builder(
                  builder: (BuildContext context) {
                    scales.add(StageRenderScale.of(context));
                    return const SizedBox.expand();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The camera's current (zoom, translation).
  ({double zoom, Offset translate}) framing(WidgetTester tester) {
    final Transform transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(StageCamera),
        matching: find.byType(Transform),
      ),
    );
    final Float64List m = transform.transform.storage;
    return (zoom: m[0], translate: Offset(m[12], m[13]));
  }

  testWidgets('StageRenderScale.of is 1 without a camera', (
    WidgetTester tester,
  ) async {
    late double scale;
    await tester.pumpWidget(
      Builder(
        builder: (BuildContext context) {
          scale = StageRenderScale.of(context);
          return const SizedBox();
        },
      ),
    );
    expect(scale, 1);
  });

  testWidgets('starts on the whole stage', (WidgetTester tester) async {
    await mount(tester);
    final ({double zoom, Offset translate}) f = framing(tester);
    expect(f.zoom, 1);
    expect(f.translate, Offset.zero);
    expect(scales.last, 1);
  });

  testWidgets('a cut jumps in one frame', (WidgetTester tester) async {
    await mount(tester);
    shot.value = const CameraShot(
      shot: Shot.medium,
      move: CameraMove.cut,
      serial: 1,
    );
    await tester.pump();
    final ({double zoom, Offset translate}) want = StageFraming.of(
      Shot.medium,
      _stage,
    );
    final ({double zoom, Offset translate}) f = framing(tester);
    expect(f.zoom, closeTo(want.zoom, 1e-9));
    expect(f.translate.dy, closeTo(want.translate.dy, 1e-9));
    // and nothing is left running
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('an ease is midway halfway and on target after its duration', (
    WidgetTester tester,
  ) async {
    await mount(tester);
    shot.value = const CameraShot(
      shot: Shot.closeUp,
      move: CameraMove.ease,
      duration: Duration(seconds: 1),
      serial: 1,
    );
    await tester.pump();
    expect(framing(tester).zoom, closeTo(1, 1e-9));

    final double target = StageFraming.of(Shot.closeUp, _stage).zoom;
    await tester.pump(const Duration(milliseconds: 500));
    // cubic in-out is half way at half time (a frame's slack either way)
    expect(framing(tester).zoom, closeTo((1 + target) / 2, 0.05));

    await tester.pump(const Duration(milliseconds: 250));
    final double late = framing(tester).zoom;
    expect(late, greaterThan((1 + target) / 2));
    expect(late, lessThan(target));

    await tester.pump(const Duration(milliseconds: 250));
    expect(framing(tester).zoom, closeTo(target, 1e-9));
    expect(
      framing(tester).translate.dy,
      closeTo(StageFraming.of(Shot.closeUp, _stage).translate.dy, 1e-9),
    );
  });

  testWidgets('the ticker stops once settled', (WidgetTester tester) async {
    await mount(tester);
    shot.value = const CameraShot(
      shot: Shot.medium,
      move: CameraMove.ease,
      duration: Duration(milliseconds: 600),
      serial: 1,
    );
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('creep adds zoom linearly over its duration', (
    WidgetTester tester,
  ) async {
    await mount(tester);
    shot.value = const CameraShot(
      shot: Shot.medium,
      move: CameraMove.cut,
      creep: 0.04,
      creepDuration: Duration(seconds: 4),
      serial: 1,
    );
    await tester.pump();
    final double base = StageFraming.of(Shot.medium, _stage).zoom;
    expect(framing(tester).zoom, closeTo(base, 1e-6));
    await tester.pump(const Duration(seconds: 2));
    expect(framing(tester).zoom, closeTo(base * 1.02, 2e-3));
    await tester.pump(const Duration(seconds: 2));
    expect(framing(tester).zoom, closeTo(base * 1.04, 1e-9));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isFalse);

    // the next sentence: more creep on the same shot, continuing from there
    shot.value = const CameraShot(
      shot: Shot.medium,
      move: CameraMove.ease,
      creep: 0.08,
      creepDuration: Duration(seconds: 4),
      serial: 2,
    );
    await tester.pump();
    expect(framing(tester).zoom, closeTo(base * 1.04, 1e-6));
    await tester.pump(const Duration(seconds: 2));
    expect(framing(tester).zoom, closeTo(base * 1.06, 2e-3));
  });

  testWidgets('wide ignores creep', (WidgetTester tester) async {
    await mount(tester);
    shot.value = const CameraShot(
      shot: Shot.wide,
      move: CameraMove.cut,
      creep: 0.1,
      creepDuration: Duration(seconds: 1),
      serial: 1,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(framing(tester).zoom, 1);
  });

  testWidgets('a new command mid-ease starts from where the camera is', (
    WidgetTester tester,
  ) async {
    await mount(tester);
    shot.value = const CameraShot(
      shot: Shot.closeUp,
      move: CameraMove.ease,
      duration: Duration(seconds: 1),
      serial: 1,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final double mid = framing(tester).zoom;
    shot.value = const CameraShot(
      shot: Shot.wide,
      move: CameraMove.ease,
      duration: Duration(seconds: 1),
      serial: 2,
    );
    await tester.pump();
    expect(framing(tester).zoom, closeTo(mid, 1e-6));
    await tester.pump(const Duration(seconds: 1));
    expect(framing(tester).zoom, closeTo(1, 1e-9));
  });

  testWidgets('a size change reframes at once', (WidgetTester tester) async {
    await mount(tester);
    shot.value = const CameraShot(
      shot: Shot.closeUp,
      move: CameraMove.ease,
      duration: Duration(seconds: 2),
      serial: 1,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    const Size landscape = Size(1280, 800);
    await mount(tester, size: landscape);
    await tester.pump();
    final ({double zoom, Offset translate}) want = StageFraming.of(
      Shot.closeUp,
      landscape,
    );
    expect(framing(tester).zoom, closeTo(want.zoom, 1e-9));
    expect(framing(tester).translate.dx, closeTo(want.translate.dx, 1e-9));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  group('StageRenderScale', () {
    testWidgets('follows the command, not the frames of the move', (
      WidgetTester tester,
    ) async {
      await mount(tester, dpr: 1);
      expect(scales.last, 1);
      final int built = scales.length;
      shot.value = const CameraShot(
        shot: Shot.medium,
        move: CameraMove.ease,
        duration: Duration(seconds: 1),
        serial: 1,
      );
      await tester.pump();
      final double target = StageFraming.of(Shot.medium, _stage).zoom;
      expect(scales.last, closeTo(cameraRenderScale(target, 1), 1e-9));
      final int afterCommand = scales.length;
      expect(afterCommand, built + 1);
      // eleven frames of the move: the child is not rebuilt
      for (int i = 0; i < 11; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(scales.length, afterCommand);
    });

    testWidgets('is capped by the device pixel ratio', (
      WidgetTester tester,
    ) async {
      await mount(tester, dpr: 3);
      shot.value = const CameraShot(
        shot: Shot.closeUp,
        move: CameraMove.cut,
        serial: 1,
      );
      await tester.pump();
      expect(scales.last, 1);
    });

    testWidgets('returns to 1 on wide', (WidgetTester tester) async {
      await mount(tester, dpr: 1);
      shot.value = const CameraShot(
        shot: Shot.closeUp,
        move: CameraMove.cut,
        serial: 1,
      );
      await tester.pump();
      expect(scales.last, closeTo(2, 1e-9));
      shot.value = const CameraShot(
        shot: Shot.wide,
        move: CameraMove.ease,
        duration: Duration(milliseconds: 500),
        serial: 2,
      );
      await tester.pump();
      expect(scales.last, 1);
    });
  });
}
