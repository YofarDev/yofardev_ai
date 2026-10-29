import 'dart:math' as math;

import '../models/face_frame.dart';
import '../models/head_pose.dart';

/// Tunables of the head motion, ported from `perform_turn` /
/// `TurnParams` in `rive/tools/rig_dsl.py` and `MotionRules` in
/// `rive/tools/art_bible.py`. Times in seconds, angles in view-model units.
class HeadMotionParams {
  const HeadMotionParams({
    this.leadS = 0.11,
    this.pitchLeadS = 0.03,
    this.eyeSettleS = 0.14,
    this.gazeMax = 0.8,
    this.windUpB = 22,
    this.turnS = 0.36,
    this.bigTurn = 0.25,
    this.rampS = 0.58,
    this.rampMinS = 0.3,
    this.pitchRampS = 0.4,
    this.pitchRampMinS = 0.25,
    this.rampFullTravel = 0.5,
    this.rampPerUnit = 0.1,
    this.overshoot = 0.12,
    this.settleS = 0.22,
    this.springF = 2.6,
    this.springZeta = 0.68,
    this.hairF = 1.8,
    this.hairZeta = 0.6,
    this.hairGain = 1.9,
    this.hairPitchScale = 0.5,
    this.hairLagMax = 0.6,
    this.faceHairF = 3.8,
    this.faceHairZeta = 0.53,
    this.faceHairRoll = 0.5,
    this.reduceSettleS = 0.35,
    this.holdMinS = 0.16,
    this.driftAfterS = 1.0,
    this.returnDriftAfterS = 0.35,
    this.driftFadeInS = 0.2,
    this.driftYaw = 0.1,
    this.driftPitch = 0.09,
    this.nodDepth = 0.06,
    this.nodS = 0.4,
    this.nodMinGapS = 4,
    this.nodMaxGapS = 6,
    this.eyePitchUpGain = 1.6,
    this.eyePitchDownGain = 1.4,
    this.eyePitchDownMax = 0.72,
    this.eyePast = 0.2,
    this.eyePastTravel = 0.5,
    this.saccadeSettleS = 0.03,
    this.microFirstS = 0.15,
    this.microMinS = 1.5,
    this.microMaxS = 3.0,
    this.microAmp = 0.12,
    this.readingDelayS = 1.0,
    this.fixationMinS = 0.2,
    this.fixationMaxS = 0.28,
    this.lineWidth3 = 0.7,
    this.lineWidth4 = 0.82,
    this.lineStart = -0.18,
    this.lineFollow = 0.015,
    this.readingLines = 3,
    this.lineFirstPitch = 0.05,
    this.linePitchStep = 0.05,
    this.fixationPitchJitter = 0.015,
    this.readingPitchFloor = -0.75,
    this.returnDip = 0.04,
    this.returnDipS = 0.25,
    this.farSideYaw = 0.5,
    this.farSideLeadMax = 0.35,
    this.seed = 7,
  });

  /// The eyes move this long before the head starts (yaw / pitch).
  final double leadS;
  final double pitchLeadS;

  /// Settle time of the eye spring.
  final double eyeSettleS;

  /// Soft saturation (tanh) of the eye lead.
  final double gazeMax;

  /// Out-turns (travel over [bigTurn]) use one continuous quintic ease with a
  /// short counter-turn: `H(t) = A*S5(t) - (b/2) t^2 (1-t)^3` over [turnS]
  /// (+ [rampPerUnit] per unit of travel), [windUpB] being `b`. The head
  /// velocity dips once, crosses zero once and peaks once: no stall between
  /// wind-up and turn.
  final double windUpB;
  final double turnS;

  /// Only travels longer than this wind up.
  final double bigTurn;

  /// Duration of the speed-capped travel: [rampS] for a full travel
  /// ([rampFullTravel] or more), shrinking to [rampMinS] for tiny ones, plus
  /// [rampPerUnit] per unit of travel.
  final double rampS;
  final double rampMinS;

  /// The same for the pitch axis (no wind-up there).
  final double pitchRampS;
  final double pitchRampMinS;
  final double rampFullTravel;
  final double rampPerUnit;

  /// Overshoot share fed to the head target, settled over [settleS]
  /// (the output peaks at ~12 % once the head spring smooths it).
  final double overshoot;
  final double settleS;

  /// Under-damped head spring smoothing the shaped target.
  final double springF;
  final double springZeta;

  /// Hair follow-through spring (damping ~0.6: one overshoot and a small
  /// rebound), the gain applied to its offset from the head, the share kept
  /// for pitch (nods must not make the fringe bob) and the soft limit of
  /// |hairLag| (a Rive art limit).
  final double hairF;
  final double hairZeta;
  final double hairGain;
  final double hairPitchScale;
  final double hairLagMax;

  /// Follow-through of the face's own head motion (the speech nods on the
  /// pitch and the roll, [HeadMotionSolver.followFace]): a faster
  /// under-damped spring ([faceHairF] Hz, damping [faceHairZeta], as
  /// integrated at 120 Hz: about 12 % overshoot, within 2 % after ~225 ms,
  /// trailing a steady motion by ~32 ms frame to frame), its offset at
  /// [hairGain] with no pitch reduction (a nod must read in the fringe). The contract has no roll lag: [faceHairRoll] of
  /// the roll's lag (roll units) swings the hair sideways through
  /// `hairLagYaw`.
  final double faceHairF;
  final double faceHairZeta;
  final double faceHairRoll;

  /// Settle time of the critically damped head used by reduce motion.
  final double reduceSettleS;

  /// A pose must read this long before the next retarget (art bible
  /// `hold_min_ms`), except a return to the user.
  final double holdMinS;

  /// Idle drift starts after the target has been steady this long and fades
  /// in over [driftFadeInS]. Two slow sines (3-5 s periods) per axis at these
  /// amplitudes.
  final double driftAfterS;
  final double returnDriftAfterS;
  final double driftFadeInS;
  final double driftYaw;
  final double driftPitch;

  /// Occasional micro-nod while idle: a pitch dip of [nodDepth] over
  /// [nodS], every [nodMinGapS] to [nodMaxGapS] seconds (seeded).
  final double nodDepth;
  final double nodS;
  final double nodMinGapS;
  final double nodMaxGapS;

  /// Held vertical eye look: target pitch x a gain (up / down). Looking down
  /// is capped at -[eyePitchDownMax]: the iris must drop further than the
  /// lid does.
  final double eyePitchUpGain;
  final double eyePitchDownGain;
  final double eyePitchDownMax;

  /// While the head is turned the eyes keep looking [eyePast] past it
  /// (reached at a travel of [eyePastTravel]); on the user they lock on.
  final double eyePast;
  final double eyePastTravel;

  /// Settle time of the fast spring behind saccades and micro-saccades.
  final double saccadeSettleS;

  /// Micro-saccades while the gaze is on the user: the first one at
  /// [microFirstS], then every [microMinS]..[microMaxS], +-[microAmp].
  final double microFirstS;
  final double microMinS;
  final double microMaxS;
  final double microAmp;

  /// Reading (tablet glance): [readingDelayS] after the retarget the eyes
  /// loop lines of 3-4 fixations ([fixationMinS]..[fixationMaxS] each),
  /// stepping one way across [lineWidth3] / [lineWidth4] from [lineStart]
  /// (relative to the held lead), then sweep back. Each new line drops the
  /// eyes [linePitchStep] (the first line starts at [lineFirstPitch]) and
  /// wraps after [readingLines] lines; fixations jitter
  /// +-[fixationPitchJitter] and the eyes never go below
  /// [readingPitchFloor].
  final double readingDelayS;
  final double fixationMinS;
  final double fixationMaxS;
  final double lineWidth3;
  final double lineWidth4;
  final double lineStart;

  /// Head-yaw micro-follow per line (toward the target), reset on wrap.
  final double lineFollow;
  final int readingLines;
  final double lineFirstPitch;
  final double linePitchStep;
  final double fixationPitchJitter;
  final double readingPitchFloor;

  /// While the head is turned past [farSideYaw], the eye lead toward the
  /// opposite (camera) side is capped at [farSideLeadMax] (far-iris safety),
  /// except on the return to the user.
  final double farSideYaw;
  final double farSideLeadMax;

  /// Returning to the user (0, 0) replaces the counter-yaw wind-up with a
  /// small pitch dip of [returnDip] over [returnDipS]; the eyes carry the
  /// intent.
  final double returnDip;
  final double returnDipS;

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
/// - After the turn the eyes keep looking 0.2 past the head toward the
///   target (never swinging to the other side while away); on the user they
///   lock on.
/// - `eyeLeadPitch` holds a vertical look (target pitch x 1.4 down, 1.6 up;
///   at most 0.72 down): the eyes carry the look at the tablet or composer.
/// - While the target is `reading`, the eyes loop lines of 3-4 fixations
///   with a fast return sweep; on the user they make micro-saccades.
/// - Hair follows the head with a slower spring; `hairLag*` is
///   (hair − head) x gain, softly limited to 0.6, with pitch at 0.5 of it.
///   The face's nods and roll ([followFace]) add their own, faster
///   follow-through to the same two numbers.
/// - [followFace] also takes the face's gaze cues: a gaze lock holds the
///   eyes on the user (no micro-saccade), a new saccade serial fires the
///   next micro-saccade now.
/// - Once the target has been steady for 1 s a seeded drift (slow sines plus
///   an occasional micro-nod) keeps the head alive; at the start of a session
///   it fades in within 0.2 s.
/// - Returning to (0, 0) skips the counter-yaw wind-up for a small pitch dip.
/// - [reduceMotion]: a critically damped head and a held vertical eye look
///   only: no lead, wind-up, overshoot, hair lag, saccades or drift.
class HeadMotionSolver {
  HeadMotionSolver({this.params = const HeadMotionParams()})
    : _yawAxis = _Axis(
        leadS: params.leadS,
        rampS: params.rampS,
        rampMinS: params.rampMinS,
        windUpAllowed: true,
      ),
      _pitchAxis = _Axis(
        leadS: params.pitchLeadS,
        rampS: params.pitchRampS,
        rampMinS: params.pitchRampMinS,
        windUpAllowed: false,
      ),
      _eyeOmega = _omegaForSettle(params.eyeSettleS),
      _reduceOmega = _omegaForSettle(params.reduceSettleS) {
    final math.Random rng = math.Random(params.seed);
    _driftPhase = List<double>.generate(
      4,
      (int _) => rng.nextDouble() * 2 * math.pi,
    );
    _eventRng = math.Random(params.seed + 101);
    _nextNodAt = _nodGap();
    _nextMicroAt = params.microFirstS;
    _driftDelay = params.driftAfterS;
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
  late final double _saccadeOmega = _omegaForSettle(params.saccadeSettleS);
  late final List<double> _driftPhase;
  late final math.Random _eventRng;

  double _time = 0;
  double _lastRetargetAt = double.negativeInfinity;
  HeadTarget? _pending;
  double _driftWeight = 1;
  double _driftDelay = 0;
  double _followYaw = 0;
  int _microSign = 1;

  double _eye = 0;
  double _eyeVel = 0;
  double _eyePitch = 0;
  double _eyePitchVel = 0;

  // Fast saccade layer (reading fixations and micro-saccades), added to the
  // eye lead; its pitch part is a goal for the slow eye-pitch spring.
  double _sac = 0;
  double _sacVel = 0;
  double _sacGoalYaw = 0;
  double _sacGoalPitch = 0;

  bool _reading = false;
  double _nextReadAt = double.infinity;
  int _readLine = 0;
  int _readFix = -1;
  int _readFixCount = 0;
  double _readWidth = 0;
  double _readStart = 0;
  double _nextMicroAt = double.infinity;

  double _nextNodAt = 0;
  double _nodStartedAt = double.negativeInfinity;
  double _dipStartedAt = double.negativeInfinity;

  double _hairYaw = 0;
  double _hairYawVel = 0;
  double _hairPitch = 0;
  double _hairPitchVel = 0;

  // The face's nod and roll (inputs) and the hair springs that chase them.
  double _faceNod = 0;
  double _faceRoll = 0;
  double _hairNod = 0;
  double _hairNodVel = 0;
  double _hairRoll = 0;
  double _hairRollVel = 0;
  bool _gazeLock = false;
  int? _saccadeSerial;

  /// A saccade the face asked for, fired once the gaze is free and on the
  /// user.
  bool _saccadeWanted = false;

  HeadPose _pose = HeadPose.zero;
  bool _reduceMotion = false;

  /// Latest pose (the result of the last [step]).
  HeadPose get pose => _pose;

  /// The target currently being chased (a held [setTarget] is not included).
  HeadTarget get target =>
      HeadTarget(_yawAxis.to, _pitchAxis.to, reading: _reading);

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
      _sac = 0;
      _sacVel = 0;
      _sacGoalYaw = 0;
      _sacGoalPitch = 0;
      _nodStartedAt = double.negativeInfinity;
      _dipStartedAt = double.negativeInfinity;
      _hairYaw = _yawAxis.pos;
      _hairYawVel = 0;
      _hairPitch = _pitchAxis.pos;
      _hairPitchVel = 0;
      _lockFaceHair();
      _eye = _yawAxis.pos;
      _eyeVel = 0;
    } else {
      _hairYaw = _yawAxis.pos;
      _hairPitch = _pitchAxis.pos;
      _hairYawVel = 0;
      _hairPitchVel = 0;
      _lockFaceHair();
      _eye = _yawAxis.pos;
      _eyeVel = 0;
    }
    _pose = _compose();
  }

  void _lockFaceHair() {
    _hairNod = _faceNod;
    _hairNodVel = 0;
    _hairRoll = _faceRoll;
    _hairRollVel = 0;
  }

  /// Takes the face's head motion and gaze cues for the next [step]: its
  /// nod (added to the pitch) and [FaceFrame.roll] drive the hair's
  /// follow-through; [FaceFrame.gazeLock] holds the eyes on the user; a
  /// [FaceFrame.saccadeSerial] above the last one seen fires a
  /// micro-saccade on the next step, or as soon as a gaze lock lets go (the
  /// first call only records the serial).
  void followFace(FaceFrame face) {
    _faceNod = face.nodPitch;
    _faceRoll = face.roll;
    _gazeLock = face.gazeLock;
    final int? last = _saccadeSerial;
    _saccadeSerial = face.saccadeSerial;
    if (last != null && face.saccadeSerial > last) {
      _saccadeWanted = true;
    }
    if (_reduceMotion) {
      _lockFaceHair();
    }
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
    final bool eyePitchAtRest =
        (_eyePitch - _eyePitchGoal()).abs() < pos && _eyePitchVel.abs() < vel;
    if (_reduceMotion) {
      // No hair or yaw-eye springs run in reduce-motion mode.
      return headAtRest && eyePitchAtRest;
    }
    return headAtRest &&
        (_hairNod - _faceNod).abs() < pos &&
        (_hairRoll - _faceRoll).abs() < pos &&
        _hairNodVel.abs() < vel &&
        _hairRollVel.abs() < vel &&
        (_hairYaw - _yawAxis.pos).abs() < pos &&
        (_hairPitch - _pitchAxis.pos).abs() < pos &&
        _hairYawVel.abs() < vel &&
        _hairPitchVel.abs() < vel &&
        (_eye - _eyeYawGoal(0)).abs() < pos &&
        _eyeVel.abs() < vel &&
        eyePitchAtRest &&
        !_reading;
  }

  /// Aims the head at ([yaw], [pitch]), both clamped to −1..1.
  ///
  /// A retarget arriving less than `holdMin` after the previous one is held
  /// until the pose has read, unless it returns to the user (0, 0).
  ///
  /// [reading] adds eye saccades while the head holds a tablet glance.
  void setTarget(double yaw, double pitch, {bool reading = false}) {
    final HeadTarget next = HeadTarget(
      _clamp1(yaw),
      _clamp1(pitch),
      reading: reading,
    );
    final bool returnToUser = next.yaw == 0 && next.pitch == 0;
    final bool sameAsCurrent =
        (next.yaw - _yawAxis.to).abs() < 1e-6 &&
        (next.pitch - _pitchAxis.to).abs() < 1e-6 &&
        next.reading == _reading;
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
      _stepEyePitch(h);
      return;
    }

    _updateDriftWeight(h);
    _updateSaccades();
    final double driftYaw = _drift(0, params.driftYaw, 0.22, 0.31);
    final double driftPitch =
        _drift(2, params.driftPitch, 0.20, 0.28) + _nod() + _returnDipNow();

    _yawAxis.stepSpring(
      _yawAxis.shaped(_time, params) + driftYaw + _followYaw,
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

    // ... and the face's nod and roll, on the faster follow-through spring.
    final double faceOmega = 2 * math.pi * params.faceHairF;
    final double faceDamp = 2 * params.faceHairZeta * faceOmega;
    _hairNodVel +=
        h *
        (faceOmega * faceOmega * (_faceNod - _hairNod) -
            faceDamp * _hairNodVel);
    _hairNod += h * _hairNodVel;
    _hairRollVel +=
        h *
        (faceOmega * faceOmega * (_faceRoll - _hairRoll) -
            faceDamp * _hairRollVel);
    _hairRoll += h * _hairRollVel;

    // The eyes go straight to the target and a little past it (plus the
    // drift, so they ride with the head while it idles).
    final double eyeTarget = _eyeYawGoal(driftYaw);
    final double e = _eye - eyeTarget;
    final double k = _eyeVel + _eyeOmega * e;
    final double decay = math.exp(-_eyeOmega * h);
    _eye = eyeTarget + (e + k * h) * decay;
    _eyeVel = (_eyeVel - _eyeOmega * k * h) * decay;
    _stepEyePitch(h);

    // Saccades: a much faster critically damped spring.
    final double se = _sac - _sacGoalYaw;
    final double sk = _sacVel + _saccadeOmega * se;
    final double sdecay = math.exp(-_saccadeOmega * h);
    _sac = _sacGoalYaw + (se + sk * h) * sdecay;
    _sacVel = (_sacVel - _saccadeOmega * sk * h) * sdecay;
  }

  /// True while the gaze rests on the user.
  bool get _onUser => !_reading && _yawAxis.to == 0 && _pitchAxis.to == 0;

  /// Where the eyes aim in yaw: the target plus a look [HeadMotionParams.eyePast]
  /// beyond it (none on the user), plus [drift].
  double _eyeYawGoal(double drift) {
    final double to = _yawAxis.to;
    final double past =
        params.eyePast *
        (to.abs() / params.eyePastTravel).clamp(0.0, 1.0) *
        to.sign;
    return to + past + drift;
  }

  /// The held vertical look: target pitch x a gain, down capped.
  double _eyePitchBase() {
    final double pitch = _pitchAxis.to;
    if (pitch >= 0) {
      return pitch * params.eyePitchUpGain;
    }
    return math.max(pitch * params.eyePitchDownGain, -params.eyePitchDownMax);
  }

  double _eyePitchGoal() {
    if (_reduceMotion) {
      return _clamp1(_eyePitchBase());
    }
    final double goal = _eyePitchBase() + _sacGoalPitch;
    return _clamp1(_reading ? math.max(goal, params.readingPitchFloor) : goal);
  }

  void _stepEyePitch(double h) {
    final double goal = _eyePitchGoal();
    final double e = _eyePitch - goal;
    final double k = _eyePitchVel + _eyeOmega * e;
    final double decay = math.exp(-_eyeOmega * h);
    _eyePitch = goal + (e + k * h) * decay;
    _eyePitchVel = (_eyePitchVel - _eyeOmega * k * h) * decay;
  }

  /// Reading fixations along lines (with a fast return sweep between them)
  /// while reading, micro-saccades while the gaze is on the user.
  void _updateSaccades() {
    if (_reading) {
      if (_time - _lastRetargetAt >= params.readingDelayS &&
          _time >= _nextReadAt) {
        _nextFixation();
      }
    } else if (_gazeLock) {
      // on the listener: the eyes come back to the camera and stay there
      _sacGoalYaw = 0;
      _nextMicroAt = math.max(_nextMicroAt, _time + 0.25);
    } else if (_onUser && (_time >= _nextMicroAt || _saccadeWanted)) {
      _saccadeWanted = false;
      // Alternate sides: each micro-saccade is at least [microAmp] and
      // darts across the user.
      _microSign = -_microSign;
      _sacGoalYaw =
          _microSign * params.microAmp * (1 + 0.3 * _eventRng.nextDouble());
      _nextMicroAt =
          _time +
          params.microMinS +
          _eventRng.nextDouble() * (params.microMaxS - params.microMinS);
    }
  }

  void _nextFixation() {
    if (_readFix < 0 || _readFix >= _readFixCount - 1) {
      // A new line: after the first, the eyes sweep back to its start.
      if (_readFix >= 0) {
        _readLine = (_readLine + 1) % params.readingLines;
      }
      _readFix = 0;
      _readFixCount = 3 + _eventRng.nextInt(2);
      _readWidth =
          (_readFixCount == 3 ? params.lineWidth3 : params.lineWidth4) +
          (_eventRng.nextDouble() - 0.5) * 0.02;
      _readStart = params.lineStart + (_eventRng.nextDouble() - 0.5) * 0.02;
      _followYaw = _yawAxis.to.sign * params.lineFollow * _readLine;
    } else {
      _readFix++;
    }
    _sacGoalYaw = _readStart + _readWidth * _readFix / (_readFixCount - 1);
    _sacGoalPitch =
        params.lineFirstPitch -
        params.linePitchStep * _readLine +
        (_eventRng.nextDouble() * 2 - 1) * params.fixationPitchJitter;
    _nextReadAt =
        _time +
        params.fixationMinS +
        _eventRng.nextDouble() * (params.fixationMaxS - params.fixationMinS);
  }

  double _nodGap() =>
      params.nodMinGapS +
      _eventRng.nextDouble() * (params.nodMaxGapS - params.nodMinGapS);

  /// Pitch dip of the occasional micro-nod (only while idling).
  double _nod() {
    if (_driftWeight > 0.5 && _time >= _nextNodAt) {
      _nodStartedAt = _time;
      _nextNodAt = _time + _nodGap();
    }
    final double u = (_time - _nodStartedAt) / params.nodS;
    if (u < 0 || u >= 1) {
      return 0;
    }
    final double s = math.sin(math.pi * u);
    return -params.nodDepth * s * s;
  }

  /// The small dip that replaces the wind-up when returning to the user.
  double _returnDipNow() {
    final double u = (_time - _dipStartedAt - params.leadS) / params.returnDipS;
    if (u < 0 || u >= 1) {
      return 0;
    }
    final double s = math.sin(math.pi * u);
    return -params.returnDip * s * s;
  }

  HeadPose _compose() {
    if (_reduceMotion) {
      return HeadPose(
        yaw: _clamp1(_yawAxis.pos),
        pitch: _clamp1(_pitchAxis.pos),
        eyeLeadPitch: _clamp1(_eyePitch),
      );
    }
    double lead =
        params.gazeMax * _tanh((_eye - _yawAxis.pos) / params.gazeMax) + _sac;
    final double to = _yawAxis.to;
    if (to.abs() > 0.05) {
      // While looking away the eyes never swing to the other side (not even
      // during the head's overshoot).
      lead = to.sign * math.max(0, to.sign * lead);
    }
    final double head = _yawAxis.pos;
    if (head.abs() > params.farSideYaw && !_onUser) {
      // Far-iris safety: toward the camera side the lead stays small, except
      // on the return to the user.
      final double toFar = -head.sign * lead;
      if (toFar > params.farSideLeadMax) {
        lead = -head.sign * params.farSideLeadMax;
      }
    }
    return HeadPose(
      yaw: _clamp1(_yawAxis.pos),
      pitch: _clamp1(_pitchAxis.pos),
      hairLagYaw: _hairLag(
        _hairYaw - _yawAxis.pos + params.faceHairRoll * (_hairRoll - _faceRoll),
        1,
      ),
      hairLagPitch: _hairLag(
        params.hairPitchScale * (_hairPitch - _pitchAxis.pos) +
            (_hairNod - _faceNod),
        1,
      ),
      eyeLeadYaw: _clamp1(lead),
      eyeLeadPitch: _clamp1(_eyePitch),
    );
  }

  /// Hair offset x gain x [scale], softly limited to [HeadMotionParams.hairLagMax].
  double _hairLag(double offset, double scale) {
    final double max = params.hairLagMax;
    return max * _tanh(params.hairGain * scale * offset / max);
  }

  void _applyTarget(HeadTarget next) {
    _pending = null;
    _lastRetargetAt = _time;
    final bool returning = next.yaw == 0 && next.pitch == 0;
    final bool turns =
        (next.yaw - _yawAxis.to).abs() >= 1e-6 ||
        (next.pitch - _pitchAxis.to).abs() >= 1e-6;
    // Returning to the user: no counter-yaw wind-up, a small pitch dip.
    _yawAxis.retarget(
      next.yaw,
      _time,
      params,
      reduce: _reduceMotion,
      windUp: !returning,
    );
    _pitchAxis.retarget(
      next.pitch,
      _time,
      params,
      reduce: _reduceMotion,
      windUp: !returning,
    );
    if (returning && turns && !_reduceMotion) {
      _dipStartedAt = _time;
    }
    _driftDelay = returning ? params.returnDriftAfterS : params.driftAfterS;
    _reading = next.reading;
    _followYaw = 0;
    _readLine = 0;
    _readFix = -1;
    _nextReadAt = _time + params.readingDelayS;
    _sacGoalYaw = 0;
    _sacGoalPitch = 0;
    _nextMicroAt = _time + 0.3;
    _saccadeWanted = false;
  }

  void _updateDriftWeight(double h) {
    final bool steady = _time - _lastRetargetAt >= _driftDelay;
    if (steady) {
      _driftWeight = math.min(1, _driftWeight + h / params.driftFadeInS);
    } else {
      _driftWeight = math.max(0, _driftWeight - h / 0.2);
    }
  }

  /// Two slow sines ([freqA] and [freqB] Hz, 3-5 s periods) at 60 / 40 % of
  /// [amplitude].
  double _drift(int phaseIndex, double amplitude, double freqA, double freqB) {
    if (_driftWeight <= 0) {
      return 0;
    }
    final double a = math.sin(
      2 * math.pi * freqA * _time + _driftPhase[phaseIndex],
    );
    final double b = math.sin(
      2 * math.pi * freqB * _time + _driftPhase[phaseIndex + 1],
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

double _smootherstep(double u) {
  final double c = u.clamp(0.0, 1.0);
  return c * c * c * (c * (c * 6 - 15) + 10);
}

/// One head axis: a shaped travel, and the spring state that follows it.
class _Axis {
  _Axis({
    required this.leadS,
    required this.rampS,
    required this.rampMinS,
    required this.windUpAllowed,
  });

  final double leadS;
  final double rampS;
  final double rampMinS;
  final bool windUpAllowed;

  double pos = 0;
  double vel = 0;

  double from = 0;
  double to = 0;
  double _startedAt = double.negativeInfinity;
  bool _windUp = false;

  /// Starts a travel from the current shaped value to [value].
  void retarget(
    double value,
    double now,
    HeadMotionParams p, {
    required bool reduce,
    bool windUp = true,
  }) {
    if ((value - to).abs() < 1e-6) {
      return;
    }
    final double current = reduce ? to : shaped(now, p);
    from = current;
    to = value;
    _startedAt = now;
    _windUp =
        windUp && windUpAllowed && !reduce && (to - from).abs() > p.bigTurn;
    if (reduce) {
      from = to;
    }
  }

  void collapse() {
    from = to;
    _startedAt = double.negativeInfinity;
    _windUp = false;
  }

  double _ramp(double travel, HeadMotionParams p) {
    final double base =
        rampMinS + (rampS - rampMinS) * math.min(1, travel / p.rampFullTravel);
    return base + p.rampPerUnit * travel;
  }

  double _turn(double travel, HeadMotionParams p) =>
      p.turnS + p.rampPerUnit * travel;

  /// Shaped target. An out-turn is one continuous quintic ease with a short
  /// counter-turn and a built-in overshoot; everything else (returns, small
  /// travels, pitch) is a speed-capped smoothstep with overshoot, as in
  /// `shaped_target` of `rig_dsl.py`. Both settle back over `settleS`.
  double shaped(double now, HeadMotionParams p) {
    final double u = now - _startedAt - leadS;
    if (u < 0) {
      return from;
    }
    final double delta = to - from;
    final double travel = delta.abs();
    final double top = 1 + p.overshoot;
    final double ramp = _windUp ? _turn(travel, p) : _ramp(travel, p);
    if (u < ramp) {
      final double t = u / ramp;
      if (_windUp) {
        final double k = 1 - t;
        return from +
            delta *
                (top * _smootherstep(t) - 0.5 * p.windUpB * t * t * k * k * k);
      }
      return from + top * delta * _smoothstep(t);
    }
    if (u < ramp + p.settleS) {
      return to +
          p.overshoot * delta * (1 - _smoothstep((u - ramp) / p.settleS));
    }
    return to;
  }

  /// True while the shaped travel has not reached its end.
  bool moving(double now, HeadMotionParams p) {
    final double u = now - _startedAt - leadS;
    if (u < 0) {
      return _startedAt.isFinite;
    }
    final double travel = (to - from).abs();
    final double ramp = _windUp ? _turn(travel, p) : _ramp(travel, p);
    return u < ramp + p.settleS;
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
