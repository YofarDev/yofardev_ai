import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/logger.dart';
import 'home_state.dart';

/// HomeCubit manages home page specific state and actions
class HomeCubit extends Cubit<HomeState> {
  HomeCubit() : super(const HomeState());

  final AudioPlayer _ttsPlayer = AudioPlayer();

  /// Initialize the home cubit
  Future<void> initialize() async {
    emit(state.copyWith(isInitialized: true));
  }

  /// Start volume fade in or out
  void startVolumeFade(bool fadeIn) {
    emit(state.copyWith(isFading: fadeIn));
  }

  /// Start the waiting TTS loop
  void startWaitingTtsLoop() {
    emit(state.copyWith(isPlayingWaitingLoop: true));
  }

  /// Stop the waiting TTS loop
  void stopWaitingTtsLoop() {
    emit(state.copyWith(isPlayingWaitingLoop: false));
  }

  /// Play TTS with the given audio path
  Future<void> playTts(
    String audioPath, {
    bool removeFile = true,
    bool soundEffectsEnabled = true,
    bool updateStatus = true,
    VoidCallback? onComplete,
  }) async {
    try {
      // Stop any currently playing audio
      await _ttsPlayer.stop();

      // Load and play the TTS audio file
      await _ttsPlayer.setFilePath(audioPath);

      // Set up completion handler
      _ttsPlayer.playerStateStream
          .where(
            (PlayerState state) =>
                state.processingState == ProcessingState.completed ||
                state.processingState == ProcessingState.idle,
          )
          .take(1)
          .listen((_) {
            if (onComplete != null) {
              onComplete();
            }
          });

      // Start playback
      await _ttsPlayer.play();
    } catch (e) {
      AppLogger.error('Error playing TTS', tag: 'HomeCubit', error: e);
      // Still call onComplete even on error to avoid hanging
      if (onComplete != null) {
        onComplete();
      }
    }
  }

  @override
  Future<void> close() async {
    await _ttsPlayer.dispose();
    super.close();
  }
}
