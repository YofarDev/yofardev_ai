import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/models/performance/performance.dart';
import '../../../talking/talking.dart';
import '../models/avatar_animation.dart';
import '../models/performance_intent.dart';
import 'npc_director.dart';

/// Feeds the [NpcDirector] from the streams the avatar already lives on (M8
/// ruling 9), like `CameraFeed` for the camera:
///
/// - the performance director's intents: the emotion and speaking;
/// - TTS playback: every `CaptionEvent` is a reply sentence (names, the
///   owl's questions);
/// - the user's messages (names);
/// - the animation service: scene events (the lamp, the walking cat);
/// - the world's [rain] and the quality tier.
///
/// The scene, the talking phase, reduce motion and the pokes come from the
/// Home stage. The director stays owned by the composition root.
class NpcFeed {
  NpcFeed({
    required NpcDirector npc,
    required Stream<PerformanceIntent> intents,
    required Stream<PlaybackEvent> playback,
    required Stream<AvatarAnimation> animations,
    Stream<String>? userMessages,
    ValueListenable<double>? rain,
    QualityTier tier = QualityTier.high,
    Stream<QualityTier>? tierChanges,
  }) : _npc = npc,
       _rain = rain {
    npc.setTier(tier);
    _subscriptions
      ..add(intents.listen(_onIntent))
      ..add(playback.listen(_onPlayback))
      ..add(animations.listen(_onAnimation));
    if (userMessages != null) {
      _subscriptions.add(userMessages.listen(npc.onUserText));
    }
    if (tierChanges != null) {
      _subscriptions.add(tierChanges.listen(npc.setTier));
    }
    rain?.addListener(_onRain);
    _onRain();
  }

  final NpcDirector _npc;
  final ValueListenable<double>? _rain;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  void _onIntent(PerformanceIntent intent) {
    _npc
      ..setEmotion(intent.emotion)
      ..setSpeaking(intent.speaking);
  }

  void _onPlayback(PlaybackEvent event) {
    if (event is CaptionEvent) {
      _npc.onReplySentence(event.text);
    }
  }

  void _onAnimation(AvatarAnimation animation) {
    if (animation is AvatarAnimationSceneEvent) {
      _npc.onSceneEvent(animation.sceneEvent);
    }
  }

  void _onRain() {
    final ValueListenable<double>? rain = _rain;
    if (rain != null) {
      _npc.setRain(rain.value);
    }
  }

  /// Cancels the subscriptions. The director stays owned by the composition
  /// root.
  void dispose() {
    _rain?.removeListener(_onRain);
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}
