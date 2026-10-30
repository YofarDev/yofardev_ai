import '../../../../core/models/avatar_scene.dart';
import '../models/journey.dart';

/// Picks the threshold of a scene journey (moonshot M7 ruling 5): anything
/// to deep space takes the rocket, leaving deep space takes a portal, the
/// living room and the outdoors connect by a door, campfire and beach by a
/// path.
abstract final class JourneyPlanner {
  static JourneyFamily familyFor(AvatarScene from, AvatarScene to) {
    if (to == AvatarScene.deepSpace) {
      return JourneyFamily.rocket;
    }
    if (from == AvatarScene.deepSpace) {
      return JourneyFamily.portal;
    }
    if (from == AvatarScene.livingRoom || to == AvatarScene.livingRoom) {
      return JourneyFamily.door;
    }
    return JourneyFamily.path;
  }
}
