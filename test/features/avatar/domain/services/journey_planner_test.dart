import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/domain/models/journey.dart';
import 'package:yofardev_ai/features/avatar/domain/services/journey_planner.dart';

void main() {
  test('the twelve directed journeys (M7 ruling 5)', () {
    const AvatarScene lr = AvatarScene.livingRoom;
    const AvatarScene cf = AvatarScene.campfire;
    const AvatarScene be = AvatarScene.beach;
    const AvatarScene ds = AvatarScene.deepSpace;
    final Map<(AvatarScene, AvatarScene), JourneyFamily> want =
        <(AvatarScene, AvatarScene), JourneyFamily>{
          (lr, cf): JourneyFamily.door,
          (lr, be): JourneyFamily.door,
          (lr, ds): JourneyFamily.rocket,
          (cf, lr): JourneyFamily.door,
          (cf, be): JourneyFamily.path,
          (cf, ds): JourneyFamily.rocket,
          (be, lr): JourneyFamily.door,
          (be, cf): JourneyFamily.path,
          (be, ds): JourneyFamily.rocket,
          (ds, lr): JourneyFamily.portal,
          (ds, cf): JourneyFamily.portal,
          (ds, be): JourneyFamily.portal,
        };
    expect(want, hasLength(12));
    want.forEach(((AvatarScene, AvatarScene) pair, JourneyFamily family) {
      expect(
        JourneyPlanner.familyFor(pair.$1, pair.$2),
        family,
        reason: '$pair',
      );
    });
    // every family is used
    expect(want.values.toSet(), JourneyFamily.values.toSet());
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
