import 'dart:async';

import '../../../../core/utils/logger.dart';
import '../repositories/talking_repository.dart';

sealed class PlaybackEvent {
  const PlaybackEvent();
}

class SpeakingStartedEvent extends PlaybackEvent {
  const SpeakingStartedEvent();
}

class SpeakingStoppedEvent extends PlaybackEvent {
  const SpeakingStoppedEvent();
}

class MouthStateUpdatedEvent extends PlaybackEvent {
  const MouthStateUpdatedEvent(this.mouthState);
  final int mouthState;
}

class AnimationCompletedEvent extends PlaybackEvent {
  const AnimationCompletedEvent();
}

class TtsPlaybackService {
  TtsPlaybackService(this._repository);

  final TalkingRepository _repository;
  Timer? _animationTimer;

  final StreamController<PlaybackEvent> _controller =
      StreamController<PlaybackEvent>.broadcast();

  Stream<PlaybackEvent> get events => _controller.stream;

  Future<void> stop() async {
    _animationTimer?.cancel();
    _animationTimer = null;
    await _repository.stop();
    _controller.add(const SpeakingStoppedEvent());
  }

  void startAmplitudeAnimation(
    String audioPath,
    List<int> amplitudes,
    Duration audioDuration,
  ) {
    AppLogger.debug(
      'TtsPlaybackService: Starting amplitude animation with ${amplitudes.length} frames, duration: ${audioDuration.inMilliseconds}ms',
      tag: 'TtsPlaybackService',
    );

    _animationTimer?.cancel();

    if (amplitudes.isEmpty) {
      AppLogger.debug(
        'TtsPlaybackService: No amplitudes, completing immediately',
        tag: 'TtsPlaybackService',
      );
      _controller.add(const AnimationCompletedEvent());
      return;
    }

    _controller.add(const SpeakingStartedEvent());

    final int totalFrames = amplitudes.length;
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
        _controller.add(const AnimationCompletedEvent());
        return;
      }

      final int mouthState = _getMouthState(amplitudes[currentIndex]);
      _controller.add(MouthStateUpdatedEvent(mouthState));
      currentIndex++;
    });
  }

  void cancelAnimation() {
    _animationTimer?.cancel();
    _animationTimer = null;
  }

  int _getMouthState(int amplitude) {
    if (amplitude == 0) return 0;
    if (amplitude <= 5) return 1;
    if (amplitude <= 12) return 2;
    if (amplitude <= 18) return 3;
    return 4;
  }

  void dispose() {
    _animationTimer?.cancel();
    _animationTimer = null;
    _controller.close();
  }
}
