import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';

void main() {
  group('AvatarConfig.applyTo', () {
    test('a null config field keeps the base value', () {
      const AvatarConfig config = AvatarConfig(hat: AvatarHat.beanie);
      const Avatar base = Avatar(
        hat: AvatarHat.frenchBeret,
        top: AvatarTop.longCoat,
        background: AvatarScene.beach,
      );
      final Avatar merged = config.applyTo(base);
      expect(merged.hat, AvatarHat.beanie); // the only set field overrides
      expect(merged.top, AvatarTop.longCoat);
      expect(merged.background, AvatarScene.beach);
    });

    test('a non-null config field overrides the base value', () {
      const AvatarConfig config = AvatarConfig(
        hat: AvatarHat.santaHat,
        top: AvatarTop.blackSuitAndTie,
        background: AvatarScene.deepSpace,
        glasses: AvatarGlasses.sunglasses,
        costume: AvatarCostume.batman,
        topTint: AvatarTint.red,
        hatTint: AvatarTint.blue,
        specials: AvatarSpecials.outOfScreen,
      );
      final Avatar merged = config.applyTo(const Avatar());
      expect(merged.hat, AvatarHat.santaHat);
      expect(merged.top, AvatarTop.blackSuitAndTie);
      expect(merged.background, AvatarScene.deepSpace);
      expect(merged.glasses, AvatarGlasses.sunglasses);
      expect(merged.costume, AvatarCostume.batman);
      expect(merged.topTint, AvatarTint.red);
      expect(merged.hatTint, AvatarTint.blue);
      expect(merged.specials, AvatarSpecials.outOfScreen);
    });

    test('every Avatar field is covered by the merge rule', () {
      // A config with every field set, applied to a base with a distinct
      // sentinel value per field: the result must equal the config's values
      // field by field.
      const AvatarConfig config = AvatarConfig(
        background: AvatarScene.beach,
        hat: AvatarHat.santaHat,
        top: AvatarTop.christmasSweater,
        glasses: AvatarGlasses.sunglasses,
        specials: AvatarSpecials.leaveAndComeBack,
        costume: AvatarCostume.robocop,
        topTint: AvatarTint.teal,
        hatTint: AvatarTint.purple,
      );
      const Avatar base = Avatar(
        background: AvatarScene.livingRoom,
        hat: AvatarHat.noHat,
        top: AvatarTop.pinkHoodie,
        glasses: AvatarGlasses.glasses,
        specials: AvatarSpecials.onScreen,
        costume: AvatarCostume.none,
        topTint: AvatarTint.none,
        hatTint: AvatarTint.none,
      );
      final Avatar merged = config.applyTo(base);
      expect(merged.background, AvatarScene.beach);
      expect(merged.hat, AvatarHat.santaHat);
      expect(merged.top, AvatarTop.christmasSweater);
      expect(merged.glasses, AvatarGlasses.sunglasses);
      expect(merged.specials, AvatarSpecials.leaveAndComeBack);
      expect(merged.costume, AvatarCostume.robocop);
      expect(merged.topTint, AvatarTint.teal);
      expect(merged.hatTint, AvatarTint.purple);
      // The sentinels were all distinct from the config's values: any field
      // the rule forgot would still carry its base sentinel above.
      expect(merged, isNot(equals(base)));
    });

    test('an empty config leaves the base avatar untouched', () {
      const AvatarConfig config = AvatarConfig();
      const Avatar base = Avatar(
        background: AvatarScene.mountainHut,
        hat: AvatarHat.backwardsCap,
        top: AvatarTop.swimsuit,
        glasses: AvatarGlasses.sunglasses,
        specials: AvatarSpecials.onScreen,
        costume: AvatarCostume.soubrette,
        topTint: AvatarTint.green,
        hatTint: AvatarTint.yellow,
      );
      expect(config.applyTo(base), equals(base));
    });
  });
}
