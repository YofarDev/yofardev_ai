import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/app_lifecycle_event.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/avatar_gesture.dart';
import '../../../../core/models/avatar_mood.dart';
import '../../../../core/models/avatar_scene.dart';
import '../../../../core/models/sound_effects.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/models/result.dart';
import '../../domain/repositories/avatar_repository.dart';
import '../../../../core/res/app_constants.dart';
import '../../../../core/services/app_lifecycle_service.dart';
import '../../../../core/services/audio/audio_player_service.dart';
import '../../../../features/avatar/domain/services/avatar_animation_service.dart';
import '../../../../features/avatar/domain/services/prop_reaction_service.dart';
import '../../../sound/sound.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/models/chat.dart';
import '../../domain/models/avatar_animation.dart';
import '../../domain/models/performance_intent.dart';
import '../../domain/services/head_target_mapper.dart';
import '../../domain/services/performance_director.dart';
import 'avatar_state.dart';

class AvatarCubit extends Cubit<AvatarState> {
  AvatarCubit(
    this._avatarRepository,
    this._animationService,
    this._audioPlayerService,
    this._appLifecycleService,
    this._propReactions,
    this._soundRepository, {
    PerformanceDirector? director,
  }) : _director = director,
       super(
         const AvatarState(avatar: Avatar(), avatarConfig: AvatarConfig()),
       ) {
    // Subscribe to animation events from the service
    _animationSubscription = _animationService.animations.listen(
      _handleAnimationEvent,
      onError: (Object error) {
        AppLogger.error(
          'Animation stream error',
          tag: 'AvatarCubit',
          error: error,
        );
      },
    );

    // Subscribe to app lifecycle events
    _lifecycleSubscription = _appLifecycleService.newChatEntryEvents.listen(
      _handleNewChatEntryEvent,
      onError: (Object error) {
        AppLogger.error(
          'Lifecycle stream error',
          tag: 'AvatarCubit',
          error: error,
        );
      },
    );

    _chatChangedSubscription = _appLifecycleService.chatChangedEvents.listen(
      _handleChatChangedEvent,
      onError: (Object error) {
        AppLogger.error(
          'Chat changed stream error',
          tag: 'AvatarCubit',
          error: error,
        );
      },
    );

    // Reply moods ride the same animation handler as the other cues.
    _moodSubscription = _appLifecycleService.moodEvents.listen(
      (AvatarMood mood) => _handleAnimationEvent(AvatarAnimation.mood(mood)),
      onError: (Object error) {
        AppLogger.error('Mood stream error', tag: 'AvatarCubit', error: error);
      },
    );

    // The director's gaze becomes the head target the Rive view chases.
    _intentSubscription = _director?.intents.listen(
      _handleIntent,
      onError: (Object error) {
        AppLogger.error(
          'Intent stream error',
          tag: 'AvatarCubit',
          error: error,
        );
      },
    );
  }

  final AvatarRepository _avatarRepository;
  final AvatarAnimationService _animationService;
  final AudioPlayerService _audioPlayerService;
  final AppLifecycleService _appLifecycleService;
  final PropReactionService _propReactions;

  /// Receives `gesture_done` so its gesture queue advances without waiting
  /// for the safety timeout. Optional for tests that do not exercise it.
  final PerformanceDirector? _director;
  final SoundRepository _soundRepository;

  /// True when the latest gesture sent to the Rive view came from a prop or
  /// avatar tap rather than from the director.
  bool _propGesturePlaying = false;
  StreamSubscription<AvatarAnimation>? _animationSubscription;
  StreamSubscription<NewChatEntryPayload>? _lifecycleSubscription;
  StreamSubscription<String>? _chatChangedSubscription;
  StreamSubscription<AvatarMood>? _moodSubscription;
  StreamSubscription<PerformanceIntent>? _intentSubscription;

  void _handleIntent(PerformanceIntent intent) {
    final HeadTarget target = headTargetFor(
      intent.gaze,
      activeTool: intent.activeTool,
    );
    if (target != state.headTarget) {
      _emitIfOpen(state.copyWith(headTarget: target));
    }
  }

  /// Handle animation events from the service.
  void _handleAnimationEvent(AvatarAnimation event) {
    AppLogger.debug(
      'AvatarCubit: received animation event: $event',
      tag: 'AvatarCubit',
    );
    event.when(
      clothes: (bool goingDown) => onClothesAnimationChanged(goingDown),
      background: (BackgroundTransition transition) =>
          onBackgroundTransitionChanged(transition),
      updateConfig: (String chatId, AvatarConfig avatarConfig) {
        AppLogger.debug(
          'AvatarCubit: updateConfig event - chatId=$chatId, config=$avatarConfig',
          tag: 'AvatarCubit',
        );
        updateAvatarConfig(chatId, avatarConfig);
      },
      gesture: (AvatarGesture gesture) {
        // The Rive view fires the trigger from a BlocListener keyed on seq,
        // so repeating the same gesture still plays.
        _propGesturePlaying = false;
        _emitIfOpen(
          state.copyWith(
            gestureEvent: (gesture: gesture, seq: state.gestureEvent.seq + 1),
          ),
        );
      },
      sceneEvent: (SceneEvent sceneEvent) {
        _emitIfOpen(
          state.copyWith(
            sceneEvent: (sceneEvent: sceneEvent, seq: state.sceneEvent.seq + 1),
          ),
        );
      },
      mood: (AvatarMood mood) {
        _emitIfOpen(state.copyWith(mood: mood));
      },
      presence: (AvatarSpecials presence) {
        _emitIfOpen(state.copyWith(presence: presence));
      },
    );
  }

  /// Handle new chat entry events from app lifecycle service.
  void _handleNewChatEntryEvent(NewChatEntryPayload payload) {
    onNewAvatarConfig(payload.chatId, payload.newAvatarConfig);
  }

  /// Handle chat changed events from app lifecycle service.
  void _handleChatChangedEvent(String chatId) {
    loadAvatar(chatId);
  }

  void _emitIfOpen(AvatarState newState) {
    if (isClosed) return;
    emit(newState);
  }

  void setValuesBasedOnScreenWidth({required double screenWidth}) {
    if (!screenWidth.isFinite || screenWidth <= 0) return;
    final double scaleFactor = screenWidth / AppConstants.avatarWidth;
    _emitIfOpen(
      state.copyWith(
        status: AvatarStatus.ready,
        baseOriginalWidth: AppConstants.avatarWidth,
        baseOriginalHeight: AppConstants.avatarHeight,
        scaleFactor: scaleFactor,
      ),
    );
  }

  void onScreenSizeChanged(double screenWidth) {
    if (!screenWidth.isFinite || screenWidth <= 0) return;
    if (!state.baseOriginalWidth.isFinite || state.baseOriginalWidth <= 0) {
      setValuesBasedOnScreenWidth(screenWidth: screenWidth);
      return;
    }
    final double scaleFactor = screenWidth / state.baseOriginalWidth;
    if (!scaleFactor.isFinite || scaleFactor <= 0) {
      setValuesBasedOnScreenWidth(screenWidth: screenWidth);
      return;
    }
    _emitIfOpen(state.copyWith(scaleFactor: scaleFactor));
  }

  void loadAvatar(String chatId) async {
    _emitIfOpen(state.copyWith(status: AvatarStatus.loading));
    final Result<Chat> result = await _avatarRepository.getChat(chatId);
    if (isClosed) return;
    result.when(
      err: (Failure failure) {
        // This is expected for new chats - no custom avatar saved yet
        // Only set status to ready if dimensions are initialized
        if (state.baseOriginalHeight > 0) {
          _emitIfOpen(state.copyWith(status: AvatarStatus.ready));
        }
      },
      ok: (Chat chat) {
        // Only set status to ready if dimensions are initialized
        if (state.baseOriginalHeight > 0) {
          _emitIfOpen(
            state.copyWith(
              avatar: chat.avatar,
              status: AvatarStatus.ready,
              scene: chat.avatar.background,
            ),
          );
        } else {
          _emitIfOpen(
            state.copyWith(avatar: chat.avatar, scene: chat.avatar.background),
          );
        }
      },
    );
  }

  void onAnimationStatusChanged(bool leaving) {
    _emitIfOpen(
      state.copyWith(
        statusAnimation: leaving
            ? AvatarStatusAnimation.leaving
            : AvatarStatusAnimation.coming,
        avatar: state.avatar.copyWith(
          specials: leaving
              ? AvatarSpecials.outOfScreen
              : AvatarSpecials.onScreen,
        ),
        presence: leaving
            ? AvatarSpecials.outOfScreen
            : AvatarSpecials.onScreen,
        previousSpecialsState: leaving
            ? AvatarSpecials.outOfScreen
            : AvatarSpecials.onScreen,
      ),
    );
  }

  void onClothesAnimationChanged(bool goingDown) {
    _emitIfOpen(
      state.copyWith(
        statusAnimation: goingDown
            ? AvatarStatusAnimation.dropping
            : AvatarStatusAnimation.rising,
        avatar: state.avatar.copyWith(
          specials: goingDown
              ? AvatarSpecials.outOfScreen
              : AvatarSpecials.onScreen,
        ),
        presence: goingDown
            ? AvatarSpecials.outOfScreen
            : AvatarSpecials.onScreen,
        previousSpecialsState: goingDown
            ? AvatarSpecials.outOfScreen
            : AvatarSpecials.onScreen,
      ),
    );
  }

  /// Upper bound for one walk leg (Rive: 80 frames at 60 fps, ~1.3 s) when
  /// the Rive file never reports `presence_done` — not loaded yet, app in
  /// the background. The change is applied anyway once it elapses.
  static const Duration presenceLegTimeout = Duration(seconds: 3);

  Completer<void>? _presenceDone;
  AvatarSpecials? _awaitedPresence;

  /// Presence transitions run one after another, so two quick config
  /// changes never interleave their walks (or lose either change).
  Future<void> _presenceChain = Future<void>.value();
  int _pendingTransitions = 0;

  void _enqueueTransition(Future<void> Function() transition) {
    // Idle: start now, so the walk-off state is emitted synchronously.
    final Future<void> next = _pendingTransitions == 0
        ? transition()
        : _presenceChain.then((_) => transition());
    _pendingTransitions++;
    _presenceChain = next.whenComplete(() => _pendingTransitions--);
  }

  void onNewAvatarConfig(String chatId, AvatarConfig avatarConfig) {
    AppLogger.debug(
      'onNewAvatarConfig called with specials: ${avatarConfig.specials}',
      tag: 'AvatarCubit',
    );

    final AvatarSpecials? specials = avatarConfig.specials;
    if (specials == AvatarSpecials.leaveAndComeBack ||
        specials == AvatarSpecials.outOfScreen) {
      // leaveAndComeBack: scene change. outOfScreen: clothes change. Either
      // way the avatar walks off, the change lands while it is hidden, and
      // it walks back.
      _enqueueTransition(
        () => _walkOffAndBack(
          chatId,
          avatarConfig,
          clothesChange: specials == AvatarSpecials.outOfScreen,
        ),
      );
      return;
    }
    if (_pendingTransitions == 0) {
      // Nothing walking: apply right away.
      _updateAvatar(chatId, avatarConfig);
      return;
    }
    // Land after the walk in progress so it is not undone by it.
    _enqueueTransition(() async => _updateAvatar(chatId, avatarConfig));
  }

  /// Drives the Rive `presence` property: walks out (`outOfScreen`), waits
  /// for `presence_done`, applies [avatarConfig], then walks back in
  /// (`onScreen`) and waits again so the next transition starts clean.
  Future<void> _walkOffAndBack(
    String chatId,
    AvatarConfig avatarConfig, {
    required bool clothesChange,
  }) async {
    if (isClosed) return;
    if (clothesChange) {
      unawaited(
        _audioPlayerService.playAsset('sound_effects/whoosh.wav', volume: 0.3),
      );
    }
    _emitIfOpen(
      state.copyWith(
        statusAnimation: clothesChange
            ? AvatarStatusAnimation.dropping
            : AvatarStatusAnimation.leaving,
        presence: AvatarSpecials.outOfScreen,
        previousSpecialsState: AvatarSpecials.outOfScreen,
      ),
    );
    await _waitForPresence(AvatarSpecials.outOfScreen);
    if (isClosed) return;

    _emitIfOpen(
      state.copyWith(
        statusAnimation: clothesChange
            ? AvatarStatusAnimation.rising
            : AvatarStatusAnimation.coming,
      ),
    );
    // Transition values are never persisted: the avatar ends on screen.
    _updateAvatar(
      chatId,
      avatarConfig.copyWith(specials: AvatarSpecials.onScreen),
    );
    await _waitForPresence(AvatarSpecials.onScreen);
  }

  Future<void> _waitForPresence(AvatarSpecials presence) {
    final Completer<void> completer = Completer<void>();
    _presenceDone = completer;
    _awaitedPresence = presence;
    return completer.future
        .timeout(
          presenceLegTimeout,
          onTimeout: () {
            AppLogger.debug(
              'presence_done(${presence.name}) not received; continuing',
              tag: 'AvatarCubit',
            );
          },
        )
        .whenComplete(() {
          if (identical(_presenceDone, completer)) {
            _presenceDone = null;
            _awaitedPresence = null;
          }
        });
  }

  /// Called by the Rive view when the avatar file emits `gesture_done`.
  ///
  /// A `gesture_done` that belongs to a prop-reaction gesture (which never
  /// went through the director) is not forwarded: it would release the
  /// director's queue while one of its own gestures is still playing.
  void onGestureDone() {
    if (_propGesturePlaying) {
      _propGesturePlaying = false;
      return;
    }
    _director?.onGestureDone();
  }

  /// Called by the Rive view when the avatar file emits `presence_done`.
  void onPresenceDone(String presence) {
    if (_awaitedPresence?.name != presence) return;
    final Completer<void>? completer = _presenceDone;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _updateAvatar(String chatId, AvatarConfig avatarConfig) {
    final Avatar avatar = state.avatar.copyWith(
      hat: avatarConfig.hat ?? state.avatar.hat,
      top: avatarConfig.top ?? state.avatar.top,
      glasses: avatarConfig.glasses ?? state.avatar.glasses,
      specials: avatarConfig.specials ?? state.avatar.specials,
      background: avatarConfig.background ?? state.avatar.background,
      costume: avatarConfig.costume ?? state.avatar.costume,
    );
    _emitIfOpen(
      state.copyWith(
        avatar: avatar,
        scene: avatar.background,
        // The avatar is on screen once a config lands; walk-off
        // transitions are driven by _walkOffAndBack.
        presence: AvatarSpecials.onScreen,
        previousSpecialsState:
            avatarConfig.specials ?? state.previousSpecialsState,
      ),
    );
    _avatarRepository.updateAvatar(chatId, avatar);
  }

  /// A tap on a scene prop triggers its local reaction only: no LLM call
  /// and nothing written to chat history.
  void onPropTapped(AvatarScene scene, String propId) {
    final PropReaction? reaction = _propReactions.reactionForProp(
      scene,
      propId,
    );
    if (reaction == null) {
      AppLogger.debug(
        'AvatarCubit: no reaction for prop $propId in ${scene.name}',
        tag: 'AvatarCubit',
      );
      return;
    }
    _applyReaction(reaction);
  }

  /// A tap on the avatar itself (zone: head or body per contract).
  void onAvatarTapped(String zone) {
    final PropReaction? reaction = _propReactions.reactionForZone(zone);
    if (reaction == null) {
      AppLogger.debug(
        'AvatarCubit: no reaction for zone $zone',
        tag: 'AvatarCubit',
      );
      return;
    }
    _applyReaction(reaction);
  }

  void _applyReaction(PropReaction reaction) {
    AvatarState next = state;
    final AvatarMood? reactionMood = reaction.mood;
    if (reactionMood != null) {
      next = next.copyWith(mood: reactionMood);
    }
    if (reaction.gesture != null) {
      final AvatarGesture gesture = reaction.gesture!;
      _propGesturePlaying = true;
      next = next.copyWith(
        gestureEvent: (gesture: gesture, seq: next.gestureEvent.seq + 1),
      );
    }
    if (next != state) {
      _emitIfOpen(next);
    }
    final SoundEffects? sound = reaction.soundEffect;
    if (sound != null) {
      unawaited(_soundRepository.play(sound.getPath()));
    }
  }

  void toggleGlasses() {
    final AvatarGlasses glasses = state.avatar.glasses == AvatarGlasses.glasses
        ? AvatarGlasses.sunglasses
        : AvatarGlasses.glasses;
    emit(state.copyWith(avatar: state.avatar.copyWith(glasses: glasses)));
  }

  void onBackgroundTransitionChanged(BackgroundTransition transition) {
    _emitIfOpen(state.copyWith(backgroundTransition: transition));
  }

  void updateAvatarConfig(String chatId, AvatarConfig avatarConfig) {
    // Use onNewAvatarConfig to trigger animations based on specials
    onNewAvatarConfig(chatId, avatarConfig);
  }

  @override
  Future<void> close() async {
    await _animationSubscription?.cancel();
    await _lifecycleSubscription?.cancel();
    await _chatChangedSubscription?.cancel();
    await _moodSubscription?.cancel();
    await _intentSubscription?.cancel();
    return super.close();
  }
}
