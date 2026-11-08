import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/domain/models/journey.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/journey_choreography.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/journey_passage.dart';

/// The avatar's feet in its artboard at walk position [x].
Offset _feet(double x) => Offset(x, PresenceWalk.ground);

JourneyState _j(JourneyFamily family, JourneyPhase phase) => JourneyState(
  from: AvatarScene.beach,
  to: AvatarScene.deepSpace,
  family: family,
  phase: phase,
  serial: 1,
);

JourneyFrame _at(JourneyFamily family, JourneyPhase phase, int ms) =>
    JourneyChoreography.at(_j(family, phase), Duration(milliseconds: ms));

const List<JourneyFamily> _open = <JourneyFamily>[
  JourneyFamily.path,
  JourneyFamily.portal,
  JourneyFamily.rocket,
];

void main() {
  test('the walk mirrors gen_avatar.walk_tracks (Root x)', () {
    // values from the generator's pose(f) at 60 fps
    double out(int ms) =>
        PresenceWalk.rootX(Duration(milliseconds: ms), out: true);
    double back(int ms) =>
        PresenceWalk.rootX(Duration(milliseconds: ms), out: false);
    expect(out(0), 400);
    expect(out(50), closeTo(394.337, 1e-3)); // the weight shift leans back
    expect(out(500), closeTo(568.513, 1e-3));
    expect(out(800), closeTo(879.509, 1e-3));
    expect(out(1333), closeTo(1250, 1e-3));
    expect(out(1600), 1250);
    expect(back(500), closeTo(1081.487, 1e-3));
    expect(back(1600), 400);
  });

  test('the passage runs over most of the walk, backwards on the way in', () {
    for (final JourneyFamily family in JourneyFamily.values) {
      double p(int ms, bool out) =>
          JourneyPassage.progress(family, Duration(milliseconds: ms), out: out);
      final (int a, int b) = JourneyPassage.exitWindow(family);
      expect(b - a, greaterThanOrEqualTo(750), reason: '$family');
      expect(b, lessThanOrEqualTo(1550), reason: '$family'); // before the clip
      expect((p(0, true), p(1600, true)), (0.0, 1.0), reason: '$family');
      expect((p(0, false), p(1600, false)), (1.0, 0.0), reason: '$family');
      // the walk in's passage is done before the avatar stops
      expect(JourneyPassage.enterWindow(family).$2, lessThan(1333));
    }
  });

  test('on stage nothing changes; the book clips only mid-passage', () {
    // The standing avatar (its phase bubble over the open book) is whole; the
    // spine clip holds only while it folds into the gutter.
    for (final JourneyFamily family in JourneyFamily.values) {
      expect(
        JourneyPassage.of(family, 0, PresenceWalk.onX),
        AvatarPassage.none,
        reason: '$family',
      );
    }
    expect(JourneyPassage.of(JourneyFamily.book, 0.5, 575).clips, isTrue);
  });

  test('until it reaches the threshold the avatar keeps its own walk', () {
    // early in the passage, short of the threshold's point, its feet are
    // its own: nothing pulls it back towards the stage
    for (final JourneyFamily family in _open) {
      final AvatarPassage p = JourneyPassage.of(family, 0.02, 560);
      expect(p.map(_feet(560)).dx, closeTo(560, 12), reason: '$family');
    }
  });

  test('the portal draws the avatar in, turning, stretching, glowing', () {
    final AvatarPassage mid = JourneyPassage.of(
      JourneyFamily.portal,
      0.6,
      1100,
    );
    expect(mid.scaleY, inExclusiveRange(0, 1));
    expect(mid.scaleX, lessThan(mid.scaleY)); // drawn out
    expect(mid.rotation, lessThan(0)); // anticlockwise, the vortex's sense
    expect((mid.tint, mid.tintAmount > 0), (PassageTint.glow, true));
    // the body has reached the pull point inside the ring
    final Offset body = mid.map(
      const Offset(1100, PresenceWalk.ground - JourneyPassage.bodyHeight),
    );
    expect(body.dx, closeTo(JourneyPassage.portalPull.dx, 1e-9));
    // the pull point is in the portrait band, inside the mouth (the ring's
    // 330 x 900 ellipse less its rim, about the core)
    const Offset pull = JourneyPassage.portalPull;
    expect(pull.dx, inInclusiveRange(640, 800));
    final Offset d = pull - JourneyPassage.portalCore;
    expect(
      (d.dx / 150) * (d.dx / 150) + (d.dy / 430) * (d.dy / 430),
      lessThan(1),
    );
    final AvatarPassage gone = JourneyPassage.of(
      JourneyFamily.portal,
      1,
      PresenceWalk.offX,
    );
    expect(gone.scaleY, lessThan(0.01)); // a point, never singular
    expect(gone.opacity, 0);
  });

  test('the path takes the avatar down its tunnel into a silhouette', () {
    final AvatarPassage far = JourneyPassage.of(
      JourneyFamily.path,
      1,
      PresenceWalk.offX,
    );
    final Offset feet = far.map(_feet(PresenceWalk.offX));
    expect(feet.dx, closeTo(JourneyPassage.pathFar.dx, 1e-9));
    expect(feet.dy, closeTo(JourneyPassage.pathFar.dy, 1e-9));
    expect(far.scaleY, closeTo(JourneyPassage.pathFarScale, 1e-12));
    expect(far.opacity, 0);
    final AvatarPassage mid = JourneyPassage.of(JourneyFamily.path, 0.5, 900);
    expect(mid.tint, PassageTint.silhouette);
    expect(mid.tintAmount, inExclusiveRange(0, 1));
    expect(mid.opacity, 1);
  });

  test('the rocket: shrink, a hop onto the sill, into the cabin, clipped', () {
    const Offset sill = JourneyPassage.rocketSill;
    final AvatarPassage landed = JourneyPassage.of(
      JourneyFamily.rocket,
      0.8,
      1200,
    );
    final Offset feet = landed.map(_feet(1200));
    expect(feet.dx, closeTo(sill.dx, 1e-9));
    expect(feet.dy, closeTo(sill.dy, 1e-9));
    expect(landed.scaleY, closeTo(JourneyPassage.rocketScale, 1e-12));
    expect(landed.window, JourneyPassage.rocketHatch);
    // landed, the small avatar (±170 px wide, 870 px tall at full size) fits
    // the opening: the clip cuts nothing yet
    const double k = JourneyPassage.rocketScale;
    const Rect hatch = JourneyPassage.rocketHatch;
    expect(sill.dx - 170 * k, greaterThan(hatch.left));
    expect(sill.dx + 170 * k, lessThan(hatch.right));
    expect(sill.dy - 870 * k, greaterThan(hatch.top));
    // the hop: halfway, the feet are above both the ground and the sill
    final AvatarPassage hop = JourneyPassage.of(
      JourneyFamily.rocket,
      0.625,
      1100,
    );
    expect(hop.map(_feet(1100)).dy, lessThan(sill.dy));
    expect(hop.clips, isFalse); // in front of the hull until it lands
    // then it walks on into the cabin, past the opening's far edge, and fades
    final AvatarPassage aboard = JourneyPassage.of(
      JourneyFamily.rocket,
      1,
      PresenceWalk.offX,
    );
    expect(
      aboard.map(_feet(PresenceWalk.offX)).dx,
      closeTo(sill.dx + JourneyPassage.rocketCabinWalk, 1e-9),
    );
    expect(aboard.opacity, 0);
  });

  test('the book folds the avatar flat into its gutter', () {
    final AvatarPassage mid = JourneyPassage.of(JourneyFamily.book, 0.5, 575);
    expect(mid.scaleX, inExclusiveRange(0, 1));
    expect(mid.map(const Offset(640, 400)).dx, 640); // the spine stays put
    expect(JourneyPassage.of(JourneyFamily.book, 1, 700).opacity, 0);
  });

  test('the choreography walks the passage with the beats', () {
    for (final JourneyFamily family in JourneyFamily.values) {
      AvatarPassage want(int ms, {required bool out}) {
        final Duration t = Duration(milliseconds: ms);
        return JourneyPassage.of(
          family,
          JourneyPassage.progress(family, t, out: out),
          PresenceWalk.rootX(t, out: out),
        );
      }

      expect(
        _at(family, JourneyPhase.exit, 0).passage,
        JourneyPassage.of(family, 0, PresenceWalk.onX),
      );
      expect(_at(family, JourneyPhase.exit, 800).passage, want(800, out: true));
      expect(
        _at(family, JourneyPhase.enter, 500).passage,
        want(500, out: false),
      );
      // out of sight while away (the book's spine also clips it)
      for (final JourneyPhase away in <JourneyPhase>[
        JourneyPhase.close,
        JourneyPhase.cut,
        JourneyPhase.arriveOpen,
      ]) {
        expect(
          _at(family, away, 0).passage.opacity,
          0,
          reason: '$family $away',
        );
      }
      expect(_at(family, JourneyPhase.vanish, 0).passage, AvatarPassage.none);
      expect(
        JourneyChoreography.settleOf(_j(family, JourneyPhase.exit)),
        greaterThanOrEqualTo(PresenceWalk.length),
      );
    }
  });
}
