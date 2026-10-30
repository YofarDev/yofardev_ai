import 'dart:async';

import '../../../../core/models/avatar_cue.dart';
import '../../../../core/models/performance/speech_timeline.dart';
import '../../../../core/models/performance/viseme.dart';
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
  const SpeakingStoppedEvent({this.interrupted = false});

  /// True when the user cut the speech off ([TtsPlaybackService.interrupt]);
  /// false when a sentence simply ended.
  final bool interrupted;
}

class MouthStateUpdatedEvent extends PlaybackEvent {
  const MouthStateUpdatedEvent(this.mouthState);
  final int mouthState;
}

class AnimationCompletedEvent extends PlaybackEvent {
  const AnimationCompletedEvent();
}

/// Emitted [lead] before a sentence's audio starts: the avatar draws its
/// breath in that time, lips parted unless the sentence opens on a lip
/// closure ([onset], the first sounding viseme, when the analysis is
/// already known).
class SpeechPrerollEvent extends PlaybackEvent {
  const SpeechPrerollEvent(this.lead, {this.onset});
  final Duration lead;
  final Viseme? onset;
}

/// Emitted right after [SpeakingStartedEvent] (before the sentence's cues
/// and caption) with what the face performs for this sentence: the analysed
/// viseme spans and prosody marks, or a timeline synthesised from the
/// amplitudes when no analysis is available. Times are relative to the start
/// of the audio ([TtsPlaybackService.speechPosition]).
///
/// A sentence whose analysis landed after its audio started gets a second
/// event with [replacesCurrent] true ([TtsPlaybackService.replaceTimeline]):
/// the same sentence, the analysed timeline, same time base. A consumer that
/// treats a timeline event as the start of a sentence must ignore it.
class SpeechTimelineEvent extends PlaybackEvent {
  const SpeechTimelineEvent(this.timeline, {this.replacesCurrent = false});
  final SpeechTimeline timeline;

  /// True when this swaps the timeline of the sentence already playing (its
  /// analysis arrived late) instead of starting a sentence.
  final bool replacesCurrent;
}

/// Emitted the moment a TTS queue item's audio starts playing (or
/// immediately, for items that carry only cues and no speakable text).
class CuesReachedEvent extends PlaybackEvent {
  const CuesReachedEvent(this.cues);
  final List<AvatarCue> cues;
}

/// Emitted after [SpeakingStartedEvent] (and after the sentence's
/// [CuesReachedEvent], if any) with the text of the sentence that just
/// started playing (live captions).
class CaptionEvent extends PlaybackEvent {
  const CaptionEvent(this.text);
  final String text;
}

/// Drives the avatar mouth animation from a playback clock instead of an
/// open-loop timer index: every tick derives the frame index from the clock's
/// position, so a stalled UI isolate jumps straight to the real frame.
class TtsPlaybackService {
  TtsPlaybackService(
    this._repository, {
    PlaybackClock? clock,
    Duration? tick,
    Stopwatch Function()? stopwatchFactory,
  }) : _clock = clock,
       tick = tick ?? defaultTick,
       _stopwatchFactory = stopwatchFactory ?? Stopwatch.new;

  final TalkingRepository _repository;

  /// Closed-loop clock anchored to the player position; null on platforms
  /// without a position source (tests, web), where a pure stopwatch drives
  /// the frames.
  final PlaybackClock? _clock;

  /// Builds the fallback stopwatch used when there is no [_clock].
  final Stopwatch Function() _stopwatchFactory;

  /// Interval between animation ticks.
  final Duration tick;

  static const Duration defaultTick = Duration(milliseconds: 16);

  static const Duration _defaultFrameDuration = Duration(milliseconds: 25);

  Timer? _animationTimer;

  /// The audio file of the sentence whose animation runs (null: none).
  String? _playingAudioPath;
  Stopwatch? _fallbackStopwatch;
  bool _animationCompleted = false;

  final StreamController<PlaybackEvent> _controller =
      StreamController<PlaybackEvent>.broadcast();

  Stream<PlaybackEvent> get events => _controller.stream;

  /// Position in the sentence now playing (the playback clock, or the
  /// fallback stopwatch), the time base of its [SpeechTimelineEvent]; null
  /// when no animation runs (before start, after stop or completion).
  Duration? get speechPosition {
    if (_animationTimer == null) {
      return null;
    }
    return _clock?.position ?? _fallbackStopwatch?.elapsed;
  }

  /// Fires cues for a queue item that has no speakable text: there is no
  /// audio to start, so they are delivered as soon as the item is reached.
  void fireCues(List<AvatarCue> cues) {
    if (cues.isEmpty) {
      return;
    }
    _controller.add(CuesReachedEvent(cues));
  }

  /// Announces that a sentence starts playing in [lead]; [onset] is its
  /// first sounding viseme when known.
  void announceSpeech(Duration lead, {Viseme? onset}) {
    _controller.add(SpeechPrerollEvent(lead, onset: onset));
  }

  /// Ends the current sentence (it finished playing).
  Future<void> stop() async {
    _cancelAnimation();
    await _repository.stop();
    _controller.add(const SpeakingStoppedEvent());
  }

  /// Cuts the speech off: like [stop], but listeners learn it was an
  /// interruption (the face drops its end-of-sentence acting at once).
  Future<void> interrupt() async {
    _cancelAnimation();
    _controller.add(const SpeakingStoppedEvent(interrupted: true));
    await _repository.stop();
  }

  /// Swaps the timeline of the sentence now playing for [timeline], its late
  /// speech analysis (times relative to the audio start, like the first
  /// one). Does nothing unless [audioPath] is still the sentence that plays:
  /// a sentence that ended, was interrupted or was followed by another gets
  /// nothing. Returns whether the event went out.
  bool replaceTimeline(String audioPath, SpeechTimeline timeline) {
    if (_animationTimer == null || _playingAudioPath != audioPath) {
      return false;
    }
    _controller.add(SpeechTimelineEvent(timeline, replacesCurrent: true));
    return true;
  }

  void startAmplitudeAnimation(
    String audioPath,
    List<int> amplitudes,
    Duration audioDuration, {
    List<AvatarCue> cues = const <AvatarCue>[],
    String? caption,
    SpeechTimeline? timeline,
  }) {
    AppLogger.debug(
      'TtsPlaybackService: Starting amplitude animation with ${amplitudes.length} frames, duration: ${audioDuration.inMilliseconds}ms',
      tag: 'TtsPlaybackService',
    );

    _cancelAnimation();
    _animationCompleted = false;
    _playingAudioPath = audioPath;

    if (amplitudes.isEmpty) {
      AppLogger.debug(
        'TtsPlaybackService: No amplitudes, completing immediately',
        tag: 'TtsPlaybackService',
      );
      _controller.add(const AnimationCompletedEvent());
      return;
    }

    _controller.add(const SpeakingStartedEvent());
    _controller.add(
      SpeechTimelineEvent(
        timeline ??
            _amplitudeTimeline(amplitudes, audioDuration, caption: caption),
      ),
    );
    // The audio starts now: cues embedded in this sentence fire in time with
    // speech. They go out before the caption so an LLM gesture always reaches
    // the director ahead of the auto-acting rules that read the caption.
    if (cues.isNotEmpty) {
      _controller.add(CuesReachedEvent(cues));
    }
    // Only a sentence that actually starts speaking gets a caption.
    if (caption != null && caption.trim().isNotEmpty) {
      _controller.add(CaptionEvent(caption));
    }

    final int totalFrames = amplitudes.length;
    final Duration frameDuration = audioDuration > Duration.zero
        ? Duration(microseconds: audioDuration.inMicroseconds ~/ totalFrames)
        : _defaultFrameDuration;

    final PlaybackClock? clock = _clock;
    if (clock != null) {
      clock.start();
    } else {
      _fallbackStopwatch = _stopwatchFactory()
        ..reset()
        ..start();
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
    _playingAudioPath = null;
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
    _playingAudioPath = null;
    _fallbackStopwatch?.stop();
    _fallbackStopwatch = null;
    _clock?.stop();
  }

  /// Fallback timeline from the 25 ms amplitudes, stretched to the real
  /// audio duration.
  static SpeechTimeline _amplitudeTimeline(
    List<int> amplitudes,
    Duration audioDuration, {
    String? caption,
  }) {
    final Duration frame = audioDuration > Duration.zero
        ? Duration(
            microseconds: audioDuration.inMicroseconds ~/ amplitudes.length,
          )
        : _defaultFrameDuration;
    final SpeechTimeline timeline = SpeechTimeline.fromAmplitudes(
      amplitudes,
      frame,
      text: caption,
    );
    if (audioDuration <= Duration.zero || timeline.visemes.isEmpty) {
      return timeline;
    }
    // Integer frame division can leave the last span a few microseconds
    // short of the audio: the last span ends with the audio.
    final List<VisemeSpan> visemes = List<VisemeSpan>.of(timeline.visemes);
    visemes[visemes.length - 1] = visemes.last.copyWith(end: audioDuration);
    return timeline.copyWith(visemes: visemes, duration: audioDuration);
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
