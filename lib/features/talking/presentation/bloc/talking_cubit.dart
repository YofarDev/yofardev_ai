import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/audio/interruption_service.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/repositories/talking_repository.dart';
import '../../domain/services/tts_playback_service.dart';
import 'talking_state.dart';

class TalkingCubit extends Cubit<TalkingState> {
  TalkingCubit(
    this._repository,
    this._interruptionService,
    this._playbackService,
  ) : super(const TalkingState.idle()) {
    _eventSubscription = _playbackService.events.listen(_onPlaybackEvent);
    _interruptionSubscription = _interruptionService.interruptionStream.listen((
      _,
    ) async {
      await stop();
    });
  }

  final TalkingRepository _repository;
  final InterruptionService _interruptionService;
  final TtsPlaybackService _playbackService;
  StreamSubscription<void>? _interruptionSubscription;
  StreamSubscription<PlaybackEvent>? _eventSubscription;

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
        _idleCooldownTimer?.cancel();
        _idleCooldownTimer = Timer(const Duration(milliseconds: 100), () {
          if (!isClosed) {
            emit(const TalkingState.idle());
          }
        });
      case MouthStateUpdatedEvent(:final int mouthState):
        _updateMouthStateFromService(mouthState);
      case AnimationCompletedEvent():
        break;
    }
  }

  Future<void> init() async {
    emit(const TalkingState.idle());
  }

  Future<void> playWaitingSentence(String sentence) async {
    emit(const TalkingState.waiting());

    try {
      await _repository.playWaitingSentence(sentence);
    } catch (e) {
      emit(TalkingState.error(e.toString()));
    }
  }

  Future<void> generateSpeech(String text) async {
    emit(const TalkingState.generating());

    try {
      await _repository.generateSpeech(text);
      emit(const TalkingState.speaking());
    } catch (e) {
      emit(TalkingState.error(e.toString()));
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
        error: (String message, MouthState m) =>
            emit(TalkingState.error(message, newMouthState)),
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
    await _interruptionSubscription?.cancel();
    await super.close();
  }
}
