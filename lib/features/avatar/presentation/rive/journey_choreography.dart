import 'dart:math' as math;

import 'package:flutter/animation.dart';

import '../../../../core/models/avatar_scene.dart';
import '../../domain/models/journey.dart';

/// What the journey overlay draws in one frame: the threshold's `JourneyVM`
/// numbers and whether the avatar is clipped at the threshold.
class JourneyFrame {
  const JourneyFrame({
    this.family,
    this.show = 0,
    this.open = 0,
    this.unfold = 0,
    this.lift = 0,
    this.destination,
    this.clip = false,
  });

  /// The threshold shown (null: nothing).
  final JourneyFamily? family;
  final double show;
  final double open;

  /// The book's riffle and pop-up vignette (v15; the other thresholds ignore
  /// it): 1 while the book stands open, 0 on the cut.
  final double unfold;
  final double lift;

  /// The scene the book's vignette shows (v15, book only): the destination
  /// before the cut, the origin from it — the scene NOT on screen.
  final AvatarScene? destination;

  /// The avatar is clipped right of the threshold.
  final bool clip;

  static const JourneyFrame none = JourneyFrame();

  @override
  bool operator ==(Object other) =>
      other is JourneyFrame &&
      other.family == family &&
      other.show == show &&
      other.open == open &&
      other.unfold == unfold &&
      other.lift == lift &&
      other.destination == destination &&
      other.clip == clip;

  @override
  int get hashCode =>
      Object.hash(family, show, open, unfold, lift, destination, clip);

  @override
  String toString() =>
      'JourneyFrame(${family?.name}, show $show, open $open, unfold $unfold, '
      'lift $lift, dest ${destination?.name}, clip $clip)';
}

/// The cover's staged swing (v15): the first 15 % of the span is the crack —
/// a slow, barely-open sliver (0 → 0.03) — then the cover swings heavy,
/// ease-in-out cubic, over the rest (0.03 → 1).
class _SwingCurve extends Curve {
  const _SwingCurve();

  static const double _crackShare = 0.15;
  static const double _crackOpen = 0.03;

  @override
  double transform(double t) {
    if (t <= 0) {
      return 0;
    }
    if (t >= 1) {
      return 1;
    }
    if (t <= _crackShare) {
      return _crackOpen * (t / _crackShare);
    }
    final double rest = (t - _crackShare) / (1 - _crackShare);
    return _crackOpen +
        (1 - _crackOpen) * Curves.easeInOutCubic.transform(rest);
  }
}

/// The cover's fall (v15): ease-in-out cubic's inverse — a slow start
/// dropping faster as it goes — lands shut at 86 % of the span, then the
/// rebound: the closedness dips 4 % below shut for the last 60 ms of the
/// window (the cover springs back open a crack, +0.04) and settles shut at
/// the beat's end.
class _FallCurve extends Curve {
  const _FallCurve();

  /// The easeInCubic descent's share of the span: it lands at 580 of the
  /// close beat's 200–640 ms window.
  static const double _landShare = 380 / 440;
  static const double _rebound = 0.04;

  @override
  double transform(double t) {
    if (t >= 1) {
      return 0;
    }
    if (t <= 0) {
      return 1;
    }
    if (t <= _landShare) {
      return 1 - Curves.easeInCubic.transform(t / _landShare);
    }
    final double tail = (t - _landShare) / (1 - _landShare);
    return _rebound * math.sin(math.pi * tail);
  }
}

/// The overlay's numbers over a journey's beats (M7 ruling 9, v15 staging),
/// history-free: a pure function of the beat and the time spent in it.
/// Reduce motion jumps every move to its end (the walks are the avatar's
/// own); the piecewise curves collapse to their end values for the beat.
abstract final class JourneyChoreography {
  /// The book's staged windows (ms within a beat; the tests pin them). The
  /// cover swing starts as the appear ends and lands 390 ms before the grab;
  /// the riffle overlaps the swing's tail. The file's unfold-driven art is
  /// fully landed at unfold 0.89 (`gen_journeys.UNFOLD_LANDED`), and this
  /// open ramp reaches ~0.895 by the beat's end, so the grab/exit rows
  /// snapping `unfold` to 1 change nothing visible.
  static const int _openSwingEndMs = 1010;
  static const int _openUnfoldStartMs = 850;
  static const int _openUnfoldLenMs = 750;

  /// The close: the fold snaps first (the vignette folds before the cover
  /// falls), then the cover falls over the rest with its rebound tail.
  static const int _fallStartMs = 200;
  static const int _foldLenMs = 200;

  /// The arrival (book): the swing runs hold → 570 ms without the crack;
  /// the riffle starts where the plain thresholds' open would end.
  static const int _arriveSwingLenMs = 450;
  static const int _arriveUnfoldLenMs = 510;

  static JourneyFrame at(
    JourneyState? journey,
    Duration elapsed, {
    bool reduceMotion = false,
  }) {
    // A reduced journey (a cross-fade cut) draws no threshold and never
    // clips the avatar.
    if (journey == null || journey.reduced) {
      return JourneyFrame.none;
    }
    final JourneyFamily family = journey.family;
    final bool rocket = family == JourneyFamily.rocket;
    final bool book = family == JourneyFamily.book;
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

    // A curve move (the book's staged swing and fall) collapses to its end
    // value under reduce motion.
    double staged(double start, Duration length, Curve curve, double end) {
      if (reduceMotion) {
        return end;
      }
      final double t = ((ms - start) / length.inMilliseconds).clamp(0.0, 1.0);
      return curve.transform(t);
    }

    // The close's cover: held open until the fall starts, then the fall
    // curve (which reads 0 at its own end and through the rebound's tail).
    double closeOpen() {
      if (!reduceMotion && ms <= _fallStartMs) {
        return 1;
      }
      return staged(
        _fallStartMs.toDouble(),
        JourneyTiming.close - const Duration(milliseconds: _fallStartMs),
        const _FallCurve(),
        0,
      );
    }

    // The vignette's scene: the destination before the cut, the origin from
    // it — the scene NOT on screen (book only).
    final AvatarScene? destination = book
        ? (journey.phase.index >= JourneyPhase.cut.index
              ? journey.from
              : journey.to)
        : null;

    final double appearMs = JourneyTiming.appear.inMilliseconds / 2;
    final double closeMs = JourneyTiming.close.inMilliseconds.toDouble();
    final double liftMs = JourneyTiming.lift.inMilliseconds.toDouble();
    switch (journey.phase) {
      case JourneyPhase.pullBack:
        return JourneyFrame(family: family, destination: destination);
      case JourneyPhase.open:
        return JourneyFrame(
          family: family,
          show: ramp(0, JourneyTiming.appear, Curves.easeOut),
          open: book
              ? staged(
                  JourneyTiming.appear.inMilliseconds.toDouble(),
                  Duration(
                    milliseconds:
                        _openSwingEndMs - JourneyTiming.appear.inMilliseconds,
                  ),
                  const _SwingCurve(),
                  1,
                )
              : ramp(appearMs, JourneyTiming.appear),
          unfold: ramp(
            _openUnfoldStartMs.toDouble(),
            const Duration(milliseconds: _openUnfoldLenMs),
            Curves.easeOut,
          ),
          destination: destination,
          clip: true,
        );
      case JourneyPhase.grab:
      case JourneyPhase.exit:
        return JourneyFrame(
          family: family,
          show: 1,
          open: 1,
          unfold: 1,
          destination: destination,
          clip: true,
        );
      case JourneyPhase.close:
        return JourneyFrame(
          family: family,
          show: 1,
          open: closeOpen(),
          unfold:
              1 -
              ramp(0, const Duration(milliseconds: _foldLenMs), Curves.easeOut),
          lift: rocket ? ramp(closeMs, JourneyTiming.lift, Curves.easeIn) : 0,
          destination: destination,
          clip: true,
        );
      case JourneyPhase.cut:
        return JourneyFrame(
          family: family,
          show: 1,
          lift: rocket ? 1 : 0,
          destination: destination,
          clip: true,
        );
      case JourneyPhase.arriveOpen:
        if (rocket) {
          return JourneyFrame(
            family: family,
            show: 1,
            lift: 1 - ramp(0, JourneyTiming.lift, Curves.easeOut),
            open: ramp(liftMs, JourneyTiming.arriveOpen),
            destination: destination,
            clip: true,
          );
        }
        if (book) {
          return JourneyFrame(
            family: family,
            show: 1,
            open: staged(
              JourneyTiming.arriveHold.inMilliseconds.toDouble(),
              const Duration(milliseconds: _arriveSwingLenMs),
              Curves.easeInOutCubic,
              1,
            ),
            unfold: ramp(
              (JourneyTiming.arriveHold + JourneyTiming.arriveOpen)
                  .inMilliseconds
                  .toDouble(),
              const Duration(milliseconds: _arriveUnfoldLenMs),
              Curves.easeOut,
            ),
            destination: destination,
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
          destination: destination,
          clip: true,
        );
      case JourneyPhase.enter:
      case JourneyPhase.hang:
        return JourneyFrame(
          family: family,
          show: 1,
          open: 1,
          unfold: 1,
          destination: destination,
          clip: true,
        );
      case JourneyPhase.arriveClose:
        return JourneyFrame(
          family: family,
          show: 1,
          open: closeOpen(),
          unfold:
              1 -
              ramp(0, const Duration(milliseconds: _foldLenMs), Curves.easeOut),
          destination: destination,
          clip: true,
        );
      case JourneyPhase.vanish:
        return JourneyFrame(
          family: family,
          show: 1 - ramp(0, JourneyTiming.vanish),
          destination: destination,
        );
    }
  }

  /// The longest a beat's timed moves run: past it the frame no longer
  /// changes (the overlay's ticker may idle). The open beat settles 100 ms
  /// in: its beat is over at 1400 ms (the grab takes over and writes 1) and
  /// its riffle ramp is past the file's landed mark by then. The close beats
  /// get 20 ms past their last move (the rebound's tail).
  static Duration settleOf(JourneyState journey) => switch (journey.phase) {
    JourneyPhase.open => JourneyTiming.open + const Duration(milliseconds: 100),
    JourneyPhase.close =>
      JourneyTiming.closeOf(journey.family) + const Duration(milliseconds: 20),
    JourneyPhase.arriveOpen => JourneyTiming.arriveOpenOf(journey.family),
    JourneyPhase.arriveClose =>
      JourneyTiming.close + const Duration(milliseconds: 20),
    JourneyPhase.vanish => JourneyTiming.vanish,
    _ => Duration.zero,
  };
}
