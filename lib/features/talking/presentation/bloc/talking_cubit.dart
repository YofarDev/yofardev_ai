import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/repositories/talking_repository.dart';
import 'talking_state.dart';

/// Cubit responsible for managing TTS playback state
///
/// This cubit abstracts the TTS service through a repository,
/// allowing for proper separation of concerns and testability.
class TalkingCubit extends Cubit<TalkingState> {
  TalkingCubit(this._repository) : super(const TalkingState.idle());

  final TalkingRepository _repository;
  Timer? _animationTimer;

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
    _animationTimer?.cancel();
    _animationTimer = null;
    await _repository.stop();
    emit(const TalkingState.idle());
  }

  /// Update mouth state based on amplitude for lip-sync animation
  void updateMouthState(int amplitude) {
    final MouthState newMouthState = _getMouthState(amplitude);

    // Only emit if state actually changed and we're in a speaking state
    final TalkingState currentState = state;
    if (currentState.mouthState != newMouthState) {
      AppLogger.debug(
        'TalkingCubit: Updating mouth state: ${currentState.mouthState.name} -> $newMouthState (amplitude: $amplitude)',
        tag: 'TalkingCubit',
      );
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

    // Cancel any existing animation
    _animationTimer?.cancel();

    if (amplitudes.isEmpty) {
      AppLogger.debug(
        'TalkingCubit: No amplitudes, calling onComplete immediately',
        tag: 'TalkingCubit',
      );
      onComplete();
      return;
    }

    final int totalFrames = amplitudes.length;
    // Calculate update interval based on ACTUAL audio duration
    final int updateInterval = (audioDuration.inMilliseconds / totalFrames)
        .round()
        .clamp(5, 100); // Clamp to reasonable range

    AppLogger.debug(
      'TalkingCubit: Starting animation timer: interval=${updateInterval}ms, frames=$totalFrames, totalDuration=${audioDuration.inMilliseconds}ms',
      tag: 'TalkingCubit',
    );

    int currentIndex = 0;
    _animationTimer = Timer.periodic(Duration(milliseconds: updateInterval), (
      Timer timer,
    ) {
      if (currentIndex >= totalFrames) {
        AppLogger.debug(
          'TalkingCubit: Animation completed after $currentIndex frames',
          tag: 'TalkingCubit',
        );
        timer.cancel();
        _animationTimer = null;
        onComplete();
        return;
      }

      if (!isClosed) {
        updateMouthState(amplitudes[currentIndex]);
        currentIndex++;
      } else {
        AppLogger.debug(
          'TalkingCubit: Cubit closed, cancelling animation',
          tag: 'TalkingCubit',
        );
        timer.cancel();
        _animationTimer = null;
      }
    });
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
    _animationTimer?.cancel();
    await super.close();
  }
}
