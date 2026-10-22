import 'dart:async';

import '../../../../core/models/avatar_cue.dart';
import '../../../../core/models/avatar_gesture.dart';
import '../../../../core/models/avatar_scene.dart';
import '../../../../core/utils/logger.dart';
import '../../../talking/talking.dart';
import '../models/avatar_animation.dart';
import 'avatar_animation_service.dart';

/// Delivers avatar cues to the animation pipeline at the right moment.
///
/// Two sources feed the same guard:
/// - `CuesReachedEvent`s from TTS playback (cues fire the moment their
///   sentence's audio starts);
/// - the chat streaming channel used when TTS is disabled (cues fire as
///   soon as their sentence chunk finishes streaming).
///
/// Anti-spam guard: at most one gesture per chunk and a 1.5 s cooldown
/// between gestures. Scene events are never throttled.
class AvatarCueService {
  AvatarCueService({
    required TtsPlaybackService playbackService,
    required AvatarAnimationService animationService,
    required Stream<List<AvatarCue>> streamingCues,
    DateTime Function() now = DateTime.now,
  }) : _animationService = animationService,
       _now = now {
    _subscriptions.add(playbackService.events.listen(_onPlaybackEvent));
    _subscriptions.add(streamingCues.listen(_onCues));
  }

  static const Duration _gestureCooldown = Duration(milliseconds: 1500);

  final AvatarAnimationService _animationService;
  final DateTime Function() _now;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  DateTime? _lastGestureAt;

  void _onPlaybackEvent(PlaybackEvent event) {
    if (event is CuesReachedEvent) {
      _onCues(event.cues);
    }
  }

  void _onCues(List<AvatarCue> cues) {
    bool gestureFiredInChunk = false;
    for (final AvatarCue cue in cues) {
      cue.when(
        gesture: (AvatarGesture gesture) {
          if (gestureFiredInChunk) {
            AppLogger.debug(
              'Dropped gesture cue ${gesture.name}: one gesture per chunk',
              tag: 'AvatarCueService',
            );
            return;
          }
          if (!_gestureCooldownElapsed) {
            AppLogger.debug(
              'Dropped gesture cue ${gesture.name}: cooldown active',
              tag: 'AvatarCueService',
            );
            return;
          }
          gestureFiredInChunk = true;
          _lastGestureAt = _now();
          _animationService.trigger(AvatarAnimation.gesture(gesture));
        },
        sceneEvent: (SceneEvent sceneEvent) {
          _animationService.trigger(AvatarAnimation.sceneEvent(sceneEvent));
        },
      );
    }
  }

  bool get _gestureCooldownElapsed {
    final DateTime? last = _lastGestureAt;
    if (last == null) {
      return true;
    }
    return _now().difference(last) >= _gestureCooldown;
  }

  /// Cancels both subscriptions. The playback and animation services stay
  /// owned by the composition root.
  void dispose() {
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}
