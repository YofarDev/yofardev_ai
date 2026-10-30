import '../../../../core/models/avatar_gesture.dart';
import '../../../../core/models/avatar_mood.dart';
import '../../../../core/models/avatar_scene.dart';
import '../../../../core/models/sound_effects.dart';

/// A local reaction to a tap: at most a mood change, a gesture and a sound
/// effect. Taps never call the LLM and never touch chat history (design §2).
class PropReaction {
  const PropReaction({this.mood, this.gesture, this.soundEffect});

  final AvatarMood? mood;
  final AvatarGesture? gesture;
  final SoundEffects? soundEffect;
}

/// Mapping table from every contract `propId` (per scene) and avatar tap
/// zone to its local reaction.
class PropReactionService {
  PropReaction? reactionForProp(AvatarScene scene, String propId) {
    return _propReactions['${scene.name}/$propId'];
  }

  PropReaction? reactionForZone(String zone) => _zoneReactions[zone];

  /// Keyed by `<sceneId>/<propId>` — the same ids as in `CONTRACT.md`.
  static const Map<String, PropReaction> _propReactions =
      <String, PropReaction>{
        // livingRoom
        'livingRoom/lamp': PropReaction(soundEffect: SoundEffects.whoosh),
        'livingRoom/tv': PropReaction(
          gesture: AvatarGesture.laugh,
          soundEffect: SoundEffects.crowdLaughing,
        ),
        'livingRoom/cat': PropReaction(
          mood: AvatarMood.happy,
          soundEffect: SoundEffects.uwu,
        ),
        'livingRoom/plant': PropReaction(
          mood: AvatarMood.happy,
          soundEffect: SoundEffects.magicWand,
        ),
        // campfire
        'campfire/fire': PropReaction(
          mood: AvatarMood.happy,
          gesture: AvatarGesture.clap,
        ),
        'campfire/tent': PropReaction(gesture: AvatarGesture.shrug),
        'campfire/owl': PropReaction(
          gesture: AvatarGesture.think,
          soundEffect: SoundEffects.spookyTheme,
        ),
        'campfire/sky': PropReaction(mood: AvatarMood.sad),
        // beach
        'beach/crab': PropReaction(
          gesture: AvatarGesture.shrug,
          soundEffect: SoundEffects.uwu,
        ),
        'beach/umbrella': PropReaction(
          mood: AvatarMood.happy,
          soundEffect: SoundEffects.frenchTheme,
        ),
        'beach/seagull': PropReaction(
          gesture: AvatarGesture.nod,
          soundEffect: SoundEffects.crowdLaughing,
        ),
        // deepSpace
        'deepSpace/planet': PropReaction(gesture: AvatarGesture.think),
        'deepSpace/ufo': PropReaction(
          mood: AvatarMood.surprised,
          soundEffect: SoundEffects.magicWand,
        ),
        'deepSpace/rubberDuck': PropReaction(
          gesture: AvatarGesture.laugh,
          soundEffect: SoundEffects.uwu,
        ),
        // cafe
        'cafe/cup': PropReaction(mood: AvatarMood.happy),
        'cafe/espresso': PropReaction(
          mood: AvatarMood.happy,
          gesture: AvatarGesture.thumbsUp,
        ),
        'cafe/window': PropReaction(gesture: AvatarGesture.think),
        'cafe/fish': PropReaction(
          mood: AvatarMood.happy,
          soundEffect: SoundEffects.uwu,
        ),
        // rooftop
        'rooftop/telescope': PropReaction(gesture: AvatarGesture.think),
        'rooftop/antenna': PropReaction(gesture: AvatarGesture.shrug),
        'rooftop/pigeon': PropReaction(
          gesture: AvatarGesture.nod,
          soundEffect: SoundEffects.uwu,
        ),
        'rooftop/moon': PropReaction(
          mood: AvatarMood.happy,
          gesture: AvatarGesture.think,
        ),
        // mountainHut
        'mountainHut/stove': PropReaction(
          mood: AvatarMood.happy,
          gesture: AvatarGesture.thumbsUp,
        ),
        'mountainHut/window': PropReaction(gesture: AvatarGesture.think),
        'mountainHut/dog': PropReaction(
          mood: AvatarMood.happy,
          soundEffect: SoundEffects.uwu,
        ),
        'mountainHut/bell': PropReaction(
          mood: AvatarMood.happy,
          soundEffect: SoundEffects.christmasBells,
        ),
      };

  static const Map<String, PropReaction>
  _zoneReactions = <String, PropReaction>{
    // A pat on the head is welcome; a poke in the body gets a shrug.
    'head': PropReaction(mood: AvatarMood.happy, soundEffect: SoundEffects.uwu),
    'body': PropReaction(
      gesture: AvatarGesture.shrug,
      soundEffect: SoundEffects.whoosh,
    ),
  };
}
