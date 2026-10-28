import 'dart:math' as math;

import '../models/head_pose.dart';

/// Tunables of the head motion, ported from `perform_turn` /
/// `TurnParams` in `rive/tools/rig_dsl.py` and `MotionRules` in
/// `rive/tools/art_bible.py`. Times in seconds, angles in view-model units.
class HeadMotionParams {
  const HeadMotionParams({
    this.leadS = 0.08,
    this.eyeSettleS = 0.14,
    this.gazeMax = 0.8,
    this.anticipation = 0.2,
    this.anticipationS = 0.13,
    this.bigTurn = 0.25,
    this.rampS = 0.58,
    this.rampMinS = 0.3,
    this.rampFullTravel = 0.5,
    this.rampPerUnit = 0.1,
    this.overshoot = 0.12,
    this.settleS = 0.22,
    this.springF = 2.6,
    this.springZeta = 0.68,
    this.hairF = 2.1,
    this.hairZeta = 0.5,
    this.reduceSettleS = 0.35,
    this.holdMinS = 0.16,
    this.driftAfterS = 1.5,
    this.driftYaw = 0.04,
    this.driftPitch = 0.03,
    this.seed = 7,
  });

  /// The eyes move this long before the head starts.
  final double leadS;

  /// Settle time of the eye spring.
  final double eyeSettleS;

  /// Soft saturation (tanh) of the eye lead.
  final double gazeMax;

  /// Wind-up as a share of the travel, fed to the head target (the output
  /// wind-up lands at ~16 % once the head spring smooths it).
  final double anticipation;
  final double anticipationS;

  /// Only travels longer than this wind up.
  final double bigTurn;

  /// Duration of the speed-capped travel: [rampS] for a full travel
  /// ([rampFullTravel] or more), shrinking to [rampMinS] for tiny ones, plus
  /// [rampPerUnit] per unit of travel.
  final double rampS;
  final double rampMinS;
  final double rampFullTravel;
  final double rampPerUnit;

  /// Overshoot share fed to the head target, settled over [settleS]
  /// (the output peaks at ~12 % once the head spring smooths it).
  final double overshoot;
  final double settleS;

  /// Under-damped head spring smoothing the shaped target.
  final double springF;
  final double springZeta;

  /// Hair follow-through spring (trails the head by ~2 part offsets).
  final double hairF;
  final double hairZeta;

  /// Settle time of the critically damped head used by reduce motion.
  final double reduceSettleS;

  /// A pose must read this long before the next retarget (art bible
  /// `hold_min_ms`), except a return to the user.
  final double holdMinS;

  /// Idle micro drift starts after the target has been steady this long.
  final double driftAfterS;
  final double driftYaw;
  final double driftPitch;

  /// Seed of the drift phases.
  final int seed;
}

/// Frame-stepped solver for the avatar's 2.5D head turn.
///
/// Give it a target with [setTarget] and advance it with [step]; it returns
/// the five rig numbers (`yaw`, `pitch`, `hairLagYaw`, `hairLagPitch`,
/// `eyeLeadYaw`). Pure Dart and deterministic: the same calls give the same
/// poses.
///
/// - Eyes lead: the eye spring chases the target immediately while the head
///   waits [HeadMotionParams.leadS]; `eyeLeadYaw` is the eye-in-head offset
///   and relaxes to 0 as the head arrives.
/// - Each axis travels along a shaped target (wind-up against big turns, a
///   speed-capped smoothstep, overshoot settling over 220 ms) smoothed by an
///   under-damped second-order spring.
/// - Hair follows the head with a slower spring; `hairLag*` is hair − head
///   so it swings past and settles.
/// - Once the target has been steady for 1.5 s a seeded, low-amplitude drift
///   keeps the head alive.
/// - [reduceMotion]: a critically damped head only, no lead, wind-up,
///   overshoot, hair lag or drift.
class HeadMotionSolver {
  HeadMotionSolver({this.params = const HeadMotionParams()})
    : _yawAxis = _Axis(),
      _pitchAxis = _Axis(),
      _eyeOmega = _omegaForSettle(params.eyeSettleS),
      _reduceOmega = _omegaForSettle(params.reduceSettleS) {
    final math.Random rng = math.Random(params.seed);
    _driftPhase = List<double>.generate(
      4,
      (int _) => rng.nextDouble() * 2 * math.pi,
    );
  }

  final HeadMotionParams params;

  /// Largest slice integrated in one go; a longer `dt` (app resumed) is
  /// processed in slices of this size.
  static const double maxSubstepS = 0.05;

  /// A single [step] never simulates more than this (everything has settled
  /// long before).
  static const double maxStepS = 2;

  static const double _integrationS = 1 / 120;
  static const double _epsilon = 1e-9;

  final _Axis _yawAxis;
  final _Axis _pitchAxis;
  final double _eyeOmega;
  final double _reduceOmega;
  late final List<double> _driftPhase;

  double _time = 0;
  double _lastRetargetAt = double.negativeInfinity;
  HeadTarget? _pending;
  double _driftWeight = 0;

  double _eye = 0;
  double _eyeVel = 0;

  double _hairYaw = 0;
  double _hairYawVel = 0;
  double _hairPitch = 0;
  double _hairPitchVel = 0;

  HeadPose _pose = HeadPose.zero;
  bool _reduceMotion = false;

  /// Latest pose (the result of the last [step]).
  HeadPose get pose => _pose;

  /// The target currently being chased (a held [setTarget] is not included).
  HeadTarget get target => HeadTarget(_yawAxis.to, _pitchAxis.to);

  bool get reduceMotion => _reduceMotion;

  set reduceMotion(bool value) {
    if (_reduceMotion == value) {
      return;
    }
    _reduceMotion = value;
    if (value) {
      // Collapse the shaped travel onto the target and lock the hair; the
      // head keeps its position and velocity so the switch does not pop.
      _yawAxis.collapse();
      _pitchAxis.collapse();
      _pending = null;
      _driftWeight = 0;
      _hairYaw = _yawAxis.pos;
      _hairYawVel = 0;
      _hairPitch = _pitchAxis.pos;
      _hairPitchVel = 0;
      _eye = _yawAxis.pos;
      _eyeVel = 0;
    } else {
      _hairYaw = _yawAxis.pos;
      _hairPitch = _pitchAxis.pos;
      _hairYawVel = 0;
      _hairPitchVel = 0;
      _eye = _yawAxis.pos;
      _eyeVel = 0;
    }
    _pose = _compose();
  }

  /// Whether idle drift keeps the solver moving forever: the caller must
  /// keep stepping while this is true.
  bool get driftEnabled => !_reduceMotion;

  /// True once every spring is at rest on the target (ignoring idle drift).
  bool get isSettled {
    if (_pending != null) {
      return false;
    }
    const double pos = 1e-4;
    const double vel = 1e-3;
    final bool headAtRest =
        !_yawAxis.moving(_time, params) &&
        !_pitchAxis.moving(_time, params) &&
        (_yawAxis.pos - _yawAxis.to).abs() < pos &&
        (_pitchAxis.pos - _pitchAxis.to).abs() < pos &&
        _yawAxis.vel.abs() < vel &&
        _pitchAxis.vel.abs() < vel;
    if (_reduceMotion) {
      // No hair or eye springs run in reduce-motion mode.
      return headAtRest;
    }
    return headAtRest &&
        (_hairYaw - _yawAxis.pos).abs() < pos &&
        (_hairPitch - _pitchAxis.pos).abs() < pos &&
        _hairYawVel.abs() < vel &&
        _hairPitchVel.abs() < vel &&
        (_eye - _yawAxis.to).abs() < pos &&
        _eyeVel.abs() < vel;
  }

  /// Aims the head at ([yaw], [pitch]), both clamped to −1..1.
  ///
  /// A retarget arriving less than `holdMin` after the previous one is held
  /// until the pose has read, unless it returns to the user (0, 0).
  void setTarget(double yaw, double pitch) {
    final HeadTarget next = HeadTarget(_clamp1(yaw), _clamp1(pitch));
    final bool returnToUser = next.yaw == 0 && next.pitch == 0;
    final bool sameAsCurrent =
        (next.yaw - _yawAxis.to).abs() < 1e-6 &&
        (next.pitch - _pitchAxis.to).abs() < 1e-6;
    if (sameAsCurrent) {
      _pending = null;
      return;
    }
    if (returnToUser || _time - _lastRetargetAt >= params.holdMinS) {
      _applyTarget(next);
      return;
    }
    _pending = next;
  }

  /// Advances the simulation by [dt] and returns the new pose.
  HeadPose step(Duration dt) {
    double remaining = math.min(dt.inMicroseconds / 1e6, maxStepS);
    while (remaining > _epsilon) {
      final double slice = math.min(remaining, maxSubstepS);
      _advance(slice);
      remaining -= slice;
    }
    return _pose;
  }

  // — internals —

  void _advance(double substep) {
    double left = substep;
    while (left > _epsilon) {
      final double h = math.min(left, _integrationS);
      _integrate(h);
      left -= h;
    }
    _pose = _compose();
  }

  void _integrate(double h) {
    _time += h;
    final HeadTarget? pending = _pending;
    if (pending != null && _time - _lastRetargetAt >= params.holdMinS) {
      _pending = null;
      _applyTarget(pending);
    }

    if (_reduceMotion) {
      _yawAxis.stepCritical(_yawAxis.to, _reduceOmega, h);
      _pitchAxis.stepCritical(_pitchAxis.to, _reduceOmega, h);
      return;
    }

    _updateDriftWeight(h);
    final double driftYaw = _drift(0, params.driftYaw);
    final double driftPitch = _drift(2, params.driftPitch);

    _yawAxis.stepSpring(
      _yawAxis.shaped(_time, params) + driftYaw,
      params.springF,
      params.springZeta,
      h,
    );
    _pitchAxis.stepSpring(
      _pitchAxis.shaped(_time, params) + driftPitch,
      params.springF,
      params.springZeta,
      h,
    );

    // Hair chases the head output.
    final double hairOmega = 2 * math.pi * params.hairF;
    _hairYawVel +=
        h *
        (hairOmega * hairOmega * (_yawAxis.pos - _hairYaw) -
            2 * params.hairZeta * hairOmega * _hairYawVel);
    _hairYaw += h * _hairYawVel;
    _hairPitchVel +=
        h *
        (hairOmega * hairOmega * (_pitchAxis.pos - _hairPitch) -
            2 * params.hairZeta * hairOmega * _hairPitchVel);
    _hairPitch += h * _hairPitchVel;

    // The eyes go straight to the target (plus the drift, so they ride with
    // the head while it idles).
    final double eyeTarget = _yawAxis.to + driftYaw;
    final double e = _eye - eyeTarget;
    final double k = _eyeVel + _eyeOmega * e;
    final double decay = math.exp(-_eyeOmega * h);
    _eye = eyeTarget + (e + k * h) * decay;
    _eyeVel = (_eyeVel - _eyeOmega * k * h) * decay;
  }

  HeadPose _compose() {
    if (_reduceMotion) {
      return HeadPose(
        yaw: _clamp1(_yawAxis.pos),
        pitch: _clamp1(_pitchAxis.pos),
      );
    }
    final double lead =
        params.gazeMax * _tanh((_eye - _yawAxis.pos) / params.gazeMax);
    return HeadPose(
      yaw: _clamp1(_yawAxis.pos),
      pitch: _clamp1(_pitchAxis.pos),
      hairLagYaw: _clamp1(_hairYaw - _yawAxis.pos),
      hairLagPitch: _clamp1(_hairPitch - _pitchAxis.pos),
      eyeLeadYaw: _clamp1(lead),
    );
  }

  void _applyTarget(HeadTarget next) {
    _pending = null;
    _lastRetargetAt = _time;
    _yawAxis.retarget(next.yaw, _time, params, reduce: _reduceMotion);
    _pitchAxis.retarget(next.pitch, _time, params, reduce: _reduceMotion);
  }

  void _updateDriftWeight(double h) {
    final bool steady = _time - _lastRetargetAt >= params.driftAfterS;
    if (steady) {
      _driftWeight = math.min(1, _driftWeight + h / 0.6);
    } else {
      _driftWeight = math.max(0, _driftWeight - h / 0.2);
    }
  }

  /// Two slow sines (≈0.21 Hz and 0.13 Hz) at 60 / 40 % of [amplitude].
  double _drift(int phaseIndex, double amplitude) {
    if (_driftWeight <= 0) {
      return 0;
    }
    final double a = math.sin(
      2 * math.pi * 0.21 * _time + _driftPhase[phaseIndex],
    );
    final double b = math.sin(
      2 * math.pi * 0.13 * _time + _driftPhase[phaseIndex + 1],
    );
    return amplitude * _driftWeight * (0.6 * a + 0.4 * b);
  }

  static double _clamp1(double v) => v.isNaN ? 0 : v.clamp(-1.0, 1.0);

  static double _tanh(double x) {
    if (x > 20) {
      return 1;
    }
    if (x < -20) {
      return -1;
    }
    final double e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }

  /// omega such that a critically damped step from rest is within 5 % at
  /// [seconds] (bisection, as in `omega_for_settle`).
  static double _omegaForSettle(double seconds) {
    double lo = 0.1;
    double hi = 500;
    for (int i = 0; i < 80; i++) {
      final double mid = (lo + hi) / 2;
      final double t = mid * seconds;
      if ((1 + t) * math.exp(-t) > 0.05) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return hi;
  }
}

double _smoothstep(double u) {
  final double c = u.clamp(0.0, 1.0);
  return c * c * (3 - 2 * c);
}

/// One head axis: a shaped travel, and the spring state that follows it.
class _Axis {
  double pos = 0;
  double vel = 0;

  double from = 0;
  double to = 0;
  double _startedAt = double.negativeInfinity;
  double _antic = 0;

  /// Starts a travel from the current shaped value to [value].
  void retarget(
    double value,
    double now,
    HeadMotionParams p, {
    required bool reduce,
  }) {
    if ((value - to).abs() < 1e-6) {
      return;
    }
    final double current = reduce ? to : shaped(now, p);
    from = current;
    to = value;
    _startedAt = now;
    _antic = !reduce && (to - from).abs() > p.bigTurn ? p.anticipation : 0;
    if (reduce) {
      from = to;
    }
  }

  void collapse() {
    from = to;
    _startedAt = double.negativeInfinity;
    _antic = 0;
  }

  /// Target with wind-up, a speed-capped smoothstep and overshoot (the
  /// `shaped_target` of `rig_dsl.py`, for one step).
  double shaped(double now, HeadMotionParams p) {
    final double u = now - _startedAt - p.leadS;
    if (u < 0) {
      return from;
    }
    final double delta = to - from;
    final double travel = delta.abs();
    final double base =
        p.rampMinS +
        (p.rampS - p.rampMinS) * math.min(1, travel / p.rampFullTravel);
    final double ramp = base + p.rampPerUnit * travel;
    final double anticS = _antic > 0 ? p.anticipationS : 0;
    if (u < anticS) {
      return from - _antic * delta * _smoothstep(u / anticS);
    }
    if (u < anticS + ramp) {
      return from -
          _antic * delta +
          (1 + _antic + p.overshoot) * delta * _smoothstep((u - anticS) / ramp);
    }
    if (u < anticS + ramp + p.settleS) {
      return to +
          p.overshoot *
              delta *
              (1 - _smoothstep((u - anticS - ramp) / p.settleS));
    }
    return to;
  }

  /// True while the shaped travel has not reached its end.
  bool moving(double now, HeadMotionParams p) {
    final double u = now - _startedAt - p.leadS;
    if (u < 0) {
      return _startedAt.isFinite;
    }
    final double travel = (to - from).abs();
    final double base =
        p.rampMinS +
        (p.rampS - p.rampMinS) * math.min(1, travel / p.rampFullTravel);
    final double end =
        (_antic > 0 ? p.anticipationS : 0) +
        base +
        p.rampPerUnit * travel +
        p.settleS;
    return u < end;
  }

  /// Under-damped second-order follower of [input].
  void stepSpring(double input, double f, double zeta, double h) {
    final double omega = 2 * math.pi * f;
    vel += h * (omega * omega * (input - pos) - 2 * zeta * omega * vel);
    pos += h * vel;
  }

  /// Exact critically damped step toward [goal].
  void stepCritical(double goal, double omega, double h) {
    final double e = pos - goal;
    final double k = vel + omega * e;
    final double decay = math.exp(-omega * h);
    pos = goal + (e + k * h) * decay;
    vel = (vel - omega * k * h) * decay;
  }
}
