import 'dart:async';

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
import 'package:yofardev_ai/features/avatar/presentation/rive/journey_choreography.dart';

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
      test('a scene change is a journey: pull back, open, walk out, close, '
          'cut, open, walk in, close, vanish', () {
        fakeAsync((FakeAsync async) {
          avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
          avatarCubit.updateAvatarConfig(
            'chat1',
            AvatarConfig(
              background: AvatarScene.beach,
              top: AvatarTop.longCoat,
              specials: AvatarSpecials.leaveAndComeBack,
            ),
          );
          JourneyState j() => avatarCubit.state.journey!;
          expect(j().phase, JourneyPhase.pullBack);
          expect(j().family, JourneyFamily.door);
          expect(avatarCubit.state.preloadScene, AvatarScene.beach);
          expect(avatarCubit.state.presence, AvatarSpecials.onScreen);

          async.elapse(JourneyTiming.pullBack);
          expect(j().phase, JourneyPhase.open);
          expect(avatarCubit.state.headTarget, AvatarCubit.journeyLead);

          // the jacket hangs on the door's peg from its appear
          expect(avatarCubit.state.journeyJacket, 1);
          expect(avatarCubit.state.jacket, isFalse);

          async.elapse(JourneyTiming.open);
          // M8: the door's grab beat, the grab gesture, the contact swap
          expect(j().phase, JourneyPhase.grab);
          expect(avatarCubit.state.gestureEvent.gesture, AvatarGesture.grab);
          expect(avatarCubit.state.presence, AvatarSpecials.onScreen);
          async.elapse(
            JourneyTiming.grabContact - const Duration(milliseconds: 1),
          );
          expect(avatarCubit.state.jacket, isFalse);
          expect(avatarCubit.state.journeyJacket, 1);
          async.elapse(const Duration(milliseconds: 1));
          expect(avatarCubit.state.jacket, isTrue);
          expect(avatarCubit.state.journeyJacket, 0);
          async.elapse(JourneyTiming.grab - JourneyTiming.grabContact);
          expect(j().phase, JourneyPhase.exit);
          expect(avatarCubit.state.jacket, isTrue);
          expect(avatarCubit.state.presence, AvatarSpecials.outOfScreen);
          expect(
            avatarCubit.state.statusAnimation,
            AvatarStatusAnimation.leaving,
          );
          expect(avatarCubit.state.scene, isNot(AvatarScene.beach));

          avatarCubit.onPresenceDone('outOfScreen');
          async.flushMicrotasks();
          expect(j().phase, JourneyPhase.close);
          expect(avatarCubit.state.headTarget, HeadTarget.zero);

          async.elapse(JourneyTiming.close);
          expect(j().phase, JourneyPhase.cut);
          // The scene switches with the avatar still off screen.
          expect(avatarCubit.state.scene, AvatarScene.beach);
          expect(avatarCubit.state.avatar.top, AvatarTop.longCoat);
          expect(avatarCubit.state.presence, AvatarSpecials.outOfScreen);
          verify(
            () => mockAvatarRepository.updateAvatar('chat1', any()),
          ).called(1);

          avatarCubit.onSceneShown(AvatarScene.beach);
          async.flushMicrotasks();
          expect(j().phase, JourneyPhase.arriveOpen);

          async.elapse(JourneyTiming.arriveOpenOf(JourneyFamily.door));
          expect(j().phase, JourneyPhase.enter);
          expect(avatarCubit.state.presence, AvatarSpecials.onScreen);
          expect(
            avatarCubit.state.statusAnimation,
            AvatarStatusAnimation.coming,
          );

          avatarCubit.onPresenceDone('onScreen');
          async.flushMicrotasks();
          // M8: the hang beat puts the jacket on the new door's peg
          expect(j().phase, JourneyPhase.hang);
          expect(avatarCubit.state.jacket, isTrue);
          final int grabSeq = avatarCubit.state.gestureEvent.seq;
          expect(avatarCubit.state.gestureEvent.gesture, AvatarGesture.grab);
          async.elapse(JourneyTiming.grabContact);
          expect(avatarCubit.state.jacket, isFalse);
          expect(avatarCubit.state.journeyJacket, 1);
          async.elapse(JourneyTiming.hang - JourneyTiming.grabContact);
          expect(avatarCubit.state.gestureEvent.seq, grabSeq);
          expect(j().phase, JourneyPhase.arriveClose);
          async.elapse(JourneyTiming.close);
          expect(j().phase, JourneyPhase.vanish);
          expect(avatarCubit.state.journeyJacket, 1);
          async.elapse(JourneyTiming.vanish);
          expect(avatarCubit.state.journey, isNull);
          expect(avatarCubit.state.preloadScene, isNull);
          expect(avatarCubit.state.jacket, isFalse);
          expect(avatarCubit.state.journeyJacket, 0);
        });
      });

      test('a prop tap during a journey is ignored (M11 review)', () {
        fakeAsync((FakeAsync async) {
          avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
          avatarCubit.onNewAvatarConfig(
            'chat1',
            AvatarConfig(
              background: AvatarScene.deepSpace,
              specials: AvatarSpecials.leaveAndComeBack,
            ),
          );
          expect(avatarCubit.state.journey, isNotNull);
          final int seq = avatarCubit.state.gestureEvent.seq;
          avatarCubit.onPropTapped(AvatarScene.livingRoom, 'tv');
          expect(avatarCubit.state.gestureEvent.seq, seq);
        });
      });

      test('a journey to deep space takes the rocket, which lifts off', () {
        fakeAsync((FakeAsync async) {
          avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
          avatarCubit.onNewAvatarConfig(
            'chat1',
            AvatarConfig(
              background: AvatarScene.deepSpace,
              specials: AvatarSpecials.leaveAndComeBack,
            ),
          );
          expect(avatarCubit.state.journey!.family, JourneyFamily.rocket);
          async.elapse(JourneyTiming.pullBack + JourneyTiming.open);
          // no peg on the rocket: no jacket beat, straight to the walk
          expect(avatarCubit.state.journey!.phase, JourneyPhase.exit);
          expect(avatarCubit.state.journeyJacket, 0);
          expect(avatarCubit.state.jacket, isFalse);
          avatarCubit.onPresenceDone('outOfScreen');
          async.flushMicrotasks();
          // the close beat includes the lift-off
          async.elapse(JourneyTiming.close);
          expect(avatarCubit.state.journey!.phase, JourneyPhase.close);
          async.elapse(JourneyTiming.lift);
          expect(avatarCubit.state.journey!.phase, JourneyPhase.cut);
        });
      });

      test('the cut waits for the new scene, at most the timeout', () {
        fakeAsync((FakeAsync async) {
          avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
          avatarCubit.onNewAvatarConfig(
            'chat1',
            AvatarConfig(
              background: AvatarScene.campfire,
              specials: AvatarSpecials.leaveAndComeBack,
            ),
          );
          async.elapse(
            JourneyTiming.pullBack + JourneyTiming.open + JourneyTiming.grab,
          );
          avatarCubit.onPresenceDone('outOfScreen');
          async.flushMicrotasks();
          async.elapse(JourneyTiming.close);
          expect(avatarCubit.state.journey!.phase, JourneyPhase.cut);
          // another scene showing does not release it
          avatarCubit.onSceneShown(AvatarScene.beach);
          async.elapse(const Duration(seconds: 2));
          expect(avatarCubit.state.journey!.phase, JourneyPhase.cut);
          async.elapse(const Duration(seconds: 1));
          expect(avatarCubit.state.journey!.phase, JourneyPhase.arriveOpen);
        });
      });

      test('a chat switch mid-journey stops it before the cut', () {
        fakeAsync((FakeAsync async) {
          avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
          avatarCubit.onNewAvatarConfig(
            'chat1',
            AvatarConfig(
              background: AvatarScene.beach,
              specials: AvatarSpecials.leaveAndComeBack,
            ),
          );
          async.elapse(
            JourneyTiming.pullBack + JourneyTiming.open + JourneyTiming.grab,
          );
          expect(avatarCubit.state.journey!.phase, JourneyPhase.exit);
          expect(avatarCubit.state.jacket, isTrue);
          avatarCubit.loadAvatar('chat2');
          async.flushMicrotasks();
          expect(avatarCubit.state.journey, isNull);
          // the epoch stop also clears the jacket (hand and peg)
          expect(avatarCubit.state.jacket, isFalse);
          expect(avatarCubit.state.journeyJacket, 0);
          expect(avatarCubit.state.preloadScene, isNull);
          expect(avatarCubit.state.presence, AvatarSpecials.onScreen);
          // the walk's wait times out later: nothing lands on either chat
          async.elapse(const Duration(seconds: 20));
          expect(avatarCubit.state.scene, isNot(AvatarScene.beach));
          expect(avatarCubit.state.journey, isNull);
          verifyNever(() => mockAvatarRepository.updateAvatar(any(), any()));
        });
      });

      test('a chat switch during the grab never leaves a jacket behind', () {
        fakeAsync((FakeAsync async) {
          avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
          avatarCubit.onNewAvatarConfig(
            'chat1',
            AvatarConfig(
              background: AvatarScene.beach,
              specials: AvatarSpecials.leaveAndComeBack,
            ),
          );
          async.elapse(JourneyTiming.pullBack + JourneyTiming.open);
          expect(avatarCubit.state.journey!.phase, JourneyPhase.grab);
          avatarCubit.loadAvatar('chat2');
          async.flushMicrotasks();
          // the contact would have come now: it must not
          async.elapse(const Duration(seconds: 5));
          expect(avatarCubit.state.journey, isNull);
          expect(avatarCubit.state.jacket, isFalse);
          expect(avatarCubit.state.journeyJacket, 0);
        });
      });

      test('a chat switch while the jacket is in hand clears it', () {
        fakeAsync((FakeAsync async) {
          avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
          avatarCubit.onNewAvatarConfig(
            'chat1',
            AvatarConfig(
              background: AvatarScene.beach,
              specials: AvatarSpecials.leaveAndComeBack,
            ),
          );
          async.elapse(
            JourneyTiming.pullBack + JourneyTiming.open + JourneyTiming.grab,
          );
          avatarCubit.onPresenceDone('outOfScreen');
          async.flushMicrotasks();
          async.elapse(JourneyTiming.close);
          avatarCubit.onSceneShown(AvatarScene.beach);
          async.flushMicrotasks();
          async.elapse(JourneyTiming.arriveOpenOf(JourneyFamily.door));
          expect(avatarCubit.state.journey!.phase, JourneyPhase.enter);
          expect(avatarCubit.state.jacket, isTrue);
          avatarCubit.loadAvatar('chat2');
          async.flushMicrotasks();
          expect(avatarCubit.state.jacket, isFalse);
          expect(avatarCubit.state.journeyJacket, 0);
          async.elapse(const Duration(seconds: 10));
          expect(avatarCubit.state.jacket, isFalse);
        });
      });

      test('a second scene change runs its own jacket beats after the '
          'first journey ends', () {
        fakeAsync((FakeAsync async) {
          avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
          final List<(bool, double)> jackets = <(bool, double)>[];
          final List<JourneyPhase?> phases = <JourneyPhase?>[];
          avatarCubit.stream.listen((AvatarState s) {
            jackets.add((s.jacket, s.journeyJacket));
            if (phases.isEmpty || phases.last != s.journey?.phase) {
              phases.add(s.journey?.phase);
            }
          });
          avatarCubit.onNewAvatarConfig(
            'chat1',
            AvatarConfig(
              background: AvatarScene.beach,
              specials: AvatarSpecials.leaveAndComeBack,
            ),
          );
          avatarCubit.onNewAvatarConfig(
            'chat1',
            AvatarConfig(
              background: AvatarScene.livingRoom,
              specials: AvatarSpecials.leaveAndComeBack,
            ),
          );
          async.elapse(const Duration(seconds: 40));
          expect(avatarCubit.state.journey, isNull);
          expect(avatarCubit.state.scene, AvatarScene.livingRoom);
          // never two jackets, never one in hand with no journey
          for (final (bool hand, double peg) in jackets) {
            expect(hand && peg > 0, isFalse);
          }
          expect(
            phases.where((JourneyPhase? p) => p == JourneyPhase.grab),
            hasLength(2),
          );
          expect(
            phases.where((JourneyPhase? p) => p == JourneyPhase.hang),
            hasLength(2),
          );
          expect(avatarCubit.state.jacket, isFalse);
        });
      });

      test('the grab gesture_done never reaches the director', () {
        fakeAsync((FakeAsync async) {
          final _CountingDirector director = _CountingDirector();
          final AvatarCubit cubit = AvatarCubit(
            mockAvatarRepository,
            mockAnimationService,
            mockAudioPlayerService,
            MockAppLifecycleService(),
            PropReactionService(),
            _FakeSoundRepository(),
            director: director,
          );
          cubit.setValuesBasedOnScreenWidth(screenWidth: 400);
          cubit.onNewAvatarConfig(
            'chat1',
            AvatarConfig(
              background: AvatarScene.beach,
              specials: AvatarSpecials.leaveAndComeBack,
            ),
          );
          async.elapse(JourneyTiming.pullBack + JourneyTiming.open);
          expect(cubit.state.journey!.phase, JourneyPhase.grab);
          cubit.onGestureDone();
          expect(director.done, 0);
          cubit.close();
          director.dispose();
        });
      });

      test('a director gesture still playing finishes before the grab, and '
          'only its gesture_done reaches the director', () {
        fakeAsync((FakeAsync async) {
          final _ControllableAnimationService animations =
              _ControllableAnimationService();
          final _CountingDirector director = _CountingDirector();
          final AvatarCubit cubit = AvatarCubit(
            mockAvatarRepository,
            animations,
            mockAudioPlayerService,
            MockAppLifecycleService(),
            PropReactionService(),
            _FakeSoundRepository(),
            director: director,
          );
          cubit.setValuesBasedOnScreenWidth(screenWidth: 400);
          animations.controller.add(
            const AvatarAnimation.gesture(AvatarGesture.wave),
          );
          async.flushMicrotasks();
          expect(cubit.state.gestureEvent.gesture, AvatarGesture.wave);
          final int waveSeq = cubit.state.gestureEvent.seq;

          cubit.onNewAvatarConfig(
            'chat1',
            AvatarConfig(
              background: AvatarScene.beach,
              specials: AvatarSpecials.leaveAndComeBack,
            ),
          );
          async.elapse(JourneyTiming.pullBack + JourneyTiming.open);
          // the grab waits: the wave is still the gesture on screen
          expect(cubit.state.journey!.phase, JourneyPhase.open);
          expect(cubit.state.gestureEvent.gesture, AvatarGesture.wave);
          expect(cubit.state.gestureEvent.seq, waveSeq);

          // the wave ends: its gesture_done reaches the director, then the
          // grab plays
          cubit.onGestureDone();
          async.flushMicrotasks();
          expect(director.done, 1);
          expect(cubit.state.journey!.phase, JourneyPhase.grab);
          expect(cubit.state.gestureEvent.gesture, AvatarGesture.grab);
          expect(cubit.state.gestureEvent.seq, waveSeq + 1);

          // the grab's own gesture_done is swallowed
          cubit.onGestureDone();
          expect(director.done, 1);
          cubit.close();
          director.dispose();
          animations.controller.close();
        });
      });

      test(
        'the same scene with new clothes still changes them out of sight',
        () {
          fakeAsync((FakeAsync async) {
            avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
            avatarCubit.onNewAvatarConfig(
              'chat1',
              AvatarConfig(
                background: avatarCubit.state.scene,
                top: AvatarTop.longCoat,
                specials: AvatarSpecials.leaveAndComeBack,
              ),
            );
            async.flushMicrotasks();
            expect(avatarCubit.state.journey, isNull);
            expect(avatarCubit.state.presence, AvatarSpecials.outOfScreen);
            expect(avatarCubit.state.avatar.top, isNot(AvatarTop.longCoat));
            async.elapse(const Duration(seconds: 10));
            expect(avatarCubit.state.avatar.top, AvatarTop.longCoat);
            expect(avatarCubit.state.presence, AvatarSpecials.onScreen);
          });
        },
      );

      test('the same scene needs no journey', () {
        fakeAsync((FakeAsync async) {
          avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
          final AvatarScene scene = avatarCubit.state.scene;
          avatarCubit.onNewAvatarConfig(
            'chat1',
            AvatarConfig(
              background: scene,
              specials: AvatarSpecials.leaveAndComeBack,
            ),
          );
          async.flushMicrotasks();
          expect(avatarCubit.state.journey, isNull);
          expect(avatarCubit.state.presence, AvatarSpecials.onScreen);
          expect(avatarCubit.state.scene, scene);
          verify(
            () => mockAvatarRepository.updateAvatar('chat1', any()),
          ).called(1);
        });
      });

      test('animation specials are never persisted to the avatar', () {
        fakeAsync((FakeAsync async) {
          avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
          avatarCubit.updateAvatarConfig(
            'chat1',
            AvatarConfig(
              background: AvatarScene.beach,
              specials: AvatarSpecials.leaveAndComeBack,
            ),
          );
          // no presence_done, no scene shown: the timeouts carry it through
          async.elapse(const Duration(seconds: 20));

          expect(avatarCubit.state.journey, isNull);
          expect(avatarCubit.state.avatar.background, AvatarScene.beach);
          expect(avatarCubit.state.avatar.specials, AvatarSpecials.onScreen);
          final Avatar saved =
              verify(
                    () => mockAvatarRepository.updateAvatar(
                      'chat1',
                      captureAny(),
                    ),
                  ).captured.single
                  as Avatar;
          expect(saved.specials, AvatarSpecials.onScreen);
        });
      });

      test('a presence_done for another value does not advance the walk', () {
        fakeAsync((FakeAsync async) {
          avatarCubit.setValuesBasedOnScreenWidth(screenWidth: 400);
          avatarCubit.onNewAvatarConfig(
            'chat1',
            AvatarConfig(
              background: AvatarScene.beach,
              specials: AvatarSpecials.leaveAndComeBack,
            ),
          );
          async.elapse(
            JourneyTiming.pullBack + JourneyTiming.open + JourneyTiming.grab,
          );
          avatarCubit.onPresenceDone('onScreen');
          async.flushMicrotasks();

          expect(avatarCubit.state.journey!.phase, JourneyPhase.exit);
          expect(avatarCubit.state.presence, AvatarSpecials.outOfScreen);
          expect(avatarCubit.state.scene, isNot(AvatarScene.beach));
        });
      });

      test('a second change waits for the journey in progress', () {
        fakeAsync((FakeAsync async) {
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
          async.elapse(const Duration(seconds: 2));
          // The hat is not applied mid-journey.
          expect(avatarCubit.state.avatar.hat, isNot(AvatarHat.beanie));

          async.elapse(const Duration(seconds: 20));
          expect(avatarCubit.state.journey, isNull);
          expect(avatarCubit.state.scene, AvatarScene.beach);
          expect(avatarCubit.state.avatar.hat, AvatarHat.beanie);
        });
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

      // Test: Background change triggers leaveAndComeBack animation

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

    group('signature move on a costume change (M10 ruling 6)', () {
      late _RecordingDirector director;
      late AvatarCubit cubit;

      setUp(() {
        director = _RecordingDirector();
        cubit = AvatarCubit(
          mockAvatarRepository,
          mockAnimationService,
          mockAudioPlayerService,
          MockAppLifecycleService(),
          PropReactionService(),
          _FakeSoundRepository(),
          director: director,
        );
        cubit.setValuesBasedOnScreenWidth(screenWidth: 400);
      });

      tearDown(() async {
        await cubit.close();
        await director.dispose();
      });

      void wear(AvatarConfig config, FakeAsync async) {
        cubit.onNewAvatarConfig('chat1', config);
        async.flushMicrotasks();
      }

      test('putting a costume on plays the signature once, after the walk '
          'back in', () {
        fakeAsync((FakeAsync async) {
          wear(
            const AvatarConfig(
              costume: AvatarCostume.batman,
              specials: AvatarSpecials.outOfScreen,
            ),
            async,
          );
          // walking off: nothing yet
          expect(director.requested, isEmpty);
          cubit.onPresenceDone('outOfScreen');
          async.flushMicrotasks();
          // the outfit switched while hidden; still walking back
          expect(cubit.state.avatar.costume, AvatarCostume.batman);
          expect(director.requested, isEmpty);
          cubit.onPresenceDone('onScreen');
          async.flushMicrotasks();
          expect(director.requested, <AvatarGesture>[AvatarGesture.signature]);
          async.elapse(const Duration(seconds: 10));
          expect(director.requested, hasLength(1));
        });
      });

      test('one costume to another plays it; taking it off does not', () {
        fakeAsync((FakeAsync async) {
          cubit.emit(
            cubit.state.copyWith(
              avatar: const Avatar(costume: AvatarCostume.robocop),
            ),
          );
          wear(
            const AvatarConfig(
              costume: AvatarCostume.soubrette,
              specials: AvatarSpecials.outOfScreen,
            ),
            async,
          );
          async.elapse(const Duration(seconds: 10));
          expect(director.requested, <AvatarGesture>[AvatarGesture.signature]);
          director.requested.clear();
          wear(
            const AvatarConfig(
              costume: AvatarCostume.none,
              specials: AvatarSpecials.outOfScreen,
            ),
            async,
          );
          async.elapse(const Duration(seconds: 10));
          expect(cubit.state.avatar.costume, AvatarCostume.none);
          expect(director.requested, isEmpty);
        });
      });

      test('the costume already worn, or other clothes, play nothing', () {
        fakeAsync((FakeAsync async) {
          cubit.emit(
            cubit.state.copyWith(
              avatar: const Avatar(costume: AvatarCostume.singularity),
            ),
          );
          wear(
            const AvatarConfig(
              costume: AvatarCostume.singularity,
              topTint: AvatarTint.red,
              specials: AvatarSpecials.outOfScreen,
            ),
            async,
          );
          wear(
            const AvatarConfig(
              hat: AvatarHat.beanie,
              specials: AvatarSpecials.outOfScreen,
            ),
            async,
          );
          async.elapse(const Duration(seconds: 20));
          expect(cubit.state.avatar.hat, AvatarHat.beanie);
          expect(director.requested, isEmpty);
        });
      });

      test(
        'loading a chat or a new chat restoring a costume plays nothing',
        () {
          fakeAsync((FakeAsync async) {
            when(() => mockAvatarRepository.getChat('chat2')).thenAnswer(
              (_) async => Result<Chat>.ok(
                const Chat(
                  id: 'chat2',
                  avatar: Avatar(costume: AvatarCostume.batman),
                ),
              ),
            );
            cubit.loadAvatar('chat2');
            async.flushMicrotasks();
            expect(cubit.state.avatar.costume, AvatarCostume.batman);
            // the new-chat sequence lands its config without specials
            wear(const AvatarConfig(costume: AvatarCostume.robocop), async);
            async.elapse(const Duration(seconds: 10));
            expect(cubit.state.avatar.costume, AvatarCostume.robocop);
            expect(director.requested, isEmpty);
          });
        },
      );

      test('a journey that also puts a costume on plays nothing', () {
        fakeAsync((FakeAsync async) {
          wear(
            const AvatarConfig(
              background: AvatarScene.beach,
              costume: AvatarCostume.batman,
              specials: AvatarSpecials.leaveAndComeBack,
            ),
            async,
          );
          async.elapse(const Duration(seconds: 30));
          expect(cubit.state.avatar.costume, AvatarCostume.batman);
          expect(cubit.state.journey, isNull);
          expect(
            director.requested.where(
              (AvatarGesture g) => g == AvatarGesture.signature,
            ),
            isEmpty,
          );
        });
      });

      test('the same scene with a costume (no journey) plays it', () {
        fakeAsync((FakeAsync async) {
          wear(
            AvatarConfig(
              background: cubit.state.scene,
              costume: AvatarCostume.robocop,
              specials: AvatarSpecials.leaveAndComeBack,
            ),
            async,
          );
          async.elapse(const Duration(seconds: 10));
          expect(director.requested, <AvatarGesture>[AvatarGesture.signature]);
        });
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

    test('a drag action plays as a scene event (everyone hears it)', () async {
      final List<AvatarAnimation> heard = <AvatarAnimation>[];
      final StreamSubscription<AvatarAnimation> sub = animationService
          .animations
          .listen(heard.add);
      addTearDown(sub.cancel);
      expect(cubit.state.scene, AvatarScene.livingRoom);
      cubit.onSceneDragEvent(SceneEvent.lightsOff);
      await drain();

      expect(cubit.state.sceneEvent.sceneEvent, SceneEvent.lightsOff);
      expect(cubit.state.sceneEvent.seq, 1);
      expect(heard, <AvatarAnimation>[
        const AvatarAnimation.sceneEvent(SceneEvent.lightsOff),
      ]);
    });

    test('a drag start is user activity for the idle ladder, with or without '
        'a scene event', () async {
      final PerformanceDirector director = PerformanceDirector(
        now: DateTime.now,
      );
      final AvatarCubit dragCubit = AvatarCubit(
        MockAvatarRepository(),
        animationService,
        MockAudioPlayerService(),
        MockAppLifecycleService(),
        PropReactionService(),
        _FakeSoundRepository(),
        director: director,
      );
      addTearDown(() async {
        await dragCubit.close();
        director.dispose();
      });
      int activity = 0;
      final StreamSubscription<void> sub = director.activity.listen(
        (_) => activity++,
      );
      addTearDown(sub.cancel);

      dragCubit.onSceneDragStarted();
      await drain();

      expect(activity, 1);
      // nothing else happened: no scene event
      expect(dragCubit.state.sceneEvent.seq, 0);
    });

    test('a drag action foreign to the scene is ignored', () async {
      cubit.onSceneDragEvent(SceneEvent.bell);
      await drain();

      expect(cubit.state.sceneEvent.seq, 0);
    });
  });

  group('reduce motion: a journey is a cross-fade cut (M11 ruling 18)', () {
    late MockAvatarRepository repository;
    late bool reduce;
    late AvatarCubit cubit;

    setUpAll(() {
      registerFallbackValue(const Avatar());
      registerFallbackValue(const AvatarConfig());
    });

    setUp(() {
      repository = MockAvatarRepository();
      when(
        () => repository.updateAvatar(any(), any()),
      ).thenAnswer((_) async => Result<void>.ok(null));
      when(() => repository.getChat(any())).thenAnswer(
        (_) async => Result<Chat>.err(const StorageFailure('no chat')),
      );
      reduce = true;
      cubit = AvatarCubit(
        repository,
        MockAvatarAnimationService(),
        MockAudioPlayerService(),
        MockAppLifecycleService(),
        PropReactionService(),
        _FakeSoundRepository(),
        reduceMotion: () => reduce,
      );
    });

    tearDown(() => cubit.close());

    void changeScene(AvatarScene scene, {AvatarTop? top}) =>
        cubit.onNewAvatarConfig(
          'chat1',
          AvatarConfig(
            background: scene,
            top: top,
            specials: AvatarSpecials.leaveAndComeBack,
          ),
        );

    test(
      'fade out, cut (saved, no walk), fade in: no threshold, no jacket',
      () {
        fakeAsync((FakeAsync async) {
          cubit.setValuesBasedOnScreenWidth(screenWidth: 400);
          // livingRoom → beach is a door journey: its jacket beats are skipped
          changeScene(AvatarScene.beach, top: AvatarTop.longCoat);
          JourneyState j() => cubit.state.journey!;
          expect(j().reduced, isTrue);
          expect(j().phase, JourneyPhase.close);
          expect(j().fadedOut, isTrue);
          expect(j().hasJacket, isFalse);
          expect(cubit.state.preloadScene, AvatarScene.beach);
          expect(cubit.state.presence, AvatarSpecials.onScreen);
          expect(cubit.state.scene, AvatarScene.livingRoom);
          // the overlay draws nothing for it
          expect(
            JourneyChoreography.at(j(), Duration.zero, reduceMotion: true),
            JourneyFrame.none,
          );

          async.elapse(JourneyTiming.reducedFade);
          expect(j().phase, JourneyPhase.cut);
          expect(j().fadedOut, isTrue);
          // the scene and the clothes land with the avatar on screen, saved
          expect(cubit.state.scene, AvatarScene.beach);
          expect(cubit.state.avatar.top, AvatarTop.longCoat);
          expect(cubit.state.presence, AvatarSpecials.onScreen);
          expect(cubit.state.statusAnimation, AvatarStatusAnimation.initial);
          verify(() => repository.updateAvatar('chat1', any())).called(1);

          // the fade back waits for the new file on screen
          async.elapse(const Duration(milliseconds: 500));
          expect(j().phase, JourneyPhase.cut);
          cubit.onSceneShown(AvatarScene.beach);
          async.flushMicrotasks();
          expect(j().phase, JourneyPhase.vanish);
          expect(j().fadedOut, isFalse);

          async.elapse(JourneyTiming.reducedFade);
          expect(cubit.state.journey, isNull);
          expect(cubit.state.preloadScene, isNull);
          // never a walk, a grab or a jacket
          expect(cubit.state.jacket, isFalse);
          expect(cubit.state.journeyJacket, 0);
          expect(cubit.state.gestureEvent.seq, 0);
        });
      },
    );

    test('the cut still arrives when the new scene never shows', () {
      fakeAsync((FakeAsync async) {
        changeScene(AvatarScene.deepSpace);
        async.elapse(JourneyTiming.reducedFade + JourneyTiming.waitTimeout);
        expect(cubit.state.journey!.phase, JourneyPhase.vanish);
        async.elapse(JourneyTiming.reducedFade);
        expect(cubit.state.journey, isNull);
        expect(cubit.state.scene, AvatarScene.deepSpace);
      });
    });

    test('the switch is read when a journey starts: off, it walks', () {
      fakeAsync((FakeAsync async) {
        reduce = false;
        changeScene(AvatarScene.campfire);
        expect(cubit.state.journey!.reduced, isFalse);
        expect(cubit.state.journey!.phase, JourneyPhase.pullBack);
      });
    });

    test('a chat switch during the fade stops it before the cut', () {
      fakeAsync((FakeAsync async) {
        changeScene(AvatarScene.cafe);
        expect(cubit.state.journey, isNotNull);
        cubit.loadAvatar('chat2');
        async.flushMicrotasks();
        async.elapse(JourneyTiming.reducedFade * 3);
        expect(cubit.state.journey, isNull);
        expect(cubit.state.scene, isNot(AvatarScene.cafe));
        verifyNever(() => repository.updateAvatar('chat1', any()));
      });
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

/// An animation service whose stream the test drives.
class _ControllableAnimationService extends MockAvatarAnimationService {
  final StreamController<AvatarAnimation> controller =
      StreamController<AvatarAnimation>.broadcast();

  @override
  Stream<AvatarAnimation> get animations => controller.stream;
}

/// Counts the `gesture_done`s forwarded to the director.
class _CountingDirector extends PerformanceDirector {
  _CountingDirector() : super(now: DateTime.now);

  int done = 0;

  @override
  void onGestureDone() {
    done++;
    super.onGestureDone();
  }
}

/// Records the gestures requested of the director.
class _RecordingDirector extends PerformanceDirector {
  _RecordingDirector() : super(now: DateTime.now);

  final List<AvatarGesture> requested = <AvatarGesture>[];

  @override
  void requestGesture(
    AvatarGesture gesture, {
    GestureSource source = GestureSource.llm,
  }) {
    requested.add(gesture);
    super.requestGesture(gesture, source: source);
  }
}
