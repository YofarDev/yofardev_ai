import '../../../../core/models/avatar_scene.dart';
import '../models/journey.dart';

/// Picks the threshold of a scene journey (moonshot M7 ruling 5, M9 ruling
/// 5): anything to deep space takes the rocket, leaving deep space takes a
/// portal, campfire and beach connect by a path, and every other pair takes
/// the storybook door (of the living room, the cafe, the rooftop's stairwell
/// or the hut). Over the seven scenes that is 6 rocket, 6 portal, 2 path and
/// 28 door journeys.
abstract final class JourneyPlanner {
  static JourneyFamily familyFor(AvatarScene from, AvatarScene to) {
    if (to == AvatarScene.deepSpace) {
      return JourneyFamily.rocket;
    }
    if (from == AvatarScene.deepSpace) {
      return JourneyFamily.portal;
    }
    final bool campfireBeach =
        (from == AvatarScene.campfire && to == AvatarScene.beach) ||
        (from == AvatarScene.beach && to == AvatarScene.campfire);
    if (campfireBeach) {
      return JourneyFamily.path;
    }
    return JourneyFamily.door;
  }
}
