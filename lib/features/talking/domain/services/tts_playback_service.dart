import 'dart:async';
import 'dart:ui';

import '../../../../core/utils/logger.dart';
import '../repositories/talking_repository.dart';

/// Service for coordinating TTS playback across features.
///
/// This service manages the business logic for TTS playback coordination,
/// including amplitude animation for lip-sync and playback state management.
///
/// It eliminates the need for cubits to depend on each other by providing
/// a shared service that both can use.
class TtsPlaybackService {
  TtsPlaybackService(this._repository);

  final TalkingRepository _repository;
  Timer? _animationTimer;

  /// Callback for when TTS playback state changes (true = started, false = stopped)
  void Function(bool isSpeaking)? _onPlaybackStateChanged;

  /// Set a callback to be notified when playback state changes.
  ///
  /// This allows cubits to react to TTS playback state changes without
  /// directly depending on each other.
  void setPlaybackStateCallback(void Function(bool isSpeaking)? callback) {
    _onPlaybackStateChanged = callback;
  }

  /// Notify that playback state has changed (true = started, false = stopped).
  void _notifyPlaybackStateChanged(bool isSpeaking) {
    _onPlaybackStateChanged?.call(isSpeaking);
  }

  /// Notify that TTS has started speaking.
  void notifySpeakingStarted() {
    _notifyPlaybackStateChanged(true);
  }

  /// Notify that TTS has stopped speaking.
  void notifySpeakingStopped() {
    _notifyPlaybackStateChanged(false);
  }

  /// Stop all TTS playback and cancel any active animation.
  Future<void> stop() async {
    _animationTimer?.cancel();
    _animationTimer = null;
    await _repository.stop();
    // Notify that speaking has stopped
    notifySpeakingStopped();
  }

  /// Start amplitude-based animation for lip-sync.
  ///
  /// This method manages a timer that updates mouth state based on audio
  /// amplitude data, enabling realistic lip-sync animation during TTS playback.
  ///
  /// Parameters:
  /// - [audioPath]: Path to the audio file being played
  /// - [amplitudes]: List of amplitude values extracted from audio
  /// - [audioDuration]: Actual duration of the audio file
  /// - [onMouthStateUpdate]: Callback for each amplitude frame (mouth state 0-4)
  /// - [onComplete]: Callback when animation completes
  void startAmplitudeAnimation(
    String audioPath,
    List<int> amplitudes,
    Duration audioDuration, {
    required void Function(int mouthState) onMouthStateUpdate,
    required VoidCallback onComplete,
  }) {
    AppLogger.debug(
      'TtsPlaybackService: Starting amplitude animation with ${amplitudes.length} frames, duration: ${audioDuration.inMilliseconds}ms',
      tag: 'TtsPlaybackService',
    );

    // Cancel any existing animation
    _animationTimer?.cancel();

    if (amplitudes.isEmpty) {
      AppLogger.debug(
        'TtsPlaybackService: No amplitudes, completing immediately',
        tag: 'TtsPlaybackService',
      );
      onComplete();
      return;
    }

    // Notify that speaking has started
    notifySpeakingStarted();

    final int totalFrames = amplitudes.length;
    // Calculate update interval based on ACTUAL audio duration
    final int updateInterval = (audioDuration.inMilliseconds / totalFrames)
        .round()
        .clamp(5, 100);

    AppLogger.debug(
      'TtsPlaybackService: Animation timer: interval=${updateInterval}ms, frames=$totalFrames',
      tag: 'TtsPlaybackService',
    );

    int currentIndex = 0;
    _animationTimer = Timer.periodic(Duration(milliseconds: updateInterval), (
      Timer timer,
    ) {
      if (currentIndex >= totalFrames) {
        AppLogger.debug(
          'TtsPlaybackService: Animation completed after $currentIndex frames',
          tag: 'TtsPlaybackService',
        );
        timer.cancel();
        _animationTimer = null;
        onComplete();
        return;
      }

      // Map amplitude to mouth state and notify via callback
      final int mouthState = _getMouthState(amplitudes[currentIndex]);
      onMouthStateUpdate(mouthState);
      currentIndex++;
    });
  }

  /// Cancel any active animation without stopping playback.
  void cancelAnimation() {
    _animationTimer?.cancel();
    _animationTimer = null;
  }

  /// Map amplitude value to mouth state (0-4).
  ///
  /// Returns:
  /// - 0: closed (amplitude == 0)
  /// - 1: slightly open (amplitude <= 5)
  /// - 2: semi-open (amplitude <= 12)
  /// - 3: open (amplitude <= 18)
  /// - 4: wide open (amplitude > 18)
  int _getMouthState(int amplitude) {
    if (amplitude == 0) return 0;
    if (amplitude <= 5) return 1;
    if (amplitude <= 12) return 2;
    if (amplitude <= 18) return 3;
    return 4;
  }

  /// Dispose of the service and cancel any active timers.
  void dispose() {
    _animationTimer?.cancel();
    _animationTimer = null;
  }
}
