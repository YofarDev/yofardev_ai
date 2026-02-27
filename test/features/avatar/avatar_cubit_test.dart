import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/logic/avatar/avatar_cubit.dart';
import 'package:yofardev_ai/logic/avatar/avatar_state.dart';
import 'package:yofardev_ai/models/avatar.dart';

void main() {
  group('AvatarCubit', () {
    late AvatarCubit avatarCubit;

    setUp(() {
      avatarCubit = AvatarCubit();
    });

    tearDown(() {
      avatarCubit.close();
    });

    test('initial state should have default values', () {
      expect(avatarCubit.state.status, AvatarStatus.initial);
      expect(avatarCubit.state.scaleFactor, 1);
      expect(avatarCubit.state.avatar, const Avatar());
    });

    group('setValuesBasedOnScreenWidth', () {
      test('should calculate correct scale factor based on screen width', () {
        const double screenWidth = 400.0;
        const double avatarWidth = 1024.0; // AppConstants.avatarWidth

        avatarCubit.setValuesBasedOnScreenWidth(screenWidth: screenWidth);

        expect(avatarCubit.state.status, AvatarStatus.ready);
        expect(avatarCubit.state.baseOriginalWidth, avatarWidth);
        expect(avatarCubit.state.baseOriginalHeight, 1280.0); // AppConstants.avatarHeight
        expect(avatarCubit.state.scaleFactor, screenWidth / avatarWidth);
      });
    });

    group('onScreenSizeChanged', () {
      test('should update scale factor when screen size changes', () {
        avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400.0);
        final double initialScaleFactor = avatarCubit.state.scaleFactor;

        avatarCubit.onScreenSizeChanged(800.0);

        expect(avatarCubit.state.scaleFactor, initialScaleFactor * 2);
      });
    });

    group('onAnimationStatusChanged', () {
      test('should update animation status to leaving when leaving is true', () {
        avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400.0);

        avatarCubit.onAnimationStatusChanged(true);

        expect(
          avatarCubit.state.statusAnimation,
          AvatarStatusAnimation.leaving,
        );
        expect(
          avatarCubit.state.avatar.specials,
          AvatarSpecials.outOfScreen,
        );
      });

      test('should update animation status to coming when leaving is false', () {
        avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400.0);

        avatarCubit.onAnimationStatusChanged(false);

        expect(
          avatarCubit.state.statusAnimation,
          AvatarStatusAnimation.coming,
        );
        expect(
          avatarCubit.state.avatar.specials,
          AvatarSpecials.onScreen,
        );
      });
    });

    group('toggleGlasses', () {
      test('should toggle between glasses and sunglasses', () {
        avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400.0);

        final AvatarGlasses initialGlasses = avatarCubit.state.avatar.glasses;
        avatarCubit.toggleGlasses();

        expect(
          avatarCubit.state.avatar.glasses != initialGlasses,
          isTrue,
        );

        avatarCubit.toggleGlasses();

        expect(
          avatarCubit.state.avatar.glasses,
          initialGlasses,
        );
      });
    });

    group('AvatarState', () {
      test('should copy with new values correctly', () {
        const AvatarState state = AvatarState();
        final AvatarState newState = state.copyWith(
          status: AvatarStatus.ready,
          scaleFactor: 2.0,
        );

        expect(newState.status, AvatarStatus.ready);
        expect(newState.scaleFactor, 2.0);
        expect(newState.baseOriginalWidth, state.baseOriginalWidth);
        expect(newState.avatar, state.avatar);
      });

      test('props should include all fields', () {
        const AvatarState state = AvatarState();

        expect(
          state.props.length,
          8, // status, statusAnimation, baseOriginalWidth, baseOriginalHeight, scaleFactor, avatar, avatarConfig, previousSpecialsState
        );
      });
    });

    group('Avatar model', () {
      test('should create default avatar', () {
        const Avatar avatar = Avatar();

        expect(avatar.background, AvatarBackgrounds.lake);
        expect(avatar.hat, AvatarHat.noHat);
        expect(avatar.top, AvatarTop.pinkHoodie);
        expect(avatar.glasses, AvatarGlasses.glasses);
        expect(avatar.specials, AvatarSpecials.onScreen);
        expect(avatar.costume, AvatarCostume.none);
      });

      test('should copy with new values', () {
        const Avatar avatar = Avatar();
        final Avatar newAvatar = avatar.copyWith(
          background: AvatarBackgrounds.beach,
          glasses: AvatarGlasses.sunglasses,
        );

        expect(newAvatar.background, AvatarBackgrounds.beach);
        expect(newAvatar.glasses, AvatarGlasses.sunglasses);
        expect(newAvatar.hat, avatar.hat); // unchanged
      });

      test('should serialize and deserialize correctly', () {
        const Avatar avatar = Avatar(
          background: AvatarBackgrounds.forest,
          hat: AvatarHat.frenchBeret,
          top: AvatarTop.longCoat,
          glasses: AvatarGlasses.sunglasses,
          specials: AvatarSpecials.onScreen,
          costume: AvatarCostume.batman,
        );

        final Map<String, dynamic> map = avatar.toMap();
        final Avatar deserialized = Avatar.fromMap(map);

        expect(deserialized.background, avatar.background);
        expect(deserialized.hat, avatar.hat);
        expect(deserialized.top, avatar.top);
        expect(deserialized.glasses, avatar.glasses);
        expect(deserialized.specials, avatar.specials);
        expect(deserialized.costume, avatar.costume);
      });

      test('props should include all fields', () {
        const Avatar avatar = Avatar();

        expect(
          avatar.props.length,
          6, // background, hat, top, glasses, specials, costume
        );
      });

      test('should correctly determine costume visibility', () {
        const Avatar normalAvatar = Avatar();
        const Avatar singularityAvatar = Avatar(
          costume: AvatarCostume.singularity,
        );

        expect(normalAvatar.hideBlinkingEyes, isFalse);
        expect(normalAvatar.hideBaseAvatar, isFalse);
        expect(normalAvatar.hideTalkingMouth, isFalse);

        expect(singularityAvatar.hideBlinkingEyes, isTrue);
        expect(singularityAvatar.hideBaseAvatar, isTrue);
        expect(singularityAvatar.hideTalkingMouth, isTrue);
      });

      test('should correctly determine sunglasses display', () {
        const Avatar withSunglasses = Avatar(
          glasses: AvatarGlasses.sunglasses,
        );
        const Avatar withGlasses = Avatar(
          glasses: AvatarGlasses.glasses,
        );
        const Avatar batmanCostume = Avatar(
          glasses: AvatarGlasses.sunglasses,
          costume: AvatarCostume.batman,
        );

        expect(withSunglasses.displaySunglasses, isTrue);
        expect(withGlasses.displaySunglasses, isFalse);
        expect(batmanCostume.displaySunglasses, isFalse);
      });
    });

    group('AvatarConfig', () {
      test('should create config with optional values', () {
        const AvatarConfig config = AvatarConfig(
          background: AvatarBackgrounds.beach,
          hat: AvatarHat.beanie,
        );

        expect(config.background, AvatarBackgrounds.beach);
        expect(config.hat, AvatarHat.beanie);
        expect(config.top, isNull);
        expect(config.glasses, isNull);
      });

      test('should copy with new values', () {
        const AvatarConfig config = AvatarConfig(
          background: AvatarBackgrounds.beach,
        );
        final AvatarConfig newConfig = config.copyWith(
          glasses: AvatarGlasses.sunglasses,
        );

        expect(newConfig.background, config.background);
        expect(newConfig.glasses, AvatarGlasses.sunglasses);
        expect(newConfig.hat, config.hat);
      });

      test('props should include all fields', () {
        const AvatarConfig config = AvatarConfig();

        expect(
          config.props.length,
          7, // background, hat, top, glasses, specials, costume, soundEffect
        );
      });
    });
  });
}
