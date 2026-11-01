import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/scene_front_follower.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/rive_scene_view.dart';

import '../../../../helpers/rive_test_assets.dart';

void main() {
  group('tier gates (M11 ruling 13)', () {
    test('low never creates the front; high and ultra do while it rains', () {
      for (final QualityTier tier in QualityTier.values) {
        expect(
          SceneFrontFollower.shouldShow(hasFront: true, rain: 1, tier: tier),
          tier != QualityTier.low,
          reason: tier.name,
        );
        expect(
          SceneFrontFollower.shouldShow(hasFront: true, rain: 0, tier: tier),
          isFalse,
        );
      }
    });

    test('low stops the parallax sensors and writes none', () {
      const Offset live = Offset(0.4, -0.2);
      const Offset lab = Offset(-1, 1);
      for (final QualityTier tier in QualityTier.values) {
        final bool rich = tier != QualityTier.low;
        expect(
          RiveSceneView.sensorsActive(
            resumed: true,
            loaded: AvatarScene.campfire,
            tier: tier,
          ),
          rich,
        );
        expect(
          RiveSceneView.shownParallax(live: live, tier: tier),
          rich ? live : Offset.zero,
        );
        expect(
          RiveSceneView.shownParallax(live: live, override: lab, tier: tier),
          rich ? lab : Offset.zero,
        );
      }
      expect(
        RiveSceneView.sensorsActive(
          resumed: false,
          loaded: AvatarScene.campfire,
          tier: QualityTier.ultra,
        ),
        isFalse,
      );
      expect(
        RiveSceneView.sensorsActive(
          resumed: true,
          loaded: null,
          tier: QualityTier.ultra,
        ),
        isFalse,
      );
    });
  });

  setUp(serveFakeRiveAssets);

  testWidgets('the view follows a tier source and lets it go', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<QualityTier> tier = ValueNotifier<QualityTier>(
      QualityTier.ultra,
    );
    addTearDown(tier.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RiveSceneView(
          scene: AvatarScene.campfire,
          sceneEvent: (sceneEvent: SceneEvent.flare, seq: 0),
          tier: tier,
        ),
      ),
    );
    tier.value = QualityTier.low;
    await tester.pump();
    tier.value = QualityTier.high;
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    expect(tier.hasListeners, isFalse);
  });
}
