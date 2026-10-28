import 'dart:async';

import '../../../../core/models/avatar_cue.dart';
import '../../../../core/utils/logger.dart';
import '../repositories/talking_repository.dart';
import 'playback_clock.dart';

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

/// Emitted the moment a TTS queue item's audio starts playing (or
/// immediately, for items that carry only cues and no speakable text).
class CuesReachedEvent extends PlaybackEvent {
  const CuesReachedEvent(this.cues);
  final List<AvatarCue> cues;
}

/// Emitted right after [SpeakingStartedEvent] with the text of the sentence
/// that just started playing (live captions).
class CaptionEvent extends PlaybackEvent {
  const CaptionEvent(this.text);
  final String text;
}

/// Drives the avatar mouth animation from a playback clock instead of an
/// open-loop timer index: every tick derives the frame index from the clock's
/// position, so a stalled UI isolate jumps straight to the real frame.
class TtsPlaybackService {
  TtsPlaybackService(this._repository, {PlaybackClock? clock, Duration? tick})
    : _clock = clock,
      tick = tick ?? defaultTick;

  final TalkingRepository _repository;

  /// Closed-loop clock anchored to the player position; null on platforms
  /// without a position source (tests, web), where a pure stopwatch drives
  /// the frames.
  final PlaybackClock? _clock;

  /// Interval between animation ticks.
  final Duration tick;

  static const Duration defaultTick = Duration(milliseconds: 16);

  static const Duration _defaultFrameDuration = Duration(milliseconds: 25);

  Timer? _animationTimer;
  Stopwatch? _fallbackStopwatch;
  bool _animationCompleted = false;

  final StreamController<PlaybackEvent> _controller =
      StreamController<PlaybackEvent>.broadcast();

  Stream<PlaybackEvent> get events => _controller.stream;

  /// Fires cues for a queue item that has no speakable text: there is no
  /// audio to start, so they are delivered as soon as the item is reached.
  void fireCues(List<AvatarCue> cues) {
    if (cues.isEmpty) {
      return;
    }
    _controller.add(CuesReachedEvent(cues));
  }

  Future<void> stop() async {
    _cancelAnimation();
    await _repository.stop();
    _controller.add(const SpeakingStoppedEvent());
  }

  void startAmplitudeAnimation(
    String audioPath,
    List<int> amplitudes,
    Duration audioDuration, {
    List<AvatarCue> cues = const <AvatarCue>[],
    String? caption,
  }) {
    AppLogger.debug(
      'TtsPlaybackService: Starting amplitude animation with ${amplitudes.length} frames, duration: ${audioDuration.inMilliseconds}ms',
      tag: 'TtsPlaybackService',
    );

    _cancelAnimation();
    _animationCompleted = false;

    if (amplitudes.isEmpty) {
      AppLogger.debug(
        'TtsPlaybackService: No amplitudes, completing immediately',
        tag: 'TtsPlaybackService',
      );
      _controller.add(const AnimationCompletedEvent());
      return;
    }

    _controller.add(const SpeakingStartedEvent());
    // Only a sentence that actually starts speaking gets a caption.
    if (caption != null && caption.trim().isNotEmpty) {
      _controller.add(CaptionEvent(caption));
    }
    // The audio starts now: cues embedded in this sentence fire in time
    // with speech.
    if (cues.isNotEmpty) {
      _controller.add(CuesReachedEvent(cues));
    }

    final int totalFrames = amplitudes.length;
    final Duration frameDuration = audioDuration > Duration.zero
        ? Duration(microseconds: audioDuration.inMicroseconds ~/ totalFrames)
        : _defaultFrameDuration;

    final PlaybackClock? clock = _clock;
    if (clock != null) {
      clock.start();
    } else {
      _fallbackStopwatch = Stopwatch()..start();
    }

    AppLogger.debug(
      'TtsPlaybackService: Animation clock: frame=${frameDuration.inMilliseconds}ms, frames=$totalFrames',
      tag: 'TtsPlaybackService',
    );

    int lastMouthState = -1;
    _animationTimer = Timer.periodic(tick, (Timer timer) {
      final Stopwatch? fallback = _fallbackStopwatch;
      final Duration position =
          clock?.position ?? fallback?.elapsed ?? Duration.zero;
      final int frameIndex =
          position.inMicroseconds ~/ frameDuration.inMicroseconds;

      if (frameIndex >= totalFrames) {
        _completeAnimation(timer);
        return;
      }

      final int mouthState = _getMouthState(amplitudes[frameIndex]);
      if (mouthState != lastMouthState) {
        lastMouthState = mouthState;
        _controller.add(MouthStateUpdatedEvent(mouthState));
      }
    });
  }

  void cancelAnimation() {
    _cancelAnimation();
  }

  void _completeAnimation(Timer timer) {
    timer.cancel();
    _animationTimer = null;
    _fallbackStopwatch?.stop();
    _fallbackStopwatch = null;
    _clock?.stop();
    if (_animationCompleted) {
      return;
    }
    _animationCompleted = true;
    AppLogger.debug(
      'TtsPlaybackService: Animation completed',
      tag: 'TtsPlaybackService',
    );
    _controller.add(const AnimationCompletedEvent());
  }

  void _cancelAnimation() {
    _animationTimer?.cancel();
    _animationTimer = null;
    _fallbackStopwatch?.stop();
    _fallbackStopwatch = null;
    _clock?.stop();
  }

  int _getMouthState(int amplitude) {
    if (amplitude == 0) return 0;
    if (amplitude <= 5) return 1;
    if (amplitude <= 12) return 2;
    if (amplitude <= 18) return 3;
    return 4;
  }

  void dispose() {
    _cancelAnimation();
    _controller.close();
  }
}
