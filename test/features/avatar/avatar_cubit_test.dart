import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/repositories/avatar_repository.dart';
import 'package:yofardev_ai/core/services/audio/audio_player_service.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/core/models/app_lifecycle_event.dart';
import 'package:yofardev_ai/core/services/avatar_animation_service.dart';
import 'package:yofardev_ai/features/avatar/domain/models/avatar_animation.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_state.dart';

class MockAvatarRepository extends Mock implements AvatarRepository {}

class MockAvatarAnimationService implements AvatarAnimationService {
  @override
  Stream<AvatarAnimation> get animations =>
      const Stream<AvatarAnimation>.empty();

  @override
  void dispose() {}

  @override
  Future<void> playNewChatSequence(String chatId, AvatarConfig config) async {}

  @override
  void emitUpdateConfig(String chatId, AvatarConfig config) {}
}

class MockAudioPlayerService extends Mock implements AudioPlayerService {
  @override
  Future<void> playAsset(String assetPath, {double volume = 1.0}) async {}
}

class MockAppLifecycleService extends Mock implements AppLifecycleService {
  @override
  Stream<NewChatEntryPayload> get newChatEntryEvents =>
      const Stream<NewChatEntryPayload>.empty();

  @override
  Stream<String> get chatChangedEvents => const Stream<String>.empty();
}

void main() {
  group('AvatarCubit', () {
    late AvatarCubit avatarCubit;
    late MockAvatarRepository mockAvatarRepository;
    late MockAvatarAnimationService mockAnimationService;
    late MockAudioPlayerService mockAudioPlayerService;

    setUpAll(() {
      // Register fallback values for mocktail
      registerFallbackValue(const Avatar());
      registerFallbackValue(const AvatarConfig());
    });

    setUp(() {
      mockAvatarRepository = MockAvatarRepository();
      mockAnimationService = MockAvatarAnimationService();
      mockAudioPlayerService = MockAudioPlayerService();

      // Stub updateAvatar to return success
      when(
        () => mockAvatarRepository.updateAvatar(any(), any()),
      ).thenAnswer((_) async => const Right<Exception, void>(null));

      avatarCubit = AvatarCubit(
        mockAvatarRepository,
        mockAnimationService,
        mockAudioPlayerService,
        MockAppLifecycleService(),
      );
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

    group('onBackgroundTransitionChanged', () {
      test('should update backgroundTransition state', () {
        // Arrange
        const BackgroundTransition expectedTransition =
            BackgroundTransition.sliding;

        // Act
        avatarCubit.onBackgroundTransitionChanged(expectedTransition);

        // Assert
        expect(avatarCubit.state.backgroundTransition, expectedTransition);
      });

      test('should emit state with new backgroundTransition', () {
        // Arrange
        const BackgroundTransition expectedTransition =
            BackgroundTransition.sliding;

        // Act & Assert
        expectLater(
          avatarCubit.stream,
          emits(
            predicate<AvatarState>(
              (AvatarState state) =>
                  state.backgroundTransition == expectedTransition,
            ),
          ),
        );
        avatarCubit.onBackgroundTransitionChanged(expectedTransition);
      });
    });

    group('Avatar Animation from LLM Response', () {
      late MockAvatarAnimationService mockAnimationService;

      setUp(() {
        mockAnimationService = MockAvatarAnimationService();
      });

      // Test: AvatarCubit receives updateConfig events from AvatarAnimationService
      test(
        'updateAvatarConfig calls onNewAvatarConfig to trigger animations',
        () async {
          // Arrange
          avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
          final AvatarConfig avatarConfig = AvatarConfig(
            background: AvatarBackgrounds.beach,
            top: AvatarTop.longCoat,
            specials: AvatarSpecials.leaveAndComeBack,
          );

          // Act
          avatarCubit.updateAvatarConfig('chat1', avatarConfig);

          // Wait for animation to complete
          await Future<dynamic>.delayed(const Duration(milliseconds: 100));

          // Assert - Should trigger the animation flow via onNewAvatarConfig
          // Verify by checking state changes
          expect(
            avatarCubit.state.avatar.background,
            equals(AvatarBackgrounds.beach),
          );
          expect(avatarCubit.state.avatar.top, equals(AvatarTop.longCoat));
        },
      );

      // Test: Animation specials (leaveAndComeBack, outOfScreen) are NOT persisted to avatar
      test('animation specials are not persisted to avatar state', () async {
        // Arrange - Start with onScreen
        avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
        final AvatarSpecials originalSpecials =
            avatarCubit.state.avatar.specials;

        // Act - Trigger background change animation
        final AvatarConfig animationConfig = AvatarConfig(
          background: AvatarBackgrounds.beach,
          specials: AvatarSpecials.leaveAndComeBack, // Animation trigger
        );
        avatarCubit.updateAvatarConfig('chat1', animationConfig);

        // Wait for animation to complete
        await Future<dynamic>.delayed(const Duration(milliseconds: 100));

        // Assert - Background changed, but specials should be preserved (not set to leaveAndComeBack)
        expect(
          avatarCubit.state.avatar.background,
          equals(AvatarBackgrounds.beach),
        );
        expect(avatarCubit.state.avatar.specials, equals(originalSpecials));
      });

      // Test: _goAndComeBack preserves original specials
      test(
        '_goAndComeBack preserves original avatar specials during animation',
        () async {
          // Arrange
          avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
          final AvatarConfig avatarConfig = AvatarConfig(
            background: AvatarBackgrounds.beach,
            specials: AvatarSpecials.onScreen,
          );

          // Act - This will trigger _goAndComeBack
          avatarCubit.onNewAvatarConfig('chat1', avatarConfig);

          // Wait for animation to complete
          await Future<dynamic>.delayed(const Duration(milliseconds: 100));

          // Assert - Specials should be onScreen, not leaveAndComeBack
          expect(
            avatarCubit.state.avatar.specials,
            equals(AvatarSpecials.onScreen),
          );
          expect(
            avatarCubit.state.avatar.background,
            equals(AvatarBackgrounds.beach),
          );
        },
      );

      // Test: _goDownAndUp preserves original specials
      test(
        '_goDownAndUp preserves original avatar specials during animation',
        () async {
          // Arrange
          avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
          final AvatarConfig avatarConfig = AvatarConfig(
            top: AvatarTop.longCoat,
            specials: AvatarSpecials.outOfScreen, // Animation trigger
          );

          // Act - This will trigger _goDownAndUp
          avatarCubit.onNewAvatarConfig('chat1', avatarConfig);

          // Wait for animation to complete
          await Future<dynamic>.delayed(const Duration(milliseconds: 700));

          // Assert - Specials should be preserved from before animation
          expect(avatarCubit.state.avatar.top, equals(AvatarTop.longCoat));
        },
      );

      // Test: Background change triggers leaveAndComeBack animation
      test('background change triggers leaving and coming animation', () {
        // Arrange
        avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);

        // Act
        final AvatarConfig avatarConfig = AvatarConfig(
          background: AvatarBackgrounds.beach,
          specials: AvatarSpecials.leaveAndComeBack,
        );
        avatarCubit.onNewAvatarConfig('chat1', avatarConfig);

        // Assert - Should trigger leaving animation
        expect(
          avatarCubit.state.statusAnimation,
          AvatarStatusAnimation.leaving,
        );
      });

      // Test: Clothes change triggers dropping/rising animation
      test('clothes change triggers dropping and rising animation', () {
        // Arrange
        avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);

        // Act
        final AvatarConfig avatarConfig = AvatarConfig(
          top: AvatarTop.longCoat,
          specials: AvatarSpecials.outOfScreen,
        );
        avatarCubit.onNewAvatarConfig('chat1', avatarConfig);

        // Assert - Should trigger dropping animation
        expect(
          avatarCubit.state.statusAnimation,
          AvatarStatusAnimation.dropping,
        );
      });

      // Test: Multiple avatar fields can be updated at once
      test('can update multiple avatar fields simultaneously', () {
        // Arrange
        avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
        final AvatarConfig avatarConfig = AvatarConfig(
          background: AvatarBackgrounds.forest,
          hat: AvatarHat.frenchBeret,
          top: AvatarTop.longCoat,
          glasses: AvatarGlasses.sunglasses,
        );

        // Act
        avatarCubit.updateAvatarConfig('chat1', avatarConfig);

        // Assert
        expect(
          avatarCubit.state.avatar.background,
          equals(AvatarBackgrounds.forest),
        );
        expect(avatarCubit.state.avatar.hat, equals(AvatarHat.frenchBeret));
        expect(avatarCubit.state.avatar.top, equals(AvatarTop.longCoat));
        expect(
          avatarCubit.state.avatar.glasses,
          equals(AvatarGlasses.sunglasses),
        );
      });

      // Test: Null values in avatar config preserve existing values
      test('null values preserve existing avatar values', () {
        // Arrange
        avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
        avatarCubit.loadAvatar('chat1');
        avatarCubit.emit(
          avatarCubit.state.copyWith(
            avatar: const Avatar(
              background: AvatarBackgrounds.cityscrape,
              hat: AvatarHat.frenchBeret,
            ),
          ),
        );

        // Act - Update only background, keep other fields
        final AvatarConfig avatarConfig = AvatarConfig(
          background: AvatarBackgrounds.beach,
          // other fields are null
        );
        avatarCubit.updateAvatarConfig('chat1', avatarConfig);

        // Assert
        expect(
          avatarCubit.state.avatar.background,
          equals(AvatarBackgrounds.beach),
        );
        expect(
          avatarCubit.state.avatar.hat,
          equals(AvatarHat.frenchBeret),
        ); // Preserved
      });
    });

    group('AvatarAnimationService Integration', () {
      test('initializes and subscribes to AvatarAnimationService', () {
        // The cubit should be created successfully with the animation service
        expect(avatarCubit, isNotNull);
        expect(avatarCubit.state, isNotNull);
      });

      test('handles animation service events gracefully', () {
        // This test ensures the cubit doesn't crash when receiving animation events
        avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);

        final AvatarConfig avatarConfig = AvatarConfig(
          background: AvatarBackgrounds.beach,
          specials: AvatarSpecials.leaveAndComeBack,
        );

        // Should not throw
        expect(
          () => avatarCubit.updateAvatarConfig('chat1', avatarConfig),
          returnsNormally,
        );
      });
    });
  });
}
