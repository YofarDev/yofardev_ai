import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:yofardev_ai/core/design/rive/ui_kit_file.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/chat/chat.dart';
import 'package:yofardev_ai/features/home/screens/home_screen.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

import '../../helpers/golden_test_helper.dart';
import '../../helpers/rive_test_assets.dart';
import 'stage_harness.dart';

/// The whole Home Stage on a 390×844 phone (notch and home indicator
/// insets), with the Rive scene, avatar and kit in their Flutter fallbacks.
void main() {
  late StageHarness h;

  setUpAll(() async {
    await GoldenTestHelper.init();
  });

  setUp(() {
    serveFakeRiveAssets();
    UiKitFile.resetForTest();
    h = StageHarness();
  });

  Future<void> pumpStage(
    WidgetTester tester, {
    required AvatarScene scene,
    double keyboard = 0,
  }) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(top: 47, bottom: 34)
      ..viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    h.avatar.state = h.avatar.state.copyWith(scene: scene);
    await tester.pumpWidget(h.app(HomeScreen(speech: h.speech), scene: scene));
    await tester.pump();
  }

  Future<void> shoot(WidgetTester tester, String name) =>
      GoldenTestHelper.matchGolden(
        tester,
        name,
        customPump: (WidgetTester tester) =>
            tester.pump(const Duration(milliseconds: 500)),
      );

  testGoldens('living room: idle with a caption', (WidgetTester tester) async {
    h.caption.state = const CaptionState(
      text: 'The cat thinks the lamp is a second moon.',
      seq: 1,
    );
    await pumpStage(tester, scene: AvatarScene.livingRoom);
    await tester.pumpAndSettle();
    await shoot(tester, 'stage_living_room');
  });

  testGoldens('deep space: thinking with a running tool', (
    WidgetTester tester,
  ) async {
    h.chat.state = h.chat.state.copyWith(
      status: ChatStatus.streaming,
      activeTool: 'getCurrentWeather',
    );
    h.talking.state = const TalkingState.generating();
    h.caption.state = const CaptionState(text: 'Hidden while thinking.');
    await pumpStage(tester, scene: AvatarScene.deepSpace);
    await tester.pumpAndSettle();
    expect(find.text('Hidden while thinking.'), findsNothing);
    await shoot(tester, 'stage_deep_space_tool');
  });

  testGoldens('keyboard open: the composer and caption sit above it', (
    WidgetTester tester,
  ) async {
    h.caption.state = const CaptionState(
      text: 'The cat thinks the lamp is a second moon.',
      seq: 1,
    );
    await pumpStage(tester, scene: AvatarScene.livingRoom, keyboard: 300);
    await tester.pumpAndSettle();
    await shoot(tester, 'stage_keyboard');
  });
}
