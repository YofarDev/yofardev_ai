import '../../../../core/models/avatar_scene.dart';
import '../models/journey.dart';

/// Picks the threshold of a scene journey (moonshot M7 ruling 5, M9 ruling
/// 5, M11 ruling 6): anything to deep space takes the rocket, leaving deep
/// space takes a portal, the three open-air scenes (campfire, beach and
/// forestCabin) connect by a path, and every other pair takes the storybook
/// (opened on the floor of the living room, the cafe, the rooftop's
/// stairwell, the hut, the cabin's porch, the compartment or the library).
/// Over the ten scenes that is 9 rocket, 9 portal, 6 path and 66 book
/// journeys.
abstract final class JourneyPlanner {
  /// The scenes a path joins.
  static const Set<AvatarScene> openAir = <AvatarScene>{
    AvatarScene.campfire,
    AvatarScene.beach,
    AvatarScene.forestCabin,
  };

  static JourneyFamily familyFor(AvatarScene from, AvatarScene to) {
    if (to == AvatarScene.deepSpace) {
      return JourneyFamily.rocket;
    }
    if (from == AvatarScene.deepSpace) {
      return JourneyFamily.portal;
    }
    if (from != to && openAir.contains(from) && openAir.contains(to)) {
      return JourneyFamily.path;
    }
    return JourneyFamily.book;
  }
}
