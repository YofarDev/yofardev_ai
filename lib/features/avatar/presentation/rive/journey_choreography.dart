import 'package:flutter/animation.dart';

import '../../domain/models/journey.dart';

/// What the journey overlay draws in one frame: the threshold's `JourneyVM`
/// numbers and whether the avatar is clipped at the threshold.
class JourneyFrame {
  const JourneyFrame({
    this.family,
    this.show = 0,
    this.open = 0,
    this.lift = 0,
    this.clip = false,
  });

  /// The threshold shown (null: nothing).
  final JourneyFamily? family;
  final double show;
  final double open;
  final double lift;

  /// The avatar is clipped right of the threshold.
  final bool clip;

  static const JourneyFrame none = JourneyFrame();

  @override
  bool operator ==(Object other) =>
      other is JourneyFrame &&
      other.family == family &&
      other.show == show &&
      other.open == open &&
      other.lift == lift &&
      other.clip == clip;

  @override
  int get hashCode => Object.hash(family, show, open, lift, clip);

  @override
  String toString() =>
      'JourneyFrame(${family?.name}, show $show, open $open, lift $lift, clip $clip)';
}

/// The overlay's numbers over a journey's beats (M7 ruling 9), history-free:
/// a pure function of the beat and the time spent in it. Reduce motion
/// jumps every move to its end (the walks are the avatar's own).
abstract final class JourneyChoreography {
  static JourneyFrame at(
    JourneyState? journey,
    Duration elapsed, {
    bool reduceMotion = false,
  }) {
    if (journey == null) {
      return JourneyFrame.none;
    }
    final JourneyFamily family = journey.family;
    final bool rocket = family == JourneyFamily.rocket;
    final double ms = elapsed.inMicroseconds / 1000;

    double ramp(
      double start,
      Duration length, [
      Curve curve = Curves.easeInOut,
    ]) {
      if (reduceMotion) {
        return ms >= start ? 1 : 0;
      }
      final double t = ((ms - start) / length.inMilliseconds).clamp(0.0, 1.0);
      return curve.transform(t);
    }

    final double appearMs = JourneyTiming.appear.inMilliseconds / 2;
    final double closeMs = JourneyTiming.close.inMilliseconds.toDouble();
    final double liftMs = JourneyTiming.lift.inMilliseconds.toDouble();
    switch (journey.phase) {
      case JourneyPhase.pullBack:
        return JourneyFrame(family: family);
      case JourneyPhase.open:
        return JourneyFrame(
          family: family,
          show: ramp(0, JourneyTiming.appear),
          open: ramp(appearMs, JourneyTiming.appear),
          clip: true,
        );
      case JourneyPhase.grab:
      case JourneyPhase.exit:
        return JourneyFrame(family: family, show: 1, open: 1, clip: true);
      case JourneyPhase.close:
        return JourneyFrame(
          family: family,
          show: 1,
          open: 1 - ramp(0, JourneyTiming.close),
          lift: rocket ? ramp(closeMs, JourneyTiming.lift, Curves.easeIn) : 0,
          clip: true,
        );
      case JourneyPhase.cut:
        return JourneyFrame(
          family: family,
          show: 1,
          lift: rocket ? 1 : 0,
          clip: true,
        );
      case JourneyPhase.arriveOpen:
        if (rocket) {
          return JourneyFrame(
            family: family,
            show: 1,
            lift: 1 - ramp(0, JourneyTiming.lift, Curves.easeOut),
            open: ramp(liftMs, JourneyTiming.arriveOpen),
            clip: true,
          );
        }
        return JourneyFrame(
          family: family,
          show: 1,
          open: ramp(
            JourneyTiming.arriveHold.inMilliseconds.toDouble(),
            JourneyTiming.arriveOpen,
          ),
          clip: true,
        );
      case JourneyPhase.enter:
      case JourneyPhase.hang:
        return JourneyFrame(family: family, show: 1, open: 1, clip: true);
      case JourneyPhase.arriveClose:
        return JourneyFrame(
          family: family,
          show: 1,
          open: 1 - ramp(0, JourneyTiming.close),
          clip: true,
        );
      case JourneyPhase.vanish:
        return JourneyFrame(
          family: family,
          show: 1 - ramp(0, JourneyTiming.vanish),
        );
    }
  }

  /// The longest a beat's timed moves run: past it the frame no longer
  /// changes (the overlay's ticker may idle).
  static Duration settleOf(JourneyState journey) => switch (journey.phase) {
    JourneyPhase.open => JourneyTiming.appear * 1.5,
    JourneyPhase.close => JourneyTiming.closeOf(journey.family),
    JourneyPhase.arriveOpen => JourneyTiming.arriveOpenOf(journey.family),
    JourneyPhase.arriveClose => JourneyTiming.close,
    JourneyPhase.vanish => JourneyTiming.vanish,
    _ => Duration.zero,
  };
}
