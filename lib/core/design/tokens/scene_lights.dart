import '../../models/avatar_scene.dart';
import '../../models/performance/light_rig.dart';
import 'app_palette.dart';

/// The light rig of each scene: the single Dart mirror of
/// `rive/tools/art_bible.py` `SCENES` (a Python test keeps `AppPalette` equal
/// to it). The key direction is a viewer-space vector, `cos`/`sin` of the art
/// bible's angle rounded to 3 digits. The UI reads this static rig, never the
/// flicker (`ScenePalette.glassTint` / `captionInk`).
abstract final class SceneLights {
  static const double _rimIntensity = 0.35;
  static const double _ambientAmount = 0.35;

  static LightRig of(AvatarScene scene) {
    return switch (scene) {
      AvatarScene.livingRoom => LightRig(
        keyColor: AppPalette.livingRoomKey.toARGB32(),
        keyIntensity: 0.85,
        keyX: -0.737,
        keyY: 0.675,
        rimColor: AppPalette.livingRoomRim.toARGB32(),
        rimIntensity: _rimIntensity,
        ambientColor: AppPalette.livingRoomAmbient.toARGB32(),
        ambientAmount: _ambientAmount,
        fogColor: AppPalette.livingRoomFog.toARGB32(),
        flicker: 0.15,
      ),
      AvatarScene.campfire => LightRig(
        keyColor: AppPalette.campfireKey.toARGB32(),
        keyIntensity: 1.0,
        keyX: -0.49,
        keyY: -0.872,
        rimColor: AppPalette.campfireRim.toARGB32(),
        rimIntensity: _rimIntensity,
        ambientColor: AppPalette.campfireAmbient.toARGB32(),
        ambientAmount: _ambientAmount,
        fogColor: AppPalette.campfireFog.toARGB32(),
        flicker: 1.0,
      ),
      AvatarScene.beach => LightRig(
        keyColor: AppPalette.beachKey.toARGB32(),
        keyIntensity: 0.9,
        keyX: 0.939,
        keyY: 0.343,
        rimColor: AppPalette.beachRim.toARGB32(),
        rimIntensity: _rimIntensity,
        ambientColor: AppPalette.beachAmbient.toARGB32(),
        ambientAmount: _ambientAmount,
        fogColor: AppPalette.beachFog.toARGB32(),
        flicker: 0.0,
      ),
      AvatarScene.deepSpace => LightRig(
        keyColor: AppPalette.deepSpaceKey.toARGB32(),
        keyIntensity: 0.7,
        keyX: 0.622,
        keyY: 0.783,
        rimColor: AppPalette.deepSpaceRim.toARGB32(),
        rimIntensity: _rimIntensity,
        ambientColor: AppPalette.deepSpaceAmbient.toARGB32(),
        ambientAmount: _ambientAmount,
        fogColor: AppPalette.deepSpaceFog.toARGB32(),
        flicker: 0.0,
      ),
    };
  }
}
