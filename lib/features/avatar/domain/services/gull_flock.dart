import 'dart:math' as math;

import '../models/npc_intent.dart';

/// The beach's gulls (moonshot M9 ruling 10): the second NPC slot's behaviour
/// tree, pure. An injected clock value per call, inputs as arguments,
/// output a [NpcIntent] for `npc2`, `npc2X` and `npc2Look`.
///
/// They start `away` (off the right edge, `npc2X` 1). After [calmToLand] of
/// calm they land (`move`, `npc2X` 1 → 0 over [landLength] facing left,
/// `npc2Look` [landLook], then `idle`: they peck on the sand). Anything that startles them ([startle]: a `seagulls` or
/// `bigWave` event, a poke of the `seagull` prop, the crab's react) or, while
/// they stand there, rain ≥ [rainAway] or the avatar speaking with arousal ≥
/// [excitedArousal] makes them `react` for [reactLength] and then fly off
/// (`move`, `npc2X` 0 → 1 over [fleeLength] facing right, `npc2Look`
/// [flyOffLook]) to `away`. The calm timer
/// restarts at every disturbance, and rain ≥ [rainAway] or an excited avatar
/// keep them away. Under reduce motion nothing flies: they appear and vanish
/// (after [jumpLength] away on landing).
class GullFlock {
  /// How long the landing flight takes, `npc2X` 1 → 0.
  static const Duration landLength = Duration(milliseconds: 2500);

  /// How long the flight off takes, `npc2X` 0 → 1.
  static const Duration fleeLength = Duration(milliseconds: 1500);

  /// The startled flap before they fly off.
  static const Duration reactLength = Duration(milliseconds: 600);

  /// Calm (no disturbance, no rain) before they land.
  static const Duration calmToLand = Duration(seconds: 12);

  /// A landing under reduce motion: away this long, then there.
  static const Duration jumpLength = Duration(milliseconds: 400);

  /// Rain at or above this keeps them away (and scares them off the sand).
  static const double rainAway = 0.5;

  /// The avatar speaking with at least this arousal scares them.
  static const double excitedArousal = 0.7;

  /// The facing written when they fly off (`npc2X` 0 → 1): the art faces
  /// right while `npc2Look` > 0.
  static const double flyOffLook = 1;

  /// The facing written when they land (`npc2X` 1 → 0): left while
  /// `npc2Look` ≤ 0.
  static const double landLook = -1;

  /// The `npc2X` of a landed flock.
  static const double landedX = 0;

  /// The `npc2X` of a flock off the frame's right edge.
  static const double awayX = 1;

  _Phase _phase = _Phase.away;

  /// When the phase began (for a timed phase, its exact start).
  DateTime _since = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _disturbedAt;
  bool _startled = false;
  bool _jump = false;
  double _from = awayX;
  Duration _length = Duration.zero;

  /// Rain or an excited avatar held the calm timer at the last evaluation.
  bool _blocked = false;

  /// Whether the next evaluation must follow a frame later (a flight).
  bool get animating => switch (_phase) {
    _Phase.landing || _Phase.fleeing => !_jump,
    _Phase.away || _Phase.landed || _Phase.startled => false,
  };

  /// The moment the current phase ends or begins the next one, null when
  /// only an input can change it.
  DateTime? get nextChange {
    final DateTime? disturbed = _disturbedAt;
    return switch (_phase) {
      _Phase.away =>
        _blocked || disturbed == null ? null : disturbed.add(calmToLand),
      _Phase.landing ||
      _Phase.fleeing ||
      _Phase.startled => _since.add(_length),
      _Phase.landed => null,
    };
  }

  /// Something startled them at the next evaluation: an event, a poke, the
  /// crab's react. It also restarts the calm timer.
  void startle(DateTime now) {
    _startled = true;
    _disturbedAt = now;
  }

  /// Forgets everything: away, calm timer unstarted.
  void reset() {
    _phase = _Phase.away;
    _disturbedAt = null;
    _startled = false;
    _jump = false;
    _blocked = false;
    _length = Duration.zero;
  }

  /// What the gulls do at [now]. [active] is false off the beach and at the
  /// low quality tier (they stay away and forget).
  NpcIntent evaluate(
    DateTime now, {
    required bool active,
    required double rain,
    required bool reduceMotion,
    required bool excited,
  }) {
    if (!active) {
      reset();
      return NpcIntent.away;
    }
    _disturbedAt ??= now;
    final bool raining = rain >= rainAway;
    final bool wasBlocked = _blocked;
    _blocked = raining || excited;
    if (_blocked || wasBlocked) {
      // held off while it lasts; the calm is counted from the moment it ends
      // (nothing is scheduled meanwhile, so the last evaluation may be old)
      _disturbedAt = now;
    }
    final bool scare = _startled || _blocked;
    _startled = false;
    if (scare) {
      _scare(now, reduceMotion: reduceMotion);
    }
    if (reduceMotion) {
      // no flight: a flight under way is over
      if (_phase == _Phase.landing && !_jump) {
        _phase = _Phase.landed;
      } else if (_phase == _Phase.fleeing) {
        _phase = _Phase.away;
      }
    }
    // a long gap between evaluations may cross several phases
    for (int i = 0; i < 4; i++) {
      if (!_advance(now, reduceMotion: reduceMotion)) {
        break;
      }
    }
    return _intent(now);
  }

  void _scare(DateTime now, {required bool reduceMotion}) {
    switch (_phase) {
      case _Phase.landed:
        if (reduceMotion) {
          _begin(_Phase.away, now);
        } else {
          _begin(_Phase.startled, now, length: reactLength);
        }
      case _Phase.landing:
        final double x = _x(now);
        if (_jump || x >= awayX - 1e-3) {
          _begin(_Phase.away, now);
        } else {
          // caught in the air: straight back out
          _begin(
            _Phase.fleeing,
            now,
            from: x,
            length: Duration(
              microseconds: (fleeLength.inMicroseconds * (awayX - x)).round(),
            ),
          );
        }
      case _Phase.away || _Phase.startled || _Phase.fleeing:
        break;
    }
  }

  /// Moves to the next phase when the current one is over; false when not.
  bool _advance(DateTime now, {required bool reduceMotion}) {
    final DateTime? change = nextChange;
    if (change == null || now.isBefore(change)) {
      return false;
    }
    switch (_phase) {
      case _Phase.away:
        // calm for long enough: land
        if (reduceMotion) {
          _begin(_Phase.landing, change, from: landedX, length: jumpLength);
          _jump = true;
        } else {
          _begin(_Phase.landing, change, from: awayX, length: landLength);
        }
      case _Phase.landing:
        _begin(_Phase.landed, change);
      case _Phase.startled:
        _begin(_Phase.fleeing, change, from: landedX, length: fleeLength);
      case _Phase.fleeing:
        _begin(_Phase.away, change);
      case _Phase.landed:
        return false;
    }
    return true;
  }

  void _begin(
    _Phase phase,
    DateTime at, {
    double from = awayX,
    Duration length = Duration.zero,
  }) {
    _phase = phase;
    _since = at;
    _from = from;
    _length = length;
    _jump = false;
  }

  double _progress(DateTime now) {
    final int total = _length.inMicroseconds;
    if (total <= 0) {
      return 1;
    }
    return (now.difference(_since).inMicroseconds / total).clamp(0.0, 1.0);
  }

  /// `npc2X` mid-flight, eased in and out (cubic) like the other NPCs' walks.
  double _x(DateTime now) {
    final double t = _progress(now);
    final double eased = t < 0.5
        ? 4 * t * t * t
        : 1 - math.pow(-2 * t + 2, 3) / 2;
    final double to = _phase == _Phase.landing ? landedX : awayX;
    return _from + (to - _from) * eased;
  }

  NpcIntent _intent(DateTime now) => switch (_phase) {
    _Phase.away => NpcIntent.away,
    _Phase.landing when _jump => const NpcIntent(
      npc: NpcState.away,
      npcX: landedX,
    ),
    _Phase.landing => NpcIntent(
      npc: NpcState.move,
      npcX: _x(now),
      npcLook: landLook,
    ),
    _Phase.landed => const NpcIntent(npc: NpcState.idle, npcX: landedX),
    _Phase.startled => const NpcIntent(npc: NpcState.react, npcX: landedX),
    _Phase.fleeing => NpcIntent(
      npc: NpcState.move,
      npcX: _x(now),
      npcLook: flyOffLook,
    ),
  };
}

enum _Phase { away, landing, landed, startled, fleeing }
