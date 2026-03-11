import 'package:flutter/foundation.dart';

import '../../../features/talking/presentation/bloc/talking_cubit.dart';
import '../../utils/logger.dart';

/// Service that coordinates TTS playback with talking state.
///
/// This service abstracts the coordination between TTS playback
/// and the TalkingCubit, removing the direct cubit-to-cubit dependency.
/// It manages the timing and state transitions for speaking animations.
class TtsPlaybackService {
  /// Creates a new TtsPlaybackService.
  ///
  /// [talkingCubit] is optional to support testing and scenarios
  /// where talking state management is not needed.
  TtsPlaybackService({TalkingCubit? talkingCubit})
    : _talkingCubit = talkingCubit;

  final TalkingCubit? _talkingCubit;

  /// Sets the talking state to "speaking" when TTS audio starts playing.
  ///
  /// Call this method when TTS audio playback begins.
  void setSpeakingState() {
    _talkingCubit?.setSpeakingState();
    AppLogger.debug('TTS speaking state set', tag: 'TtsPlaybackService');
  }

  /// Starts the amplitude animation with the provided audio data.
  ///
  /// [audioPath] - The path to the audio file being played
  /// [amplitudes] - List of amplitude values for the animation
  /// [audioDuration] - The duration of the audio file
  /// [onAnimationComplete] - Optional callback when animation completes
  ///
  /// Call this method after extracting amplitudes and before playing audio.
  void startAmplitudeAnimation(
    String audioPath,
    List<int> amplitudes,
    Duration audioDuration, {
    VoidCallback? onAnimationComplete,
  }) {
    _talkingCubit?.startAmplitudeAnimation(
      audioPath,
      amplitudes,
      audioDuration,
      onAnimationComplete ?? () {},
    );
    AppLogger.debug(
      'TTS amplitude animation started: $audioPath (${amplitudes.length} amplitudes)',
      tag: 'TtsPlaybackService',
    );
  }

  /// Stops the talking state and cancels any active animation.
  ///
  /// Call this method when TTS playback completes, is interrupted,
  /// or encounters an error.
  Future<void> stop() async {
    await _talkingCubit?.stop();
    AppLogger.debug('TTS talking state stopped', tag: 'TtsPlaybackService');
  }

  /// Whether this service has a TalkingCubit reference.
  ///
  /// Returns false if the service was created without a TalkingCubit
  /// (e.g., in tests or when talking state is not needed).
  bool get hasTalkingCubit => _talkingCubit != null;
}
