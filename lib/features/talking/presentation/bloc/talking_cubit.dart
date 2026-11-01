import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/app_lifecycle_service.dart';
import '../../../../core/services/audio/interruption_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../sound/sound.dart';
import '../../domain/repositories/talking_repository.dart';
import '../../domain/services/tts_playback_service.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/models/chat_status.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/models/talking_phase.dart';
import 'talking_state.dart';

class TalkingCubit extends Cubit<TalkingState> {
  TalkingCubit(
    this._repository,
    this._interruptionService,
    this._playbackService,
    this._appLifecycleService,
    this._ttsQueue,
  ) : super(const TalkingState.idle()) {
    _eventSubscription = _playbackService.events.listen(_onPlaybackEvent);
    // A finished reply whose speech ran out (a sentence failed to
    // synthesize) leaves "generating" here: no playback event will.
    _drainedSubscription = _ttsQueue.drained.listen((_) => _idleIfSilent());
    _interruptionSubscription = _interruptionService.interruptionStream.listen((
      _,
    ) async {
      await stop();
    });

    // Subscribe to streaming state changes for thinking animation
    _streamingStateSubscription = _appLifecycleService
        .streamingStateChangedEvents
        .listen(
          _handleStreamingStateChanged,
          onError: (Object error) {
            AppLogger.error(
              'Streaming state stream error',
              tag: 'TalkingCubit',
              error: error,
            );
          },
        );

    // Subscribe to chat changes to stop talking
    _chatChangedSubscription = _appLifecycleService.chatChangedEvents.listen(
      _handleChatChanged,
      onError: (Object error) {
        AppLogger.error(
          'Chat changed stream error',
          tag: 'TalkingCubit',
          error: error,
        );
      },
    );
  }

  final TalkingRepository _repository;
  final InterruptionService _interruptionService;
  final TtsPlaybackService _playbackService;
  final AppLifecycleService _appLifecycleService;
  final TtsQueueService _ttsQueue;
  StreamSubscription<void>? _interruptionSubscription;
  StreamSubscription<void>? _drainedSubscription;

  /// The reply in flight has finished streaming (success). From then on,
  /// "generating" ends as soon as no speech is pending: a reply with no
  /// audio (synthesis failed, cue-only or empty) must not think forever.
  bool _replyDone = false;
  StreamSubscription<PlaybackEvent>? _eventSubscription;
  StreamSubscription<ChatStatus>? _streamingStateSubscription;
  StreamSubscription<String>? _chatChangedSubscription;

  /// Handle streaming state changes from app lifecycle service.
  ///
  /// Controls thinking animation based on streaming status.
  void _handleStreamingStateChanged(ChatStatus status) {
    switch (status) {
      case ChatStatus.initial:
      case ChatStatus.creatingChat:
      case ChatStatus.loaded:
      case ChatStatus.updating:
        // Do nothing
        break;
      case ChatStatus.success:
        _replyDone = true;
        _idleIfSilent();
      case ChatStatus.loading:
      case ChatStatus.typing:
      case ChatStatus.streaming:
        // Show thinking animation while waiting for LLM response
        _replyDone = false;
        _idleCooldownTimer?.cancel();
        _idleCooldownTimer = null;
        setLoadingStatus(true);
      case ChatStatus.error:
        // A reply that failed mid-stream may have sentences playing or on
        // their way (the queue is not cleared): let them finish with a
        // moving mouth. With nothing to say, stop thinking now.
        _replyDone = true;
        final bool speechLeft =
            state.phase == TalkingPhase.speaking ||
            (state.phase == TalkingPhase.generating &&
                _ttsQueue.hasPendingSpeech);
        if (!speechLeft) {
          stop();
        }
      case ChatStatus.interrupted:
        // Interruption - stop thinking animation
        _replyDone = false;
        stop();
    }
  }

  /// Ends "generating" once the reply finished and no speech is pending,
  /// through the same cooldown as the end of a sentence (audio that is
  /// about to start cancels it, so normal replies never flicker).
  void _idleIfSilent() {
    if (isClosed ||
        !_replyDone ||
        state.phase != TalkingPhase.generating ||
        _ttsQueue.hasPendingSpeech) {
      return;
    }
    _startIdleCooldown();
  }

  /// Handle chat changed events from app lifecycle service.
  ///
  /// Stops talking when user switches to a different chat.
  void _handleChatChanged(String chatId) {
    stop();
  }

  /// How long the talking state waits before going idle after speech ends,
  /// so the next sentence starting can cancel it (no flicker).
  static const Duration idleCooldown = Duration(milliseconds: 100);

  /// Cooldown timer to prevent flickering between sentences during streaming
  Timer? _idleCooldownTimer;

  void _onPlaybackEvent(PlaybackEvent event) {
    if (isClosed) return;
    switch (event) {
      case SpeakingStartedEvent():
        // Cancel any pending idle transition when new audio starts
        _idleCooldownTimer?.cancel();
        _idleCooldownTimer = null;
        emit(const TalkingState.speaking());
      case SpeakingStoppedEvent():
        // Don't immediately go to idle - start cooldown instead
        // This prevents UI flickering between sentences during streaming
        _startIdleCooldown();
      case MouthStateUpdatedEvent(:final int mouthState):
        _updateMouthStateFromService(mouthState);
      case AnimationCompletedEvent():
        break;
      // Cues are consumed by the avatar feature's AvatarCueService, not by
      // talking state.
      case CuesReachedEvent():
        break;
      // Captions are owned by CaptionCubit.
      case CaptionEvent():
        break;
      // The speech timeline drives the face performer (avatar feature).
      case SpeechTimelineEvent() || SpeechPrerollEvent():
        break;
    }
  }

  void _startIdleCooldown() {
    _idleCooldownTimer?.cancel();
    _idleCooldownTimer = Timer(idleCooldown, () {
      if (!isClosed) {
        emit(const TalkingState.idle());
      }
    });
  }

  Future<void> init() async {
    emit(const TalkingState.idle());
  }

  Future<void> playWaitingSentence(String sentence) async {
    emit(const TalkingState.waiting());

    try {
      await _repository.playWaitingSentence(sentence);
    } catch (e, st) {
      emit(
        TalkingState.error(
          mapExceptionToFailure(e, stackTrace: st, tag: 'TalkingCubit'),
        ),
      );
    }
  }

  Future<void> generateSpeech(String text) async {
    emit(const TalkingState.generating());

    try {
      await _repository.generateSpeech(text);
      emit(const TalkingState.speaking());
    } catch (e, st) {
      emit(
        TalkingState.error(
          mapExceptionToFailure(e, stackTrace: st, tag: 'TalkingCubit'),
        ),
      );
    }
  }

  void setSpeakingState() {
    AppLogger.debug(
      'TalkingCubit: setSpeakingState called, current state: ${state.runtimeType}, about to emit SpeakingState',
      tag: 'TalkingCubit',
    );
    emit(const TalkingState.speaking());
    AppLogger.debug(
      'TalkingCubit: Emitted SpeakingState, new state: ${state.runtimeType}',
      tag: 'TalkingCubit',
    );
  }

  Future<void> stop() async {
    _idleCooldownTimer?.cancel();
    _idleCooldownTimer = null;
    _playbackService.cancelAnimation();
    await _repository.stop();
    emit(const TalkingState.idle());
  }

  void startAmplitudeAnimation(
    String audioPath,
    List<int> amplitudes,
    Duration audioDuration,
    VoidCallback onComplete,
  ) {
    AppLogger.debug(
      'TalkingCubit: startAmplitudeAnimation called with ${amplitudes.length} frames, audioDuration: ${audioDuration.inMilliseconds}ms',
      tag: 'TalkingCubit',
    );

    _animationCompleter = Completer<void>();
    _animationCompleter!.future.then((_) {
      AppLogger.debug('TalkingCubit: Animation completed', tag: 'TalkingCubit');
      if (!isClosed) {
        onComplete();
      }
    });

    _playbackService.startAmplitudeAnimation(
      audioPath,
      amplitudes,
      audioDuration,
    );
  }

  Completer<void>? _animationCompleter;

  void _updateMouthStateFromService(int mouthState) {
    final MouthState newMouthState = _mapMouthStateFromInt(mouthState);

    final TalkingState currentState = state;
    if (currentState.mouthState != newMouthState) {
      currentState.when(
        idle: (MouthState m) => emit(TalkingState.idle(newMouthState)),
        waiting: (MouthState m) => emit(TalkingState.waiting(newMouthState)),
        generating: (MouthState m) =>
            emit(TalkingState.generating(newMouthState)),
        speaking: (MouthState m) => emit(TalkingState.speaking(newMouthState)),
        error: (Failure failure, MouthState m) =>
            emit(TalkingState.error(failure, newMouthState)),
      );
    }
  }

  MouthState _mapMouthStateFromInt(int value) {
    return MouthState.values[value];
  }

  @Deprecated('Use generateSpeech() instead')
  void setLoadingStatus(bool isLoading) {
    if (isLoading) {
      emit(const TalkingState.generating());
    } else {
      emit(const TalkingState.idle());
    }
  }

  @Deprecated('Use stop() instead')
  Future<void> stopTalking({
    bool removeFile = true,
    bool soundEffectsEnabled = false,
    bool updateStatus = true,
  }) async {
    await stop();
  }

  @override
  Future<void> close() async {
    _idleCooldownTimer?.cancel();
    await _eventSubscription?.cancel();
    await _drainedSubscription?.cancel();
    await _interruptionSubscription?.cancel();
    await _streamingStateSubscription?.cancel();
    await _chatChangedSubscription?.cancel();
    await super.close();
  }
}
