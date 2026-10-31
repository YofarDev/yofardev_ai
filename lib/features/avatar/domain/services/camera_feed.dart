import 'dart:async';
import 'dart:math' as math;

import '../../../../core/models/performance/performance.dart';
import '../../../talking/talking.dart';
import '../models/avatar_animation.dart';
import '../models/performance_intent.dart';
import 'camera_director.dart';

/// Feeds the [CameraDirector] from the streams the avatar already lives on
/// (moonshot M7 task 3), so no cubit and no widget reports to it:
///
/// - TTS playback: `SpeakingStartedEvent` starts speaking; an interrupted
///   `SpeakingStoppedEvent` stops it at once; the end of a sentence
///   (`AnimationCompletedEvent`, a plain `SpeakingStoppedEvent`) stops it
///   only after [replyGap] without another sentence, so a reply of several sentences stays one reply for the
///   director's sentence count; `CaptionEvent` is a sentence start, with the
///   [emotion]'s intensity, `max(|valence|, arousal) x intensity`;
/// - the performance director's intents: the prop, and the listening lean
///   (the user typing) as composing;
/// - the animation service: scene events pull the camera back;
/// - the quality tier (M11: low has no slow push-in).
///
/// The talking phase and reduce motion come from the widget layer (see
/// `HomeContentStack`). The camera director stays owned by the composition
/// root.
class CameraFeed {
  CameraFeed({
    required CameraDirector camera,
    required Stream<PlaybackEvent> playback,
    required Stream<PerformanceIntent> intents,
    required Stream<AvatarAnimation> animations,
    required EmotionVector Function() emotion,
    QualityTier tier = QualityTier.ultra,
    Stream<QualityTier>? tierChanges,
  }) : _camera = camera,
       _emotion = emotion {
    camera.setTier(tier);
    if (tierChanges != null) {
      _subscriptions.add(tierChanges.listen(camera.setTier));
    }
    _subscriptions
      ..add(playback.listen(_onPlayback))
      ..add(intents.listen(_onIntent))
      ..add(animations.listen(_onAnimation));
  }

  /// How long after a sentence ends the reply still counts as going on.
  static const Duration replyGap = Duration(milliseconds: 1500);

  final CameraDirector _camera;
  final EmotionVector Function() _emotion;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  Timer? _replyEnd;
  AvatarProp _prop = AvatarProp.none;
  bool _composing = false;

  void _onPlayback(PlaybackEvent event) {
    switch (event) {
      case SpeakingStartedEvent():
        _replyEnd?.cancel();
        _replyEnd = null;
        _camera.setSpeaking(true);
      case SpeakingStoppedEvent(:final bool interrupted) when interrupted:
        _replyEnd?.cancel();
        _replyEnd = null;
        _camera.setSpeaking(false);
      case SpeakingStoppedEvent() || AnimationCompletedEvent():
        // A sentence ended: the reply may go on.
        _replyEnd?.cancel();
        _replyEnd = Timer(replyGap, () {
          _replyEnd = null;
          _camera.setSpeaking(false);
        });
      case CaptionEvent(:final String text):
        final EmotionVector emotion = _emotion();
        final double intensity = math
            .max(emotion.valence.abs(), emotion.arousal)
            .clamp(0.0, 1.0);
        _camera.onSentence(text, intensity: intensity * emotion.intensity);
      case CuesReachedEvent() ||
          MouthStateUpdatedEvent() ||
          SpeechTimelineEvent() ||
          SpeechPrerollEvent():
        break;
    }
  }

  void _onIntent(PerformanceIntent intent) {
    if (intent.prop != _prop) {
      _prop = intent.prop;
      _camera.setProp(_prop);
    }
    final bool composing = intent.lean > 0;
    if (composing != _composing) {
      _composing = composing;
      _camera.setComposing(composing);
    }
  }

  void _onAnimation(AvatarAnimation animation) {
    if (animation is AvatarAnimationSceneEvent) {
      _camera.onSceneEvent();
    }
  }

  /// Cancels the subscriptions and the pending reply end. The camera director
  /// stays owned by the composition root.
  void dispose() {
    _replyEnd?.cancel();
    _replyEnd = null;
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}
