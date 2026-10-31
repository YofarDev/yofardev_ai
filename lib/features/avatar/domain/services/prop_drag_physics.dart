import 'dart:collection' show UnmodifiableMapView;
import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../models/scene_drag.dart';

/// What a drag asks the stage to do besides moving the art (M9 ruling 9).
enum DragCue {
  /// A drag began: a selection click.
  start,

  /// A step of the drag: a selection click (a spin's 1/8 turn, a trail's
  /// 4th dot, an aim's 0.1, a poke's stir reversal).
  tick,

  /// A pull went past [PropDragPhysics.pullFire]: a light impact, the
  /// `click` foley and the scene's action (once per pull).
  pullFired,

  /// A stir faster than [PropDragPhysics.flareSpeed]: a light impact and the
  /// `flare` event (at most once per [PropDragPhysics.flareCooldown]).
  flare,
}

/// The physics of one scene drag handle (contract v12, M9 ruling 8): pure
/// and frame-ticked. Every input carries its time (`t`, from one injected
/// clock); [tick] advances the springs, the inertia and the fades. Points are
/// artboard px in the handle's rest frame (its plane's parallax offset
/// already taken off).
///
/// [values] holds the handle's `SceneVM` numbers (every one, by name); the
/// caller writes what changed, and only while [animating] or dragging.
/// [takeCues] hands over the cues raised since the last call.
///
/// With [reduceMotion] the springs settle at once on release and a spin
/// keeps no inertia; the cues are unchanged.
abstract class PropDragPhysics {
  PropDragPhysics._(this.handle, {this.reduceMotion = false})
    : _values = handle.defaults;

  /// The physics of [handle]'s kind.
  factory PropDragPhysics(SceneDragHandle handle, {bool reduceMotion = false}) {
    switch (handle.kind) {
      case DragKind.pull:
        return _PullPhysics(handle, reduceMotion: reduceMotion);
      case DragKind.poke:
        return _PokePhysics(handle, reduceMotion: reduceMotion);
      case DragKind.trail:
        return _TrailPhysics(handle, reduceMotion: reduceMotion);
      case DragKind.spin:
        return _SpinPhysics(handle, reduceMotion: reduceMotion);
      case DragKind.aim:
        return _AimPhysics(handle, reduceMotion: reduceMotion);
    }
  }

  // ------------------------------------------------------------ tuning
  /// pull: artboard px of finger travel for a full pull (value 1).
  static const double pullTravel = 100;

  /// pull: past this a pull fires its action, once per pull.
  static const double pullFire = 0.6;

  /// pull: the release spring's angular frequency (critically damped:
  /// settles in about 0.35 s, no overshoot).
  static const double pullSpringOmega = 18;

  /// poke: the tip at `pokeX` = `pokeY` = 0 (`gen_scenes.POKE_TIP`) and
  /// its travel at ±1 (`gen_scenes.POKE_RANGE`), artboard px: the tip sits
  /// under the finger, clamped to the box `pokeTip ± pokeRange`
  /// (88, 1050, 304, 1210). A test pins both to `gen_scenes.py`.
  static const Offset pokeTip = Offset(196, 1130);
  static const Offset pokeRange = Offset(108, 80);

  /// poke: the stick slides in over this when a drag starts.
  static const Duration pokeShowIn = Duration(milliseconds: 120);

  /// poke: the stick eases out over this on release.
  static const Duration pokeEaseOut = Duration(milliseconds: 450);

  /// poke: a stir faster than this (artboard px/s) fires `flare`.
  static const double flareSpeed = 900;

  /// poke: at most one flare per this.
  static const Duration flareCooldown = Duration(seconds: 3);

  /// poke: how far (px) the tip must come back along an axis to count as a
  /// stir reversal.
  static const double pokeReversal = 14;

  /// trail: the dots' spacing (artboard px).
  static const double trailSpacing = 22;

  /// trail: a selection click every this many dots.
  static const int trailDotsPerTick = 4;

  /// trail: a `bigWave` washes the dots away over this.
  static const Duration trailWash = Duration(milliseconds: 1200);

  /// trail: a new stroke clears an old fade back over this.
  static const Duration trailRestore = Duration(milliseconds: 150);

  /// trail: an old fade this far gone is dropped (not restored) by a new
  /// stroke.
  static const double trailDropFade = 0.9;

  /// trail: handles whose dots fade back on their own after the last stroke
  /// (the cafe's misted window).
  static const Map<String, Duration> trailRemist = <String, Duration>{
    'wipe': Duration(seconds: 20),
  };

  /// spin: artboard px of horizontal drag per revolution.
  static const double spinPxPerTurn = 900;

  /// spin: the inertia's time constant and how long it lasts at most.
  static const Duration spinTau = Duration(milliseconds: 300);
  static const Duration spinInertia = Duration(milliseconds: 1200);

  /// spin: the fastest fling (turns/s).
  static const double spinMaxSpeed = 4;

  /// spin: a selection click per this fraction of a turn.
  static const int spinTicksPerTurn = 8;

  /// aim: a selection click per this step of `aim`.
  static const int aimTicksPerUnit = 10;

  /// The window velocities are measured over.
  static const Duration velocityWindow = Duration(milliseconds: 100);

  /// A velocity needs samples spanning at least this: two events delivered
  /// in one frame (the pan's accept and its first update) say nothing about
  /// speed.
  static const Duration velocityMinSpan = Duration(milliseconds: 30);

  // ------------------------------------------------------------ state
  final SceneDragHandle handle;
  bool reduceMotion;

  final Map<String, double> _values;
  final List<DragCue> _cues = <DragCue>[];
  bool _dragging = false;

  /// The handle's numbers now, by name (every one of them).
  Map<String, double> get values =>
      UnmodifiableMapView<String, double>(_values);

  /// Whether a finger holds the handle.
  bool get dragging => _dragging;

  /// Whether something moves without the finger (a spring, the inertia, a
  /// fade): the caller keeps ticking while true.
  bool get animating;

  /// The cues raised since the last call.
  List<DragCue> takeCues() {
    final List<DragCue> cues = List<DragCue>.of(_cues);
    _cues.clear();
    return cues;
  }

  /// A finger lands on the handle at [p].
  void start(Offset p, Duration t) {
    _dragging = true;
    _cues.add(DragCue.start);
    _start(p, t);
  }

  /// The finger moved to [p].
  void move(Offset p, Duration t) {
    if (_dragging) {
      _move(p, t);
    }
  }

  /// The finger left (or the gesture was cancelled).
  void end(Duration t) {
    if (!_dragging) {
      return;
    }
    _dragging = false;
    _end(t);
  }

  /// Advances what moves on its own to [t].
  void tick(Duration t);

  /// A `bigWave` reached the handle (trail only: washes the dots away).
  void wash(Duration t) {}

  /// Stops everything where it is (no more motion, no cue).
  void halt() {
    _dragging = false;
    _halt();
  }

  /// A screen reader's custom action on the handle (M11 ruling 17): one
  /// drag's worth, all at [t], so no velocity is measured (no fling). A
  /// pull goes all the way down and lets go (its threshold action, the
  /// spring back); a spin turns [accessibleSpinStep]; an aim steps
  /// [accessibleAimStep] (back the other way at either end); a trail lays
  /// one short stroke; a poke stirs once and fires `flare` (cooldown
  /// permitting). Ignored while a finger holds the handle.
  void accessibilityAction(Duration t) {
    if (_dragging) {
      return;
    }
    _accessibilityAction(t);
  }

  /// spin: the turn one accessibility action gives (1/8 turn).
  static const double accessibleSpinStep = 1 / 8;

  /// aim: the step one accessibility action gives.
  static const double accessibleAimStep = 0.25;

  /// trail: the dots one accessibility stroke lays.
  static const int accessibleTrailDots = 5;

  void _accessibilityAction(Duration t);

  void _start(Offset p, Duration t);
  void _move(Offset p, Duration t);
  void _end(Duration t);
  void _halt();
}

/// Seconds between two times.
double _seconds(Duration from, Duration to) =>
    (to - from).inMicroseconds / Duration.microsecondsPerSecond;

double _easeOutCubic(double t) =>
    1 - math.pow(1 - t.clamp(0.0, 1.0), 3).toDouble();

/// Recent finger samples, for velocities.
class _Samples {
  static final double _minSpan =
      PropDragPhysics.velocityMinSpan.inMicroseconds /
      Duration.microsecondsPerSecond;

  final List<({Duration t, Offset p})> _samples = <({Duration t, Offset p})>[];

  void clear() => _samples.clear();

  void add(Offset p, Duration t) {
    _samples.add((t: t, p: p));
    final Duration oldest = t - PropDragPhysics.velocityWindow;
    // keep one sample at or before the window's start, so the window is full
    while (_samples.length > 2 && _samples[1].t <= oldest) {
      _samples.removeAt(0);
    }
  }

  /// The path length over the window per second (0 without a span).
  double speed(Duration now) {
    final List<({Duration t, Offset p})> recent = _recent(now);
    if (recent.length < 2) {
      return 0;
    }
    double path = 0;
    for (int i = 1; i < recent.length; i++) {
      path += (recent[i].p - recent[i - 1].p).distance;
    }
    final double span = _seconds(recent.first.t, recent.last.t);
    return span < _minSpan ? 0 : path / span;
  }

  /// The horizontal velocity over the window, px/s (0 if the finger rested).
  double velocityX(Duration now) {
    final List<({Duration t, Offset p})> recent = _recent(now);
    if (recent.length < 2) {
      return 0;
    }
    final double span = _seconds(recent.first.t, recent.last.t);
    return span < _minSpan ? 0 : (recent.last.p.dx - recent.first.p.dx) / span;
  }

  List<({Duration t, Offset p})> _recent(Duration now) {
    final Duration oldest = now - PropDragPhysics.velocityWindow;
    // the finger rested longer than the window: no velocity
    if (_samples.isEmpty || _samples.last.t < oldest) {
      return const <({Duration t, Offset p})>[];
    }
    final int first = _samples.lastIndexWhere(
      (({Duration t, Offset p}) s) => s.t <= oldest,
    );
    return _samples.sublist(math.max(0, first));
  }
}

// ---------------------------------------------------------------- pull
class _PullPhysics extends PropDragPhysics {
  _PullPhysics(super.handle, {super.reduceMotion}) : super._();

  late final String _name = handle.numbers.first.name;
  double _startY = 0;
  bool _fired = false;

  /// The spring: released at [_releaseValue] at [_releaseAt] (null: none).
  Duration? _releaseAt;
  double _releaseValue = 0;

  double get _value => _values[_name]!;

  @override
  bool get animating => _releaseAt != null;

  @override
  void _start(Offset p, Duration t) {
    // grabbed where the spring is: no jump
    _releaseAt = null;
    _startY = p.dy - _value * PropDragPhysics.pullTravel;
    _fired = false;
  }

  @override
  void _move(Offset p, Duration t) {
    final double value = ((p.dy - _startY) / PropDragPhysics.pullTravel).clamp(
      0.0,
      1.0,
    );
    _values[_name] = value;
    if (!_fired && value >= PropDragPhysics.pullFire) {
      _fired = true;
      _cues.add(DragCue.pullFired);
    }
  }

  @override
  void _end(Duration t) {
    if (reduceMotion || _value <= 0) {
      _values[_name] = 0;
      return;
    }
    _releaseAt = t;
    _releaseValue = _value;
  }

  @override
  void tick(Duration t) {
    final Duration? at = _releaseAt;
    if (at == null) {
      return;
    }
    final double s = math.max(0, _seconds(at, t));
    const double w = PropDragPhysics.pullSpringOmega;
    final double value = _releaseValue * (1 + w * s) * math.exp(-w * s);
    if (value < 0.001) {
      _values[_name] = 0;
      _releaseAt = null;
    } else {
      _values[_name] = value;
    }
  }

  @override
  void _halt() => _releaseAt = null;

  @override
  void _accessibilityAction(Duration t) {
    final Offset top = handle.rect.topCenter;
    start(top, t);
    move(top.translate(0, PropDragPhysics.pullTravel), t);
    end(t);
  }
}

// ---------------------------------------------------------------- poke
class _PokePhysics extends PropDragPhysics {
  _PokePhysics(super.handle, {super.reduceMotion}) : super._();

  late final String _show = handle.numbers[0].name;
  late final String _x = handle.numbers[1].name;
  late final String _y = handle.numbers[2].name;

  final _Samples _samples = _Samples();
  Duration? _lastFlare;

  /// The stick's slide: from [_fadeFrom] at [_fadeAt] toward 1 (dragging)
  /// or 0 (released); null when it rests.
  Duration? _fadeAt;
  double _fadeFrom = 0;

  /// The next move is the stroke's first: it re-origins the samples (the
  /// pan's accept carries the slop it waited for in the same instant).
  bool _fresh = false;

  /// Stir reversals, per axis: the direction (−1, 0, 1) and its extreme.
  final List<int> _dir = <int>[0, 0];
  final List<double> _extreme = <double>[0, 0];

  @override
  bool get animating => _fadeAt != null;

  @override
  void _start(Offset p, Duration t) {
    _fresh = true;
    _samples
      ..clear()
      ..add(p, t);
    _dir
      ..[0] = 0
      ..[1] = 0;
    _extreme
      ..[0] = p.dx
      ..[1] = p.dy;
    _aimTip(p);
    _slide(t);
  }

  @override
  void _move(Offset p, Duration t) {
    if (_fresh) {
      _fresh = false;
      _samples.clear();
    }
    _samples.add(p, t);
    _aimTip(p);
    _reversal(0, p.dx);
    _reversal(1, p.dy);
    final Duration? last = _lastFlare;
    if (_samples.speed(t) > PropDragPhysics.flareSpeed &&
        (last == null || t - last >= PropDragPhysics.flareCooldown)) {
      _lastFlare = t;
      _cues.add(DragCue.flare);
    }
  }

  @override
  void _end(Duration t) {
    _samples.clear();
    _slide(t);
  }

  void _slide(Duration t) {
    if (reduceMotion) {
      _fadeAt = null;
      _values[_show] = dragging ? 1 : 0;
      if (!dragging) {
        _rest();
      }
      return;
    }
    _fadeAt = t;
    _fadeFrom = _values[_show]!;
  }

  /// The tip under the finger, −1..1 across the tip box.
  void _aimTip(Offset p) {
    const Offset tip = PropDragPhysics.pokeTip;
    const Offset range = PropDragPhysics.pokeRange;
    _values[_x] = ((p.dx - tip.dx) / range.dx).clamp(-1.0, 1.0);
    _values[_y] = ((p.dy - tip.dy) / range.dy).clamp(-1.0, 1.0);
  }

  void _reversal(int axis, double v) {
    final int dir = _dir[axis];
    final double extreme = _extreme[axis];
    if (dir == 0) {
      if ((v - extreme).abs() >= PropDragPhysics.pokeReversal) {
        _dir[axis] = v > extreme ? 1 : -1;
        _extreme[axis] = v;
      }
      return;
    }
    if ((v - extreme) * dir > 0) {
      _extreme[axis] = v;
    } else if ((extreme - v) * dir >= PropDragPhysics.pokeReversal) {
      _dir[axis] = -dir;
      _extreme[axis] = v;
      _cues.add(DragCue.tick);
    }
  }

  void _rest() {
    _values[_show] = 0;
    _values[_x] = 0;
    _values[_y] = 0;
  }

  @override
  void tick(Duration t) {
    final Duration? at = _fadeAt;
    if (at == null) {
      return;
    }
    final double s = math.max(0, _seconds(at, t));
    if (dragging) {
      final double length =
          PropDragPhysics.pokeShowIn.inMicroseconds /
          Duration.microsecondsPerSecond;
      final double k = (s / length).clamp(0.0, 1.0);
      _values[_show] = _fadeFrom + (1 - _fadeFrom) * k;
      if (k >= 1) {
        _fadeAt = null;
      }
      return;
    }
    final double length =
        PropDragPhysics.pokeEaseOut.inMicroseconds /
        Duration.microsecondsPerSecond;
    final double k = s / length;
    if (k >= 1) {
      _fadeAt = null;
      _rest();
      return;
    }
    _values[_show] = _fadeFrom * (1 - _easeOutCubic(k));
  }

  @override
  void _halt() {
    _fadeAt = null;
    _samples.clear();
  }

  @override
  void _accessibilityAction(Duration t) {
    const Offset tip = PropDragPhysics.pokeTip;
    const Offset range = PropDragPhysics.pokeRange;
    start(tip, t);
    // one stir: right, left, back to the middle (two reversals)
    move(tip.translate(range.dx * 0.6, 0), t);
    move(tip.translate(-range.dx * 0.6, 0), t);
    move(tip, t);
    final Duration? last = _lastFlare;
    if (last == null || t - last >= PropDragPhysics.flareCooldown) {
      _lastFlare = t;
      _cues.add(DragCue.flare);
    }
    end(t);
  }
}

// ---------------------------------------------------------------- trail
class _TrailPhysics extends PropDragPhysics {
  _TrailPhysics(super.handle, {super.reduceMotion}) : super._();

  static const int _dots = SceneDrags.trailDots;

  /// Dots laid since the last clear (the ring index is `count % 16`).
  int _count = 0;
  Offset? _last;

  /// The fade: from [_fadeFrom] at [_fadeAt] to [_fadeTo] over [_fadeFor];
  /// reaching 1 clears the dots. Null when it rests.
  Duration? _fadeAt;
  double _fadeFrom = 0;
  double _fadeTo = 0;
  Duration _fadeFor = Duration.zero;

  late final Duration? _remist = PropDragPhysics.trailRemist[handle.id];

  double get _fade => _values['trailFade']!;

  @override
  bool get animating => _fadeAt != null;

  @override
  void _start(Offset p, Duration t) {
    // an old trail nearly gone is dropped; a fresher one clears back
    if (_count > 0 && _fade >= PropDragPhysics.trailDropFade) {
      _clear();
    }
    if (_count > 0 && _fade > 0) {
      _fadeTowards(0, PropDragPhysics.trailRestore, t);
    }
    _last = null;
    _lay(p);
  }

  @override
  void _move(Offset p, Duration t) => _lay(p);

  @override
  void _end(Duration t) {
    final Duration? remist = _remist;
    if (remist != null && _count > 0) {
      // the misted window: no motion to reduce, the mist comes back anyway
      _fadeTowards(1, remist, t, reducible: false);
    }
  }

  @override
  void wash(Duration t) {
    if (_count > 0) {
      _fadeTowards(1, PropDragPhysics.trailWash, t);
    }
  }

  /// Fades towards [to] over [length]; with [reduceMotion] a [reducible]
  /// fade (the wash, the restore) lands at once.
  void _fadeTowards(
    double to,
    Duration length,
    Duration t, {
    bool reducible = true,
  }) {
    if ((reduceMotion && reducible) || length <= Duration.zero) {
      _fadeAt = null;
      _setFade(to);
      return;
    }
    _fadeAt = t;
    _fadeFrom = _fade;
    _fadeTo = to;
    _fadeFor = length;
  }

  void _setFade(double fade) {
    _values['trailFade'] = fade;
    if (fade >= 1) {
      _clear();
    }
  }

  /// Lays dots from the last one towards [p], [PropDragPhysics.trailSpacing]
  /// apart (evenly, however far the finger jumped), inside the handle.
  void _lay(Offset p) {
    final Offset at = Offset(
      p.dx.clamp(handle.rect.left, handle.rect.right),
      p.dy.clamp(handle.rect.top, handle.rect.bottom),
    );
    final Offset? last = _last;
    if (last == null) {
      _dot(at);
      return;
    }
    Offset from = last;
    for (int i = 0; i < _dots; i++) {
      final Offset step = at - from;
      final double distance = step.distance;
      if (distance < PropDragPhysics.trailSpacing) {
        break;
      }
      from = from + step / distance * PropDragPhysics.trailSpacing;
      _dot(from);
    }
  }

  void _dot(Offset at) {
    final int slot = _count % _dots;
    _values['trailX$slot'] = at.dx;
    _values['trailY$slot'] = at.dy;
    _count++;
    _values['trailN'] = math.min(_count, _dots).toDouble();
    _last = at;
    // a dot on a cleared (or fully washed) sand shows
    if (_fade >= 1 && _fadeAt == null) {
      _values['trailFade'] = 0;
    }
    if (_count % PropDragPhysics.trailDotsPerTick == 0) {
      _cues.add(DragCue.tick);
    }
  }

  void _clear() {
    _count = 0;
    _last = null;
    _fadeAt = null;
    _values
      ..clear()
      ..addAll(handle.defaults);
  }

  @override
  void tick(Duration t) {
    final Duration? at = _fadeAt;
    if (at == null) {
      return;
    }
    final double k = (t - at).inMicroseconds / _fadeFor.inMicroseconds;
    if (k >= 1) {
      _fadeAt = null;
      _setFade(_fadeTo);
      return;
    }
    _values['trailFade'] = _fadeFrom + (_fadeTo - _fadeFrom) * math.max(0, k);
  }

  @override
  void _halt() => _fadeAt = null;

  /// Accessibility strokes laid so far: each one a row lower (it cycles).
  int _strokes = 0;

  @override
  void _accessibilityAction(Duration t) {
    final double length =
        PropDragPhysics.trailSpacing *
        (PropDragPhysics.accessibleTrailDots - 1);
    final double y =
        handle.rect.top + handle.rect.height * (0.2 + 0.15 * (_strokes % 5));
    final double x0 =
        handle.rect.left +
        math.max(0, (handle.rect.width - length) / 2).toDouble();
    _strokes++;
    start(Offset(x0, y), t);
    move(Offset(x0 + length, y), t);
    end(t);
  }
}

// ---------------------------------------------------------------- spin
class _SpinPhysics extends PropDragPhysics {
  _SpinPhysics(super.handle, {super.reduceMotion}) : super._();

  late final String _name = handle.numbers.first.name;
  final _Samples _samples = _Samples();
  bool _fresh = false;

  /// Turns so far, unwrapped (the 1/8 clicks count on it).
  double _turns = 0;
  double _lastX = 0;

  /// The inertia: released at [_flingAt] with [_flingTurns] and [_speed].
  Duration? _flingAt;
  double _flingTurns = 0;
  double _speed = 0;

  @override
  bool get animating => _flingAt != null;

  @override
  void _start(Offset p, Duration t) {
    _fresh = true;
    _flingAt = null;
    _lastX = p.dx;
    _samples
      ..clear()
      ..add(p, t);
  }

  @override
  void _move(Offset p, Duration t) {
    if (_fresh) {
      // the pan's accept and the slop it carried: no velocity from it
      _fresh = false;
      _samples.clear();
    }
    _samples.add(p, t);
    _turnTo(_turns + (p.dx - _lastX) / PropDragPhysics.spinPxPerTurn);
    _lastX = p.dx;
  }

  @override
  void _end(Duration t) {
    final double speed = (_samples.velocityX(t) / PropDragPhysics.spinPxPerTurn)
        .clamp(-PropDragPhysics.spinMaxSpeed, PropDragPhysics.spinMaxSpeed);
    _samples.clear();
    if (reduceMotion || speed.abs() < 0.01) {
      return;
    }
    _flingAt = t;
    _flingTurns = _turns;
    _speed = speed;
  }

  void _turnTo(double turns) {
    const int n = PropDragPhysics.spinTicksPerTurn;
    if ((turns * n).floor() != (_turns * n).floor()) {
      _cues.add(DragCue.tick);
    }
    _turns = turns;
    final double wrapped = turns - turns.floorToDouble();
    _values[_name] = wrapped >= 1 ? 0 : wrapped;
  }

  @override
  void tick(Duration t) {
    final Duration? at = _flingAt;
    if (at == null) {
      return;
    }
    final double tau =
        PropDragPhysics.spinTau.inMicroseconds / Duration.microsecondsPerSecond;
    final Duration elapsed = t - at;
    final bool done = elapsed >= PropDragPhysics.spinInertia;
    final double s = _seconds(at, done ? at + PropDragPhysics.spinInertia : t);
    _turnTo(_flingTurns + _speed * tau * (1 - math.exp(-math.max(0, s) / tau)));
    if (done) {
      _flingAt = null;
    }
  }

  @override
  void _halt() {
    _flingAt = null;
    _samples.clear();
  }

  @override
  void _accessibilityAction(Duration t) {
    final Offset at = handle.rect.center;
    start(at, t);
    move(
      at.translate(
        PropDragPhysics.spinPxPerTurn * PropDragPhysics.accessibleSpinStep,
        0,
      ),
      t,
    );
    end(t);
  }
}

// ---------------------------------------------------------------- aim
class _AimPhysics extends PropDragPhysics {
  _AimPhysics(super.handle, {super.reduceMotion}) : super._();

  late final String _name = handle.numbers.first.name;
  double _lastX = 0;

  @override
  bool get animating => false;

  @override
  void _start(Offset p, Duration t) => _lastX = p.dx;

  @override
  void _move(Offset p, Duration t) {
    final double before = _values[_name]!;
    final double after = (before + (p.dx - _lastX) / handle.rect.width).clamp(
      -1.0,
      1.0,
    );
    _lastX = p.dx;
    const int n = PropDragPhysics.aimTicksPerUnit;
    // a tiny epsilon so 0.3 (0.30000000000000004) does not click twice
    int step(double v) => (v * n + 1e-9).floor();
    if (step(after) != step(before)) {
      _cues.add(DragCue.tick);
    }
    _values[_name] = after;
  }

  @override
  void _end(Duration t) {}

  @override
  void tick(Duration t) {}

  @override
  void _halt() {}

  /// The accessibility step's direction: right until the end, then back.
  int _accessibleDir = 1;

  @override
  void _accessibilityAction(Duration t) {
    final double value = _values[_name]!;
    if (value + PropDragPhysics.accessibleAimStep * _accessibleDir > 1 + 1e-9 ||
        value + PropDragPhysics.accessibleAimStep * _accessibleDir <
            -1 - 1e-9) {
      _accessibleDir = -_accessibleDir;
    }
    final Offset at = handle.rect.center;
    start(at, t);
    move(
      at.translate(
        handle.rect.width * PropDragPhysics.accessibleAimStep * _accessibleDir,
        0,
      ),
      t,
    );
    end(t);
  }
}
