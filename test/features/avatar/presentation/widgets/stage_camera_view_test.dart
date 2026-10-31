import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/shot.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/stage_framing.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/stage_camera.dart';

const Size _stage = Size(390, 560);

void main() {
  late ValueNotifier<CameraShot> shot;
  late StageCameraView view;
  late int heard;

  setUp(() {
    shot = ValueNotifier<CameraShot>(CameraShot.initial);
    view = StageCameraView();
    heard = 0;
    view.addListener(() => heard++);
    addTearDown(shot.dispose);
    addTearDown(view.dispose);
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: _stage),
          child: Center(
            child: SizedBox.fromSize(
              size: _stage,
              child: StageCamera(
                shot: shot,
                view: view,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  test('without a camera: identity, no stage, wide', () {
    expect(view.frame, StageFraming.identity);
    expect(view.size, isNull);
    expect(view.shot, Shot.wide);
  });

  testWidgets('knows the stage once laid out, and tells', (
    WidgetTester tester,
  ) async {
    await mount(tester);
    expect(view.size, _stage);
    expect(view.frame, StageFraming.identity);
    expect(heard, greaterThan(0));
  });

  testWidgets('a cut is the shot framing at once', (WidgetTester tester) async {
    await mount(tester);
    final int before = heard;
    shot.value = const CameraShot(
      shot: Shot.closeUp,
      move: CameraMove.cut,
      serial: 1,
    );
    await tester.pump();
    expect(heard, greaterThan(before));
    expect(view.shot, Shot.closeUp);
    expect(view.frame, StageFraming.of(Shot.closeUp, _stage));
  });

  testWidgets('an ease notifies every frame and ends on the framing', (
    WidgetTester tester,
  ) async {
    await mount(tester);
    shot.value = const CameraShot(
      shot: Shot.medium,
      move: CameraMove.ease,
      duration: Duration(milliseconds: 600),
      serial: 1,
    );
    await tester.pump();
    final int start = heard;
    await tester.pump(const Duration(milliseconds: 300));
    expect(heard, greaterThan(start));
    final double midZoom = view.frame.zoom;
    expect(midZoom, greaterThan(1));
    expect(midZoom, lessThan(StageFraming.of(Shot.medium, _stage).zoom));
    await tester.pumpAndSettle();
    expect(view.frame, StageFraming.of(Shot.medium, _stage));
  });

  testWidgets('a removed camera leaves the identity', (
    WidgetTester tester,
  ) async {
    await mount(tester);
    shot.value = const CameraShot(
      shot: Shot.closeUp,
      move: CameraMove.cut,
      serial: 1,
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(view.frame, StageFraming.identity);
    expect(view.size, isNull);
  });
}
