import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/sound_effects.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';

void main() {
  group('Avatar (Freezed)', () {
    test('should create instance with default values', () {
      const Avatar avatar = Avatar();
      expect(avatar.background, AvatarBackgrounds.lake);
      expect(avatar.hat, AvatarHat.noHat);
      expect(avatar.top, AvatarTop.pinkHoodie);
      expect(avatar.glasses, AvatarGlasses.glasses);
      expect(avatar.specials, AvatarSpecials.onScreen);
      expect(avatar.costume, AvatarCostume.none);
    });

    test('should create instance with provided values', () {
      const Avatar avatar = Avatar(
        background: AvatarBackgrounds.beach,
        hat: AvatarHat.beanie,
        top: AvatarTop.longCoat,
        glasses: AvatarGlasses.sunglasses,
        specials: AvatarSpecials.outOfScreen,
        costume: AvatarCostume.batman,
      );
      expect(avatar.background, AvatarBackgrounds.beach);
      expect(avatar.hat, AvatarHat.beanie);
      expect(avatar.top, AvatarTop.longCoat);
      expect(avatar.glasses, AvatarGlasses.sunglasses);
      expect(avatar.specials, AvatarSpecials.outOfScreen);
      expect(avatar.costume, AvatarCostume.batman);
    });

    test('should support equality', () {
      const Avatar avatar1 = Avatar(background: AvatarBackgrounds.beach);
      const Avatar avatar2 = Avatar(background: AvatarBackgrounds.beach);
      const Avatar avatar3 = Avatar(background: AvatarBackgrounds.forest);

      expect(avatar1, equals(avatar2));
      expect(avatar1, isNot(equals(avatar3)));
    });

    test('should copy with new values', () {
      const Avatar original = Avatar(
        background: AvatarBackgrounds.lake,
        hat: AvatarHat.noHat,
      );

      final Avatar copied = original.copyWith(
        background: AvatarBackgrounds.beach,
        hat: AvatarHat.beanie,
      );

      expect(copied.background, AvatarBackgrounds.beach);
      expect(copied.hat, AvatarHat.beanie);
      expect(copied.top, original.top);
      expect(copied.glasses, original.glasses);
    });

    test('should copy with partial values', () {
      const Avatar original = Avatar(
        background: AvatarBackgrounds.lake,
        hat: AvatarHat.noHat,
      );

      final Avatar copied = original.copyWith(
        background: AvatarBackgrounds.beach,
      );

      expect(copied.background, AvatarBackgrounds.beach);
      expect(copied.hat, original.hat);
      expect(copied.top, original.top);
    });

    test('hideBlinkingEyes should be true for singularity costume', () {
      const Avatar normal = Avatar(costume: AvatarCostume.none);
      const Avatar singularity = Avatar(costume: AvatarCostume.singularity);

      expect(normal.hideBlinkingEyes, false);
      expect(singularity.hideBlinkingEyes, true);
    });

    test('hideBaseAvatar should be true for singularity costume', () {
      const Avatar normal = Avatar(costume: AvatarCostume.none);
      const Avatar singularity = Avatar(costume: AvatarCostume.singularity);

      expect(normal.hideBaseAvatar, false);
      expect(singularity.hideBaseAvatar, true);
    });

    test('hideTalkingMouth should be true for singularity costume', () {
      const Avatar normal = Avatar(costume: AvatarCostume.none);
      const Avatar singularity = Avatar(costume: AvatarCostume.singularity);

      expect(normal.hideTalkingMouth, false);
      expect(singularity.hideTalkingMouth, true);
    });

    test(
      'displaySunglasses should be true only with sunglasses and no costume',
      () {
        const Avatar withSunglasses = Avatar(
          glasses: AvatarGlasses.sunglasses,
          costume: AvatarCostume.none,
        );
        const Avatar withSunglassesAndCostume = Avatar(
          glasses: AvatarGlasses.sunglasses,
          costume: AvatarCostume.batman,
        );
        const Avatar withoutSunglasses = Avatar(
          glasses: AvatarGlasses.glasses,
          costume: AvatarCostume.none,
        );

        expect(withSunglasses.displaySunglasses, true);
        expect(withSunglassesAndCostume.displaySunglasses, false);
        expect(withoutSunglasses.displaySunglasses, false);
      },
    );
  });

  group('AvatarConfig (Freezed)', () {
    test('should create instance with all null values', () {
      const AvatarConfig config = AvatarConfig();
      expect(config.background, null);
      expect(config.hat, null);
      expect(config.top, null);
      expect(config.glasses, null);
      expect(config.specials, null);
      expect(config.costume, null);
      expect(config.soundEffect, null);
    });

    test('should create instance with provided values', () {
      const AvatarConfig config = AvatarConfig(
        background: AvatarBackgrounds.beach,
        hat: AvatarHat.beanie,
        top: AvatarTop.longCoat,
        glasses: AvatarGlasses.sunglasses,
        specials: AvatarSpecials.outOfScreen,
        costume: AvatarCostume.batman,
        soundEffect: SoundEffects.spookyTheme,
      );
      expect(config.background, AvatarBackgrounds.beach);
      expect(config.hat, AvatarHat.beanie);
      expect(config.top, AvatarTop.longCoat);
      expect(config.glasses, AvatarGlasses.sunglasses);
      expect(config.specials, AvatarSpecials.outOfScreen);
      expect(config.costume, AvatarCostume.batman);
      expect(config.soundEffect, SoundEffects.spookyTheme);
    });

    test('should support equality', () {
      const AvatarConfig config1 = AvatarConfig(
        background: AvatarBackgrounds.beach,
      );
      const AvatarConfig config2 = AvatarConfig(
        background: AvatarBackgrounds.beach,
      );
      const AvatarConfig config3 = AvatarConfig(
        background: AvatarBackgrounds.forest,
      );

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
    });

    test('should copy with new values', () {
      const AvatarConfig original = AvatarConfig(
        background: AvatarBackgrounds.beach,
      );

      final AvatarConfig copied = original.copyWith(
        background: AvatarBackgrounds.forest,
        hat: AvatarHat.beanie,
      );

      expect(copied.background, AvatarBackgrounds.forest);
      expect(copied.hat, AvatarHat.beanie);
      expect(copied.top, original.top);
    });
  });

  group('Avatar Backward Compatibility', () {
    test('toMap should maintain weird field mappings for compatibility', () {
      const Avatar avatar = Avatar(
        background: AvatarBackgrounds.beach,
        hat: AvatarHat.beanie,
        top: AvatarTop.longCoat,
        glasses: AvatarGlasses.sunglasses,
        specials: AvatarSpecials.outOfScreen,
        costume: AvatarCostume.batman,
      );

      final Map<String, dynamic> map = avatar.toMap();

      // Weird mappings: hat -> 'top', top -> 'bottom'
      expect(map['background'], 'beach');
      expect(map['top'], 'beanie'); // hat maps to 'top'
      expect(map['bottom'], 'longCoat'); // top maps to 'bottom'
      expect(map['glasses'], 'sunglasses');
      expect(map['specials'], 'outOfScreen');
      expect(map['costume'], 'batman');
    });

    test('fromMap should handle weird field mappings', () {
      final Map<String, dynamic> map = <String, dynamic>{
        'background': 'beach',
        'top': 'beanie', // this maps to hat
        'bottom': 'longCoat', // this maps to top
        'glasses': 'sunglasses',
        'specials': 'outOfScreen',
        'costume': 'batman',
      };

      final Avatar avatar = Avatar.fromMap(map);

      expect(avatar.background, AvatarBackgrounds.beach);
      expect(avatar.hat, AvatarHat.beanie);
      expect(avatar.top, AvatarTop.longCoat);
      expect(avatar.glasses, AvatarGlasses.sunglasses);
      expect(avatar.specials, AvatarSpecials.outOfScreen);
      expect(avatar.costume, AvatarCostume.batman);
    });

    test('toMap/fromMap should be symmetric', () {
      const Avatar original = Avatar(
        background: AvatarBackgrounds.beach,
        hat: AvatarHat.beanie,
        top: AvatarTop.longCoat,
      );

      final Map<String, dynamic> map = original.toMap();
      final Avatar restored = Avatar.fromMap(map);

      expect(restored.background, original.background);
      expect(restored.hat, original.hat);
      expect(restored.top, original.top);
      expect(restored.glasses, original.glasses);
      expect(restored.specials, original.specials);
      expect(restored.costume, original.costume);
    });
  });
}
