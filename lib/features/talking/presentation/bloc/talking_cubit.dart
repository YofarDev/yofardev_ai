import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/audio/interruption_service.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/repositories/talking_repository.dart';
import '../../domain/services/tts_playback_service.dart';
import 'talking_state.dart';

/// Cubit responsible for managing TTS playback state
///
/// This cubit abstracts the TTS service through a repository,
/// allowing for proper separation of concerns and testability.
class TalkingCubit extends Cubit<TalkingState> {
  TalkingCubit(
    this._repository,
    this._interruptionService,
    this._playbackService,
  ) : super(const TalkingState.idle()) {
    // Register callback for playback state changes
    _playbackService.setPlaybackStateCallback(_onPlaybackStateChanged);
    // Listen to interruptions
    _interruptionSubscription = _interruptionService.interruptionStream.listen((
      _,
    ) async {
      await stop();
    });
  }

  /// Handle playback state changes from the service.
  ///
  /// When TTS playback starts or stops, we need to update our state accordingly.
  void _onPlaybackStateChanged(bool isSpeaking) {
    if (isSpeaking) {
      emit(const TalkingState.speaking());
    } else {
      emit(const TalkingState.idle());
    }
  }

  final TalkingRepository _repository;
  final InterruptionService _interruptionService;
  final TtsPlaybackService _playbackService;
  StreamSubscription<void>? _interruptionSubscription;

  /// Initialize the cubit
  Future<void> init() async {
    // Initialization logic if needed
    emit(const TalkingState.idle());
  }

  /// Play a waiting sentence - does NOT show thinking animation
  Future<void> playWaitingSentence(String sentence) async {
    emit(const TalkingState.waiting()); // NOT loading!

    try {
      await _repository.playWaitingSentence(sentence);
    } catch (e) {
      emit(TalkingState.error(e.toString()));
    }
  }

  /// Generate TTS for speech - SHOWS thinking animation
  Future<void> generateSpeech(String text) async {
    emit(const TalkingState.generating()); // Separate state!

    try {
      // Generate TTS...
      await _repository.generateSpeech(text);
      emit(const TalkingState.speaking());
    } catch (e) {
      emit(TalkingState.error(e.toString()));
    }
  }

  /// Set speaking state directly without generating TTS
  /// Used when TTS is already generated externally
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

  /// Stop all TTS playback
  Future<void> stop() async {
    await _playbackService.stop();
    emit(const TalkingState.idle());
  }

  /// Update mouth state based on amplitude for lip-sync animation
  void updateMouthState(int amplitude) {
    final MouthState newMouthState = _getMouthState(amplitude);

    // Only emit if state actually changed and we're in a speaking state
    final TalkingState currentState = state;
    if (currentState.mouthState != newMouthState) {
      currentState.when(
        idle: (MouthState mouthState) => emit(TalkingState.idle(newMouthState)),
        waiting: (MouthState mouthState) =>
            emit(TalkingState.waiting(newMouthState)),
        generating: (MouthState mouthState) =>
            emit(TalkingState.generating(newMouthState)),
        speaking: (MouthState mouthState) =>
            emit(TalkingState.speaking(newMouthState)),
        error: (String message, MouthState mouthState) =>
            emit(TalkingState.error(message, newMouthState)),
      );
    }
  }

  /// Start amplitude-based animation for lip-sync
  ///
  /// [audioPath] - Path to the audio file being played
  /// [amplitudes] - List of amplitude values extracted from audio
  /// [audioDuration] - Actual duration of the audio file
  /// [onComplete] - Callback when animation completes
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

    _playbackService.startAmplitudeAnimation(
      audioPath,
      amplitudes,
      audioDuration,
      onMouthStateUpdate: (int mouthState) {
        if (!isClosed) {
          _updateMouthStateFromService(mouthState);
        }
      },
      onComplete: () {
        AppLogger.debug(
          'TalkingCubit: Animation completed',
          tag: 'TalkingCubit',
        );
        if (!isClosed) {
          onComplete();
        }
      },
    );
  }

  /// Update mouth state based on service callback (0-4 scale)
  void _updateMouthStateFromService(int mouthState) {
    final MouthState newMouthState = _mapMouthStateFromInt(mouthState);

    // Only emit if state actually changed and we're in a speaking state
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

  /// Map integer mouth state (0-4) to MouthState enum
  MouthState _mapMouthStateFromInt(int value) {
    return MouthState.values[value];
  }

  /// Map amplitude value to mouth state
  MouthState _getMouthState(int amplitude) {
    if (amplitude == 0) return MouthState.closed;
    if (amplitude <= 5) return MouthState.slightly;
    if (amplitude <= 12) return MouthState.semi;
    if (amplitude <= 18) return MouthState.open;
    return MouthState.wide;
  }

  /// Legacy methods for backward compatibility (will be removed in future refactor)
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
    // Note: Parameters are deprecated and ignored
    // This method now properly awaits the stop operation
    await stop();
  }

  @override
  Future<void> close() async {
    await _interruptionSubscription?.cancel();
    await super.close();
  }
}
