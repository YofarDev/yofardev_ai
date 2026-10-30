import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit_file.dart';
import 'package:yofardev_ai/core/models/performance/shot.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/home/widgets/home_content_stack.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_composer.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

import '../../helpers/rive_test_assets.dart';
import 'stage_harness.dart';

void main() {
  late StageHarness h;
  late CameraDirector camera;

  setUp(() {
    serveFakeRiveAssets();
    UiKitFile.resetForTest();
    h = StageHarness();
    camera = CameraDirector(now: DateTime.now);
  });

  tearDown(() => camera.dispose());

  Future<void> pumpStack(
    WidgetTester tester, {
    CameraDirector? director,
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      h.app(
        Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: HomeContentStack(
                speech: h.speech,
                camera: director,
                onStartDemo: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the camera frames the Rive stage, not the chrome', (
    WidgetTester tester,
  ) async {
    await pumpStack(tester, director: camera);
    expect(find.byType(StageCamera), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(StageCamera),
        matching: find.byType(RiveSceneView),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(StageCamera),
        matching: find.byType(StageComposer),
      ),
      findsNothing,
    );
    expect(find.byType(StageComposer), findsOneWidget);
  });

  testWidgets('without a camera there is no StageCamera', (
    WidgetTester tester,
  ) async {
    await pumpStack(tester);
    expect(find.byType(StageCamera), findsNothing);
    expect(find.byType(RiveSceneView), findsOneWidget);
  });

  testWidgets('the talking phase reaches the director', (
    WidgetTester tester,
  ) async {
    await pumpStack(tester, director: camera);
    expect(camera.shot.value.shot, Shot.wide);
    h.talking.emit(const TalkingState.generating());
    await tester.pump();
    expect(camera.shot.value.shot, Shot.medium);
    expect(camera.shot.value.move, CameraMove.ease);
  });

  testWidgets('reduce motion locks the camera on medium, as a cut', (
    WidgetTester tester,
  ) async {
    await pumpStack(tester, director: camera, disableAnimations: true);
    expect(camera.shot.value.shot, Shot.medium);
    expect(camera.shot.value.move, CameraMove.cut);
    // no phase moves it
    h.talking.emit(const TalkingState.idle());
    await tester.pump();
    expect(camera.shot.value.shot, Shot.medium);
  });
}
