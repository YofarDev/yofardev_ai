import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/features/sound/sound.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/core/services/audio/audio_player_service.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/core/models/app_lifecycle_event.dart';
import 'package:yofardev_ai/features/avatar/domain/models/avatar_animation.dart';

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

  @override
  void trigger(AvatarAnimation animation) {}
}

class MockAudioPlayerService extends Mock implements AudioPlayerService {
  @override
  Future<void> playAsset(String assetPath, {double volume = 1.0}) async {}
}

class MockAppLifecycleService extends Mock implements AppLifecycleService {
  @override
  Stream<AvatarChangeRequested> get avatarChangeRequestedEvents =>
      const Stream<AvatarChangeRequested>.empty();

  @override
  void emitAvatarChangeRequested(AvatarChangeRequested request) {}

  @override
  Stream<NewChatEntryPayload> get newChatEntryEvents =>
      const Stream<NewChatEntryPayload>.empty();

  @override
  Stream<String> get chatChangedEvents => const Stream<String>.empty();

  @override
  Stream<AvatarMood> get moodEvents => const Stream<AvatarMood>.empty();
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
      ).thenAnswer((_) async => Result<void>.ok(null));
      // No saved avatar for the chat (the normal case for a new chat).
      when(() => mockAvatarRepository.getChat(any())).thenAnswer(
        (_) async => Result<Chat>.err(const StorageFailure('no chat')),
      );

      avatarCubit = AvatarCubit(
        mockAvatarRepository,
        mockAnimationService,
        mockAudioPlayerService,
        MockAppLifecycleService(),
        PropReactionService(),
        _FakeSoundRepository(),
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

        expect(avatar.background, AvatarScene.livingRoom);
        expect(avatar.hat, AvatarHat.noHat);
        expect(avatar.top, AvatarTop.pinkHoodie);
        expect(avatar.glasses, AvatarGlasses.glasses);
        expect(avatar.specials, AvatarSpecials.onScreen);
        expect(avatar.costume, AvatarCostume.none);
      });

      test('should copy with new values', () {
        const Avatar avatar = Avatar();
        final Avatar newAvatar = avatar.copyWith(
          background: AvatarScene.beach,
          glasses: AvatarGlasses.sunglasses,
        );

        expect(newAvatar.background, AvatarScene.beach);
        expect(newAvatar.glasses, AvatarGlasses.sunglasses);
        expect(newAvatar.hat, avatar.hat); // unchanged
      });

      test('should serialize and deserialize correctly', () {
        const Avatar avatar = Avatar(
          background: AvatarScene.campfire,
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
        const Avatar avatar3 = Avatar(background: AvatarScene.beach);

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
          background: AvatarScene.beach,
          hat: AvatarHat.beanie,
        );

        expect(config.background, AvatarScene.beach);
        expect(config.hat, AvatarHat.beanie);
        expect(config.top, isNull);
        expect(config.glasses, isNull);
      });

      test('should copy with new values', () {
        const AvatarConfig config = AvatarConfig(background: AvatarScene.beach);
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
          background: AvatarScene.beach,
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
      // The v4 presence flow: walk off (Rive presence = outOfScreen), wait
      // for presence_done, apply the change while hidden, walk back.
      test('leaveAndComeBack walks off, applies the scene while hidden, '
          'then walks back', () async {
        avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
        avatarCubit.updateAvatarConfig(
          'chat1',
          AvatarConfig(
            background: AvatarScene.beach,
            top: AvatarTop.longCoat,
            specials: AvatarSpecials.leaveAndComeBack,
          ),
        );

        // Walking off: Rive gets outOfScreen, nothing is applied yet.
        expect(avatarCubit.state.presence, AvatarSpecials.outOfScreen);
        expect(
          avatarCubit.state.statusAnimation,
          AvatarStatusAnimation.leaving,
        );
        expect(avatarCubit.state.scene, isNot(AvatarScene.beach));

        avatarCubit.onPresenceDone('outOfScreen');
        await Future<void>.delayed(Duration.zero);

        // Hidden: the change lands and the avatar walks back.
        expect(avatarCubit.state.scene, AvatarScene.beach);
        expect(avatarCubit.state.avatar.top, AvatarTop.longCoat);
        expect(avatarCubit.state.presence, AvatarSpecials.onScreen);
        expect(avatarCubit.state.statusAnimation, AvatarStatusAnimation.coming);
        verify(
          () => mockAvatarRepository.updateAvatar('chat1', any()),
        ).called(1);
      });

      test('animation specials are never persisted to the avatar', () async {
        avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
        avatarCubit.updateAvatarConfig(
          'chat1',
          AvatarConfig(
            background: AvatarScene.beach,
            specials: AvatarSpecials.leaveAndComeBack,
          ),
        );
        avatarCubit.onPresenceDone('outOfScreen');
        await Future<void>.delayed(Duration.zero);

        expect(avatarCubit.state.avatar.background, AvatarScene.beach);
        expect(avatarCubit.state.avatar.specials, AvatarSpecials.onScreen);
        final Avatar saved =
            verify(
                  () =>
                      mockAvatarRepository.updateAvatar('chat1', captureAny()),
                ).captured.single
                as Avatar;
        expect(saved.specials, AvatarSpecials.onScreen);
      });

      test('a presence_done for another value does not advance the walk', () {
        avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
        avatarCubit.onNewAvatarConfig(
          'chat1',
          AvatarConfig(
            background: AvatarScene.beach,
            specials: AvatarSpecials.leaveAndComeBack,
          ),
        );
        avatarCubit.onPresenceDone('onScreen');

        expect(avatarCubit.state.presence, AvatarSpecials.outOfScreen);
        expect(avatarCubit.state.scene, isNot(AvatarScene.beach));
      });

      test('the change still lands when Rive never reports presence_done', () {
        fakeAsync((FakeAsync async) {
          avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
          avatarCubit.onNewAvatarConfig(
            'chat1',
            AvatarConfig(
              top: AvatarTop.longCoat,
              specials: AvatarSpecials.outOfScreen,
            ),
          );
          async.elapse(AvatarCubit.presenceLegTimeout);
          async.flushMicrotasks();

          expect(avatarCubit.state.avatar.top, AvatarTop.longCoat);
          expect(avatarCubit.state.presence, AvatarSpecials.onScreen);
        });
      });

      test('a second change waits for the walk in progress', () async {
        avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
        avatarCubit.onNewAvatarConfig(
          'chat1',
          AvatarConfig(
            background: AvatarScene.beach,
            specials: AvatarSpecials.leaveAndComeBack,
          ),
        );
        avatarCubit.onNewAvatarConfig(
          'chat1',
          AvatarConfig(hat: AvatarHat.beanie),
        );
        // The hat is not applied mid-walk.
        expect(avatarCubit.state.avatar.hat, isNot(AvatarHat.beanie));

        avatarCubit.onPresenceDone('outOfScreen');
        await Future<void>.delayed(Duration.zero);
        avatarCubit.onPresenceDone('onScreen');
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(avatarCubit.state.scene, AvatarScene.beach);
        expect(avatarCubit.state.avatar.hat, AvatarHat.beanie);
      });

      // Test: Background change triggers leaveAndComeBack animation
      test('background change triggers leaving and coming animation', () {
        // Arrange
        avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);

        // Act
        final AvatarConfig avatarConfig = AvatarConfig(
          background: AvatarScene.beach,
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
          background: AvatarScene.campfire,
          hat: AvatarHat.frenchBeret,
          top: AvatarTop.longCoat,
          glasses: AvatarGlasses.sunglasses,
        );

        // Act
        avatarCubit.updateAvatarConfig('chat1', avatarConfig);

        // Assert
        expect(
          avatarCubit.state.avatar.background,
          equals(AvatarScene.campfire),
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
              background: AvatarScene.deepSpace,
              hat: AvatarHat.frenchBeret,
            ),
          ),
        );

        // Act - Update only background, keep other fields
        final AvatarConfig avatarConfig = AvatarConfig(
          background: AvatarScene.beach,
          // other fields are null
        );
        avatarCubit.updateAvatarConfig('chat1', avatarConfig);

        // Assert
        expect(avatarCubit.state.avatar.background, equals(AvatarScene.beach));
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
          background: AvatarScene.beach,
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
  group('AvatarCubit cue & mood state (v4)', () {
    late AvatarCubit cubit;
    late AvatarAnimationService animationService;

    Future<void> drain() async {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    setUp(() {
      animationService = AvatarAnimationService();
      cubit = AvatarCubit(
        MockAvatarRepository(),
        animationService,
        MockAudioPlayerService(),
        MockAppLifecycleService(),
        PropReactionService(),
        _FakeSoundRepository(),
      );
    });

    tearDown(() {
      cubit.close();
      animationService.dispose();
    });

    test('a gesture cue sets gestureEvent with an incremented seq', () async {
      animationService.trigger(
        const AvatarAnimation.gesture(AvatarGesture.wave),
      );
      await drain();

      expect(cubit.state.gestureEvent.gesture, AvatarGesture.wave);
      expect(cubit.state.gestureEvent.seq, 1);
    });

    test('the same gesture twice gives two distinct seq values', () async {
      animationService.trigger(
        const AvatarAnimation.gesture(AvatarGesture.nod),
      );
      await drain();
      animationService.trigger(
        const AvatarAnimation.gesture(AvatarGesture.nod),
      );
      await drain();

      expect(cubit.state.gestureEvent.gesture, AvatarGesture.nod);
      expect(cubit.state.gestureEvent.seq, 2);
    });

    test('a scene event sets sceneEvent with an incremented seq', () async {
      animationService.trigger(
        const AvatarAnimation.sceneEvent(SceneEvent.tvOn),
      );
      await drain();

      expect(cubit.state.sceneEvent.sceneEvent, SceneEvent.tvOn);
      expect(cubit.state.sceneEvent.seq, 1);
    });

    test('a mood event updates mood', () async {
      animationService.trigger(const AvatarAnimation.mood(AvatarMood.happy));
      await drain();

      expect(cubit.state.mood, AvatarMood.happy);
    });

    test('a presence event updates presence', () async {
      animationService.trigger(
        const AvatarAnimation.presence(AvatarSpecials.outOfScreen),
      );
      await drain();

      expect(cubit.state.presence, AvatarSpecials.outOfScreen);
    });

    test('a prop tap applies its reaction', () {
      cubit.onPropTapped(AvatarScene.livingRoom, 'tv');

      expect(cubit.state.gestureEvent.gesture, AvatarGesture.laugh);
      expect(cubit.state.gestureEvent.seq, 1);
    });

    test('a prop tap without a reaction changes nothing', () {
      cubit.onPropTapped(AvatarScene.beach, 'volcano');

      expect(cubit.state.gestureEvent.seq, 0);
      expect(cubit.state.mood, AvatarMood.neutral);
    });

    test('an avatar zone tap applies its reaction', () {
      cubit.onAvatarTapped('head');

      expect(cubit.state.mood, AvatarMood.happy);
    });
  });
}

class _FakeSoundRepository implements SoundRepository {
  @override
  Future<Result<void>> play(String soundPath) async => Result<void>.ok(null);

  @override
  Future<Result<void>> stop() async => Result<void>.ok(null);

  @override
  Future<Result<bool>> get isPlaying async => Result<bool>.ok(false);
}
