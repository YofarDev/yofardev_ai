import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/domain/models/journey.dart';
import 'package:yofardev_ai/features/avatar/domain/services/journey_planner.dart';

void main() {
  test('all 42 directed journeys of the seven scenes (M9 ruling 5)', () {
    JourneyFamily expected(AvatarScene from, AvatarScene to) {
      if (to == AvatarScene.deepSpace) {
        return JourneyFamily.rocket;
      }
      if (from == AvatarScene.deepSpace) {
        return JourneyFamily.portal;
      }
      const Set<AvatarScene> outdoors = <AvatarScene>{
        AvatarScene.campfire,
        AvatarScene.beach,
      };
      if (outdoors.contains(from) && outdoors.contains(to)) {
        return JourneyFamily.path;
      }
      return JourneyFamily.door;
    }

    // The table, written out by hand: row = from, column = to, in
    // AvatarScene order.
    const JourneyFamily d = JourneyFamily.door;
    const JourneyFamily r = JourneyFamily.rocket;
    const JourneyFamily p = JourneyFamily.portal;
    const JourneyFamily w = JourneyFamily.path;
    const Map<AvatarScene, List<JourneyFamily?>> table =
        <AvatarScene, List<JourneyFamily?>>{
          //                       lr    cf    be    ds    cafe  roof  hut
          AvatarScene.livingRoom: <JourneyFamily?>[null, d, d, r, d, d, d],
          AvatarScene.campfire: <JourneyFamily?>[d, null, w, r, d, d, d],
          AvatarScene.beach: <JourneyFamily?>[d, w, null, r, d, d, d],
          AvatarScene.deepSpace: <JourneyFamily?>[p, p, p, null, p, p, p],
          AvatarScene.cafe: <JourneyFamily?>[d, d, d, r, null, d, d],
          AvatarScene.rooftop: <JourneyFamily?>[d, d, d, r, d, null, d],
          AvatarScene.mountainHut: <JourneyFamily?>[d, d, d, r, d, d, null],
        };
    int pairs = 0;
    final Map<JourneyFamily, int> counts = <JourneyFamily, int>{};
    for (final AvatarScene from in AvatarScene.values) {
      for (final AvatarScene to in AvatarScene.values) {
        if (from == to) {
          continue;
        }
        pairs++;
        final JourneyFamily family = JourneyPlanner.familyFor(from, to);
        expect(
          family,
          table[from]![to.index],
          reason: '${from.name} -> ${to.name}',
        );
        expect(
          family,
          expected(from, to),
          reason: '${from.name} -> ${to.name}',
        );
        counts[family] = (counts[family] ?? 0) + 1;
      }
    }
    expect(pairs, 42);
    expect(counts, <JourneyFamily, int>{
      JourneyFamily.rocket: 6,
      JourneyFamily.portal: 6,
      JourneyFamily.path: 2,
      JourneyFamily.door: 28,
    });
  });

  test('the scene is the origin until the cut, the destination after', () {
    const JourneyState s = JourneyState(
      from: AvatarScene.livingRoom,
      to: AvatarScene.beach,
      family: JourneyFamily.door,
      phase: JourneyPhase.close,
      serial: 3,
    );
    expect(s.sceneNow, AvatarScene.livingRoom);
    expect(s.next(JourneyPhase.cut).sceneNow, AvatarScene.beach);
    expect(s.next(JourneyPhase.cut).serial, 4);
  });
}
