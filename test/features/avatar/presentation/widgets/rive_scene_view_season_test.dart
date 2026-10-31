// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/rive_scene_view.dart';

import '../../../../helpers/rive_test_assets.dart';

void main() {
  setUp(serveFakeRiveAssets);

  testWidgets('the view follows the season sources, swaps and lets them go', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<double> spring = ValueNotifier<double>(0);
    final ValueNotifier<double> autumn = ValueNotifier<double>(1);
    final ValueNotifier<double> spring2 = ValueNotifier<double>(0.5);
    addTearDown(spring.dispose);
    addTearDown(autumn.dispose);
    addTearDown(spring2.dispose);

    Widget view(ValueNotifier<double> s) => MaterialApp(
      home: RiveSceneView(
        scene: AvatarScene.forestCabin,
        sceneEvent: (sceneEvent: SceneEvent.gust, seq: 0),
        spring: s,
        autumn: autumn,
      ),
    );

    await tester.pumpWidget(view(spring));
    expect(spring.hasListeners, isTrue);
    expect(autumn.hasListeners, isTrue);
    spring.value = 1 / 7;
    await tester.pump();

    await tester.pumpWidget(view(spring2));
    expect(spring.hasListeners, isFalse, reason: 'swapped out');
    expect(spring2.hasListeners, isTrue);

    await tester.pumpWidget(const SizedBox());
    expect(spring2.hasListeners, isFalse);
    expect(autumn.hasListeners, isFalse);
  });
}
