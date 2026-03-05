import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/features/avatar/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/features/avatar/bloc/avatar_state.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/features/avatar/domain/repositories/avatar_repository.dart';

class MockAvatarRepository extends Mock implements AvatarRepository {}

void main() {
  group('AvatarCubit', () {
    late AvatarCubit avatarCubit;
    late MockAvatarRepository mockAvatarRepository;

    setUp(() {
      mockAvatarRepository = MockAvatarRepository();
      avatarCubit = AvatarCubit(mockAvatarRepository);
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
        expect(
          avatarCubit.state.baseOriginalHeight,
          1280.0,
        ); // AppConstants.avatarHeight
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
      test(
        'should update animation status to leaving when leaving is true',
        () {
          avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400.0);

          avatarCubit.onAnimationStatusChanged(true);

          expect(
            avatarCubit.state.statusAnimation,
            AvatarStatusAnimation.leaving,
          );
          expect(avatarCubit.state.avatar.specials, AvatarSpecials.outOfScreen);
        },
      );

      test(
        'should update animation status to coming when leaving is false',
        () {
          avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400.0);

          avatarCubit.onAnimationStatusChanged(false);

          expect(
            avatarCubit.state.statusAnimation,
            AvatarStatusAnimation.coming,
          );
          expect(avatarCubit.state.avatar.specials, AvatarSpecials.onScreen);
        },
      );
    });

    group('toggleGlasses', () {
      test('should toggle between glasses and sunglasses', () {
        avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400.0);

        final AvatarGlasses initialGlasses = avatarCubit.state.avatar.glasses;
        avatarCubit.toggleGlasses();

        expect(avatarCubit.state.avatar.glasses != initialGlasses, isTrue);

        avatarCubit.toggleGlasses();

        expect(avatarCubit.state.avatar.glasses, initialGlasses);
      });
    });

    group('AvatarState', () {
      test('should copy with new values correctly', () {
        const AvatarState state = AvatarState(
          avatar: Avatar(),
          avatarConfig: AvatarConfig(),
        );
        final AvatarState newState = state.copyWith(
          status: AvatarStatus.ready,
          scaleFactor: 2.0,
        );

        expect(newState.status, AvatarStatus.ready);
        expect(newState.scaleFactor, 2.0);
        expect(newState.baseOriginalWidth, state.baseOriginalWidth);
        expect(newState.avatar, state.avatar);
      });

      test('should support value equality', () {
        const AvatarState state1 = AvatarState(
          avatar: Avatar(),
          avatarConfig: AvatarConfig(),
        );
        const AvatarState state2 = AvatarState(
          avatar: Avatar(),
          avatarConfig: AvatarConfig(),
        );
        const AvatarState state3 = AvatarState(
          avatar: Avatar(),
          avatarConfig: AvatarConfig(),
          status: AvatarStatus.ready,
        );

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
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

      test('should support value equality', () {
        const Avatar avatar1 = Avatar();
        const Avatar avatar2 = Avatar();
        const Avatar avatar3 = Avatar(background: AvatarBackgrounds.beach);

        expect(avatar1, equals(avatar2));
        expect(avatar1, isNot(equals(avatar3)));
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
        const Avatar withSunglasses = Avatar(glasses: AvatarGlasses.sunglasses);
        const Avatar withGlasses = Avatar();
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

      test('should support value equality', () {
        const AvatarConfig config1 = AvatarConfig();
        const AvatarConfig config2 = AvatarConfig();
        const AvatarConfig config3 = AvatarConfig(
          background: AvatarBackgrounds.beach,
        );

        expect(config1, equals(config2));
        expect(config1, isNot(equals(config3)));
      });
    });
  });
}
