import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/domain/models/journey.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/journey_choreography.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/journey_layer.dart';

JourneyState _j(
  JourneyPhase phase, [
  JourneyFamily family = JourneyFamily.door,
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
  JourneyFamily family = JourneyFamily.door,
  bool rm = false,
}) => JourneyChoreography.at(
  _j(phase, family),
  Duration(milliseconds: ms),
  reduceMotion: rm,
);

/// The layer's peg-jacket rule under test.
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
    expect(_at(JourneyPhase.open, 150).open, 0);
    expect(_at(JourneyPhase.open, 450).open, 1);
    final JourneyFrame exit = _at(JourneyPhase.exit, 999);
    expect((exit.show, exit.open, exit.clip), (1.0, 1.0, true));
  });

  test('the door holds open through the jacket beats (M8)', () {
    for (final JourneyPhase phase in <JourneyPhase>[
      JourneyPhase.grab,
      JourneyPhase.hang,
    ]) {
      for (final int ms in <int>[0, 380, 900]) {
        final JourneyFrame f = _at(phase, ms);
        expect((f.show, f.open, f.clip), (1.0, 1.0, true), reason: '$phase');
      }
      expect(JourneyChoreography.settleOf(_j(phase)), Duration.zero);
    }
  });

  test('only the door writes the peg jacket (v11)', () {
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
    expect(_at(JourneyPhase.close, 350).open, 0);
    final JourneyFrame cut = _at(JourneyPhase.cut, 0);
    expect((cut.show, cut.open, cut.lift, cut.clip), (1.0, 0.0, 0.0, true));
  });

  test(
    'the rocket lifts off after its hatch closes and lands before it opens',
    () {
      expect(
        _at(JourneyPhase.close, 350, family: JourneyFamily.rocket).lift,
        0,
      );
      expect(
        _at(JourneyPhase.close, 1050, family: JourneyFamily.rocket).lift,
        1,
      );
      expect(_at(JourneyPhase.cut, 0, family: JourneyFamily.rocket).lift, 1);
      final JourneyFrame landing = _at(
        JourneyPhase.arriveOpen,
        350,
        family: JourneyFamily.rocket,
      );
      expect(landing.lift, inExclusiveRange(0, 1));
      expect(landing.open, 0);
      final JourneyFrame landed = _at(
        JourneyPhase.arriveOpen,
        1050,
        family: JourneyFamily.rocket,
      );
      expect((landed.lift, landed.open), (0.0, 1.0));
      // the other thresholds never lift
      expect(_at(JourneyPhase.close, 1050).lift, 0);
    },
  );

  test('it opens in the new scene, closes behind the avatar and vanishes', () {
    expect(_at(JourneyPhase.arriveOpen, 150).open, 0);
    expect(_at(JourneyPhase.arriveOpen, 500).open, 1);
    expect(_at(JourneyPhase.enter, 0).open, 1);
    expect(_at(JourneyPhase.arriveClose, 350).open, 0);
    expect(_at(JourneyPhase.vanish, 0).show, 1);
    expect(_at(JourneyPhase.vanish, 300).show, 0);
    expect(_at(JourneyPhase.vanish, 0).clip, isFalse);
  });

  test('reduce motion jumps every move to its end', () {
    expect(_at(JourneyPhase.open, 0, rm: true).show, 1);
    expect(_at(JourneyPhase.close, 0, rm: true).open, 0);
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
}
