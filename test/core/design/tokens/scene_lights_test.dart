import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/tokens/scene_lights.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/performance/light_rig.dart';

void main() {
  group('SceneLights', () {
    test('defines a rig for every scene', () {
      for (final AvatarScene scene in AvatarScene.values) {
        final LightRig rig = SceneLights.of(scene);
        expect(rig, isNot(LightRig.neutral), reason: scene.name);
        expect(rig.keyIntensity, inInclusiveRange(0.0, 1.0));
        expect(rig.keyX * rig.keyX + rig.keyY * rig.keyY, closeTo(1, 0.01));
      }
    });

    test('campfire light comes from cos/sin of the art bible angle 4.2', () {
      final LightRig rig = SceneLights.of(AvatarScene.campfire);
      expect(rig.keyX, closeTo(math.cos(4.2), 0.001));
      expect(rig.keyX, closeTo(-0.490, 0.001));
      expect(rig.keyY, closeTo(-0.872, 0.001));
      expect(rig.keyColor, 0xFFFF9A4D);
      expect(rig.keyIntensity, 1.0);
      expect(rig.rimColor, 0xFF6F8FD8);
      expect(rig.ambientColor, 0xFF141C2C);
      expect(rig.fogColor, 0x3320304A);
      expect(rig.flicker, 1.0);
    });

    test('rim intensity and ambient amount are shared by every scene', () {
      for (final AvatarScene scene in AvatarScene.values) {
        expect(SceneLights.of(scene).rimIntensity, 0.35, reason: scene.name);
        expect(SceneLights.of(scene).ambientAmount, 0.35, reason: scene.name);
      }
    });

    test('flicker: campfire full, living room lamp, others steady', () {
      expect(SceneLights.of(AvatarScene.campfire).flicker, 1.0);
      expect(SceneLights.of(AvatarScene.livingRoom).flicker, 0.15);
      expect(SceneLights.of(AvatarScene.beach).flicker, 0.0);
      expect(SceneLights.of(AvatarScene.deepSpace).flicker, 0.0);
    });

    test('the other scenes keep their art bible direction and colours', () {
      final LightRig living = SceneLights.of(AvatarScene.livingRoom);
      expect(living.keyX, closeTo(math.cos(2.4), 0.001));
      expect(living.keyY, closeTo(math.sin(2.4), 0.001));
      expect(living.keyColor, 0xFFFFD49A);
      expect(living.keyIntensity, 0.85);
      final LightRig beach = SceneLights.of(AvatarScene.beach);
      expect(beach.keyX, closeTo(math.cos(0.35), 0.001));
      expect(beach.keyY, closeTo(math.sin(0.35), 0.001));
      expect(beach.fogColor, 0x22FFD9C0);
      final LightRig space = SceneLights.of(AvatarScene.deepSpace);
      expect(space.keyX, closeTo(math.cos(0.9), 0.001));
      expect(space.keyY, closeTo(math.sin(0.9), 0.001));
      expect(space.keyIntensity, 0.7);
      expect(space.rimColor, 0xFF7FE0FF);
    });
  });
}
