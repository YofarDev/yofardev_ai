import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/domain/models/journey.dart';
import 'package:yofardev_ai/features/avatar/domain/services/journey_planner.dart';

void main() {
  test('all 90 directed journeys of the ten scenes (M11 ruling 6)', () {
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
        AvatarScene.forestCabin,
      };
      if (outdoors.contains(from) && outdoors.contains(to)) {
        return JourneyFamily.path;
      }
      return JourneyFamily.book;
    }

    // The table, written out by hand: row = from, column = to, in
    // AvatarScene order.
    const JourneyFamily d = JourneyFamily.book;
    const JourneyFamily r = JourneyFamily.rocket;
    const JourneyFamily p = JourneyFamily.portal;
    const JourneyFamily w = JourneyFamily.path;
    const JourneyFamily? o = null;
    const Map<AvatarScene, List<JourneyFamily?>>
    table = <AvatarScene, List<JourneyFamily?>>{
      //                 lr cf be ds ca rt mh fc tc li
      AvatarScene.livingRoom: <JourneyFamily?>[o, d, d, r, d, d, d, d, d, d],
      AvatarScene.campfire: <JourneyFamily?>[d, o, w, r, d, d, d, w, d, d],
      AvatarScene.beach: <JourneyFamily?>[d, w, o, r, d, d, d, w, d, d],
      AvatarScene.deepSpace: <JourneyFamily?>[p, p, p, o, p, p, p, p, p, p],
      AvatarScene.cafe: <JourneyFamily?>[d, d, d, r, o, d, d, d, d, d],
      AvatarScene.rooftop: <JourneyFamily?>[d, d, d, r, d, o, d, d, d, d],
      AvatarScene.mountainHut: <JourneyFamily?>[
        d, d, d, r, d, d, o, d, d, d, //
      ],
      AvatarScene.forestCabin: <JourneyFamily?>[
        d, w, w, r, d, d, d, o, d, d, //
      ],
      AvatarScene.trainCompartment: <JourneyFamily?>[
        d, d, d, r, d, d, d, d, o, d, //
      ],
      AvatarScene.library: <JourneyFamily?>[d, d, d, r, d, d, d, d, d, o],
    };
    expect(table.keys.toList(), AvatarScene.values);
    for (final List<JourneyFamily?> row in table.values) {
      expect(row, hasLength(AvatarScene.values.length));
    }
    int pairs = 0;
    final Map<JourneyFamily, int> counts = <JourneyFamily, int>{};
    for (final AvatarScene from in AvatarScene.values) {
      for (final AvatarScene to in AvatarScene.values) {
        if (from == to) {
          expect(table[from]![to.index], isNull);
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
    expect(pairs, 90);
    expect(counts, <JourneyFamily, int>{
      JourneyFamily.rocket: 9,
      JourneyFamily.portal: 9,
      JourneyFamily.path: 6,
      JourneyFamily.book: 66,
    });
  });

  test('the scene is the origin until the cut, the destination after', () {
    const JourneyState s = JourneyState(
      from: AvatarScene.livingRoom,
      to: AvatarScene.beach,
      family: JourneyFamily.book,
      phase: JourneyPhase.close,
      serial: 3,
    );
    expect(s.sceneNow, AvatarScene.livingRoom);
    expect(s.next(JourneyPhase.cut).sceneNow, AvatarScene.beach);
    expect(s.next(JourneyPhase.cut).serial, 4);
  });
}
