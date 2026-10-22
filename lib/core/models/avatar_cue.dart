import 'package:freezed_annotation/freezed_annotation.dart';

import 'avatar_gesture.dart';
import 'avatar_scene.dart';

part 'avatar_cue.freezed.dart';

/// An inline acting cue extracted from the LLM stream: `[g:<gesture>]` or
/// `[s:<sceneEvent>]`.
///
/// Cues travel with the TTS queue item of the sentence chunk they appeared
/// in, so they can fire in time with speech.
@freezed
sealed class AvatarCue with _$AvatarCue {
  const factory AvatarCue.gesture(AvatarGesture gesture) = AvatarCueGesture;

  const factory AvatarCue.sceneEvent(SceneEvent sceneEvent) =
      AvatarCueSceneEvent;
}
