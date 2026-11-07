import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/domain/models/journey.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/journey_choreography.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/journey_layer.dart';

JourneyState _j(
  JourneyPhase phase, [
  JourneyFamily family = JourneyFamily.book,
]) => JourneyState(
  from: AvatarScene.livingRoom,
  to: AvatarScene.beach,
  family: family,
  phase: phase,
  serial: 1,
);

JourneyFrame _at(
  JourneyPhase phase,
  int ms, {
  JourneyFamily family = JourneyFamily.book,
  bool rm = false,
}) => JourneyChoreography.at(
  _j(phase, family),
  Duration(milliseconds: ms),
  reduceMotion: rm,
);

/// The layer's ribbon-jacket rule under test.
abstract final class JourneyLayerJacket {
  static double of(JourneyState journey, double jacket) =>
      JourneyLayer.journeyJacketOf(journey, jacket);
}

void main() {
  test('no journey draws nothing and clips nothing', () {
    expect(JourneyChoreography.at(null, Duration.zero), JourneyFrame.none);
  });

  test('the threshold appears and opens, then holds open for the walk', () {
    expect(_at(JourneyPhase.pullBack, 300).show, 0);
    expect(_at(JourneyPhase.open, 0).show, 0);
    expect(_at(JourneyPhase.open, 0).clip, isTrue);
    expect(_at(JourneyPhase.open, 300).show, 1);
    expect(
      _at(JourneyPhase.open, 290).open,
      0,
    ); // the swing starts as the appear ends
    expect(
      _at(JourneyPhase.open, 450).open,
      lessThan(0.06),
    ); // the crack: barely open
    final JourneyFrame exit = _at(JourneyPhase.exit, 999);
    expect((exit.show, exit.open, exit.clip), (1.0, 1.0, true));
  });

  test('the book stages crack-swing then riffle-unfold, overlapping', () {
    expect(_at(JourneyPhase.open, 290).show, lessThan(1)); // still appearing
    expect(
      _at(JourneyPhase.open, 395).open,
      lessThan(0.06),
    ); // crack: barely cracked
    expect(
      _at(JourneyPhase.open, 700).open,
      allOf(greaterThan(0.25), lessThan(0.8)),
    );
    expect(_at(JourneyPhase.open, 1010).open, 1); // cover landed
    expect(_at(JourneyPhase.open, 849).unfold, 0); // riffle not yet
    expect(
      _at(JourneyPhase.open, 900).unfold,
      greaterThan(0),
    ); // overlap with the swing
    expect(_at(JourneyPhase.open, 1600).unfold, 1); // settled past the beat
  });

  test(
    'the close folds the vignette before the cover falls, with a rebound',
    () {
      expect(
        _at(JourneyPhase.close, 100).unfold,
        lessThan(0.5),
      ); // folding fast
      expect(_at(JourneyPhase.close, 100).open, 1); // cover still open
      expect(_at(JourneyPhase.close, 580).open, 0); // landed
      final double rebound = _at(
        JourneyPhase.close,
        610,
      ).open; // 60ms rebound tail
      expect(rebound, greaterThan(0));
      expect(rebound, lessThan(0.05));
      expect(_at(JourneyPhase.close, 640).open, 0);
    },
  );

  test('the arrival vignette shows the origin, the exit the destination', () {
    expect(_at(JourneyPhase.open, 999).destination, AvatarScene.beach);
    expect(
      _at(JourneyPhase.arriveOpen, 999).destination,
      AvatarScene.livingRoom,
    );
    expect(
      _at(
        JourneyPhase.arriveOpen,
        999,
        family: JourneyFamily.rocket,
      ).destination,
      isNull,
    );
  });

  test('the book holds open through the jacket beats (M8)', () {
    for (final JourneyPhase phase in <JourneyPhase>[
      JourneyPhase.grab,
      JourneyPhase.hang,
    ]) {
      for (final int ms in <int>[0, 380, 900]) {
        final JourneyFrame f = _at(phase, ms);
        expect(
          (f.show, f.open, f.unfold, f.clip),
          (1.0, 1.0, 1.0, true),
          reason: '$phase',
        );
      }
      expect(JourneyChoreography.settleOf(_j(phase)), Duration.zero);
    }
  });

  test('only the book writes the ribbon jacket (v11)', () {
    expect(JourneyLayerJacket.of(_j(JourneyPhase.open), 1), 1);
    expect(JourneyLayerJacket.of(_j(JourneyPhase.grab), 0), 0);
    expect(JourneyLayerJacket.of(_j(JourneyPhase.vanish), 2), 1);
    for (final JourneyFamily family in <JourneyFamily>[
      JourneyFamily.path,
      JourneyFamily.portal,
      JourneyFamily.rocket,
    ]) {
      expect(JourneyLayerJacket.of(_j(JourneyPhase.open, family), 1), 0);
    }
  });

  test('it closes before the cut and stays shut across it', () {
    expect(_at(JourneyPhase.close, 0).open, 1);
    expect(_at(JourneyPhase.close, 350).open, lessThan(1)); // mid-fall
    final JourneyFrame cut = _at(JourneyPhase.cut, 0);
    expect((cut.show, cut.open, cut.lift, cut.clip), (1.0, 0.0, 0.0, true));
    expect(_at(JourneyPhase.cut, 0).unfold, 0);
  });

  test(
    'the rocket lands before boarding, rumbles on the pad, lifts off after its '
    'hatch closes and lands before it opens (v16)',
    () {
      JourneyFrame rocket(JourneyPhase phase, int ms) =>
          _at(phase, ms, family: JourneyFamily.rocket);
      // boarding: it comes down from out of frame, then the hatch opens
      expect(rocket(JourneyPhase.open, 0).lift, 1);
      expect(rocket(JourneyPhase.open, 350).lift, inExclusiveRange(0, 1));
      expect((rocket(JourneyPhase.open, 700).lift), 0);
      expect(rocket(JourneyPhase.open, 700).open, 0);
      expect(rocket(JourneyPhase.open, 1100).open, 1);
      // the lift-off: held on the pad through the ignition (the file's
      // rumble band, lift <= 0.02), then the climb
      expect(rocket(JourneyPhase.close, 640).lift, 0);
      expect(rocket(JourneyPhase.close, 640 + 175).lift, closeTo(0.01, 1e-9));
      expect(rocket(JourneyPhase.close, 640 + 350).lift, closeTo(0.02, 1e-9));
      expect(
        rocket(JourneyPhase.close, 640 + 700).lift,
        inExclusiveRange(0.02, 1),
      );
      expect(rocket(JourneyPhase.close, 1640).lift, 1);
      expect(rocket(JourneyPhase.cut, 0).lift, 1);
      final JourneyFrame landing = rocket(JourneyPhase.arriveOpen, 350);
      expect(landing.lift, inExclusiveRange(0, 1));
      expect(landing.open, 0);
      final JourneyFrame landed = rocket(JourneyPhase.arriveOpen, 1050);
      expect((landed.lift, landed.open), (0.0, 1.0));
      // after the arrival it takes off empty instead of fading
      expect(
        (
          rocket(JourneyPhase.vanish, 0).show,
          rocket(JourneyPhase.vanish, 0).lift,
        ),
        (1.0, 0.0),
      );
      expect(rocket(JourneyPhase.vanish, 1000).lift, 1);
      expect(
        JourneyChoreography.settleOf(
          _j(JourneyPhase.vanish, JourneyFamily.rocket),
        ),
        JourneyTiming.liftOff,
      );
      // the other thresholds never lift
      expect(_at(JourneyPhase.close, 1340).lift, 0);
      expect(_at(JourneyPhase.open, 0).lift, 0);
    },
  );

  test('it opens in the new scene, closes behind the avatar and vanishes', () {
    expect(
      _at(JourneyPhase.arriveOpen, 120).open,
      0,
    ); // the swing starts at the hold
    expect(_at(JourneyPhase.arriveOpen, 570).open, 1); // the swing has landed
    // the arrival riffle must finish inside the beat (1000 ms)
    expect(_at(JourneyPhase.arriveOpen, 980).unfold, 1);
    expect(_at(JourneyPhase.enter, 0).open, 1);
    expect(_at(JourneyPhase.arriveClose, 640).open, 0); // the fall lands
    expect(_at(JourneyPhase.vanish, 0).show, 1);
    expect(_at(JourneyPhase.vanish, 300).show, 0);
    expect(_at(JourneyPhase.vanish, 0).clip, isFalse);
  });

  test('each beat settles: past it the frame no longer changes', () {
    expect(
      JourneyChoreography.settleOf(_j(JourneyPhase.open)),
      const Duration(milliseconds: 1500),
    );
    expect(
      JourneyChoreography.settleOf(_j(JourneyPhase.close)),
      const Duration(milliseconds: 660),
    );
    expect(
      JourneyChoreography.settleOf(_j(JourneyPhase.arriveClose)),
      const Duration(milliseconds: 660),
    );
    expect(
      JourneyChoreography.settleOf(_j(JourneyPhase.arriveOpen)),
      JourneyTiming.arriveOpenOf(JourneyFamily.book),
    );
    expect(
      JourneyChoreography.settleOf(
        _j(JourneyPhase.arriveOpen, JourneyFamily.rocket),
      ),
      JourneyTiming.arriveOpenOf(JourneyFamily.rocket),
    );
    expect(
      JourneyChoreography.settleOf(_j(JourneyPhase.vanish)),
      JourneyTiming.vanish,
    );
  });

  test('reduce motion jumps every move to its end', () {
    expect(_at(JourneyPhase.open, 0, rm: true).show, 1);
    expect(
      _at(JourneyPhase.open, 0, rm: true).open,
      1,
    ); // the swing collapses to its end
    expect(
      _at(JourneyPhase.open, 0, rm: true).unfold,
      0,
    ); // ramps keep their start
    expect(_at(JourneyPhase.open, 850, rm: true).unfold, 1);
    expect(
      _at(JourneyPhase.close, 0, rm: true).open,
      0,
    ); // the fall collapses to its end
    expect(_at(JourneyPhase.arriveOpen, 0, rm: true).open, 1);
    expect(_at(JourneyPhase.vanish, 0, rm: true).show, 0);
  });

  test('the threshold x follows the avatar fit (contain, bottom-centre)', () {
    // the artboard fills a 800 x 1000 box: x 640
    expect(ThresholdClipper.thresholdX(const Size(800, 1000)), 640);
    // portrait phone: width-bound, 390 / 800
    expect(
      ThresholdClipper.thresholdX(const Size(390, 844)),
      closeTo(312, 1e-9),
    );
    // landscape: height-bound and centred
    expect(
      ThresholdClipper.thresholdX(const Size(1280, 800)),
      closeTo((1280 - 640) / 2 + 640 * 0.8, 1e-9),
    );
    final ValueNotifier<bool> active = ValueNotifier<bool>(false);
    final ThresholdClipper clipper = ThresholdClipper(active);
    expect(clipper.getClip(const Size(800, 1000)).right, greaterThan(800));
    active.value = true;
    expect(clipper.getClip(const Size(800, 1000)).right, 640);
  });

  test('a reduced journey (reduce motion, M11 ruling 18) draws nothing and '
      'never clips; it fades out only in close and cut', () {
    for (final JourneyFamily family in JourneyFamily.values) {
      for (final JourneyPhase phase in JourneyPhase.values) {
        final JourneyState journey = JourneyState(
          from: AvatarScene.livingRoom,
          to: AvatarScene.beach,
          family: family,
          phase: phase,
          serial: 1,
          reduced: true,
        );
        for (final bool rm in <bool>[false, true]) {
          expect(
            JourneyChoreography.at(
              journey,
              const Duration(milliseconds: 100),
              reduceMotion: rm,
            ),
            JourneyFrame.none,
          );
        }
        expect(
          journey.fadedOut,
          phase == JourneyPhase.close || phase == JourneyPhase.cut,
        );
        expect(journey.hasJacket, isFalse);
        expect(journey.next(JourneyPhase.vanish).reduced, isTrue);
      }
    }
  });
}
