import 'dart:async';

import '../../../../core/models/avatar_cue.dart';
import '../../../../core/models/avatar_gesture.dart';
import '../../../../core/models/avatar_mood.dart';
import '../../../../core/models/avatar_scene.dart';
import '../../../../core/utils/logger.dart';
import '../../../talking/talking.dart';
import '../models/avatar_animation.dart';
import '../models/performance_intent.dart';
import 'avatar_animation_service.dart';
import 'performance_director.dart';

/// Delivers avatar cues to the animation pipeline at the right moment.
///
/// Two sources feed the same guard:
/// - `CuesReachedEvent`s from TTS playback (cues fire the moment their
///   sentence's audio starts);
/// - the chat streaming channel used when TTS is disabled (cues fire as
///   soon as their sentence chunk finishes streaming).
///
/// Gesture cues are forwarded to the [PerformanceDirector] (source: llm),
/// which owns arbitration: one gesture at a time, a bounded queue and the
/// cooldown. Scene events are never throttled. The animation is triggered
/// from the director's `pendingGesture` changes.
class AvatarCueService {
  AvatarCueService({
    required TtsPlaybackService playbackService,
    required AvatarAnimationService animationService,
    required Stream<List<AvatarCue>> streamingCues,
    required PerformanceDirector director,
    Stream<AvatarMood> moods = const Stream<AvatarMood>.empty(),
    Stream<String?> toolActivity = const Stream<String?>.empty(),
  }) : _animationService = animationService,
       _director = director {
    _subscriptions.add(playbackService.events.listen(_onPlaybackEvent));
    _subscriptions.add(streamingCues.listen(_onCues));
    _subscriptions.add(director.intents.listen(_onIntent));
    _subscriptions.add(moods.listen(director.setMood));
    _subscriptions.add(toolActivity.listen(director.setActiveTool));
  }

  final AvatarAnimationService _animationService;
  final PerformanceDirector _director;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  int _lastFiredSerial = 0;

  /// True when the sentence now playing carries an LLM gesture cue: the LLM
  /// outranks the auto-acting rules, so they skip that sentence.
  bool _sentenceHasGestureCue = false;

  void _onPlaybackEvent(PlaybackEvent event) {
    switch (event) {
      case CuesReachedEvent(:final List<AvatarCue> cues):
        _sentenceHasGestureCue = cues.any(
          (AvatarCue cue) => cue is AvatarCueGesture,
        );
        _onCues(cues);
      case SpeakingStartedEvent():
        _sentenceHasGestureCue = false;
        _director.setSpeaking(true);
      case SpeakingStoppedEvent() || AnimationCompletedEvent():
        _director.setSpeaking(false);
      case CaptionEvent(:final String text):
        // Auto-acting rules read each sentence as it starts playing, unless
        // the LLM already chose a gesture for it.
        if (!_sentenceHasGestureCue) {
          _director.onSentence(text);
        }
        _sentenceHasGestureCue = false;
      case MouthStateUpdatedEvent():
        break;
    }
  }

  void _onCues(List<AvatarCue> cues) {
    for (final AvatarCue cue in cues) {
      cue.when(
        gesture: (AvatarGesture gesture) {
          _director.requestGesture(gesture, source: GestureSource.llm);
        },
        sceneEvent: (SceneEvent sceneEvent) {
          _animationService.trigger(AvatarAnimation.sceneEvent(sceneEvent));
        },
      );
    }
  }

  /// Triggers the animation whenever the director starts a new gesture
  /// (the serial distinguishes a repeat of the same gesture).
  void _onIntent(PerformanceIntent intent) {
    if (intent.pendingGesture == null ||
        intent.gestureSerial <= _lastFiredSerial) {
      return;
    }
    _lastFiredSerial = intent.gestureSerial;
    _animationService.trigger(AvatarAnimation.gesture(intent.pendingGesture!));
    AppLogger.debug(
      'AvatarCueService: fired gesture ${intent.pendingGesture!.name} (serial $_lastFiredSerial)',
      tag: 'AvatarCueService',
    );
  }

  /// Cancels the subscriptions. The playback, animation and director
  /// services stay owned by the composition root.
  void dispose() {
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}
