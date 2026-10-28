import 'dart:async';
import 'dart:math' as math;

import '../../../../core/models/performance/performance.dart';
import '../../../talking/talking.dart';
import '../models/face_frame.dart';
import '../models/performance_intent.dart';
import 'viseme_blender.dart';

/// Turns the director's emotion and the speech timeline into one
/// [FaceFrame] per rendered frame (contract v5 face rig).
///
/// Pull-based like `HeadMotionSolver`: the avatar view calls [step] from its
/// frame ticker. Everything is deterministic for a given input sequence.
///
/// - **Emotion**: each action unit follows a critically damped spring toward
///   `actionUnitsForEmotion(intent.emotion)`; higher arousal settles faster
///   (0.55 s calm, 0.28 s excited). Springs move straight through AU space, so
///   a mood change never detours through another expression.
/// - **Speech** (from `SpeechTimelineEvent` to completion or stop): the
///   [VisemeBlender] shape at the playback position drives fast springs for
///   the mouth. Speech wins the jaw and the lip seal; emotion keeps corners,
///   cheeks, brows and lids. Inside a p/b/m span the jaw is written 0 that very
///   frame.
/// - **Prosody acting** (marks are known ahead, so motion anticipates): brow
///   lifts on the strongest pitch peaks (0.9 s apart), nods on stressed
///   syllables (at most one per
///   600 ms), a head tilt and lifted brows at the end of a question, blinks in
///   pauses, a breath over the leading silence and a small settle at the full
///   stop.
class FacePerformer {
  FacePerformer({
    required Stream<PerformanceIntent> intents,
    required Stream<PlaybackEvent> playback,
    required Duration? Function() speechPosition,
    VisemeBlender blender = const VisemeBlender(),
  }) : _speechPosition = speechPosition,
       _blender = blender {
    _intentSub = intents.listen(_onIntent);
    _playbackSub = playback.listen(_onPlayback);
  }

  final Duration? Function() _speechPosition;
  final VisemeBlender _blender;
  late final StreamSubscription<PerformanceIntent> _intentSub;
  late final StreamSubscription<PlaybackEvent> _playbackSub;

  // — tuning (seconds unless noted) —
  static const double _maxDt = 0.1;
  static const double _substep = 1 / 120;
  static const double _calmSettle = 0.55;
  static const double _excitedSettle = 0.28;
  static const double _speechSettle = 0.06;
  static const double _mixSettle = 0.15;
  static const double _overlaySettle = 0.09;
  static const double _rollSettle = 0.25;
  static const double _breathSettle = 0.4;

  /// The speech springs lag their target by about a third of their settle
  /// time; reading the timeline this far ahead puts the mouth on the audio.
  static const Duration _speechLead = Duration(milliseconds: 20);
  static const double _nodGap = 0.6;
  static const double _browGap = 0.9;
  static const double _blinkGap = 1.2;
  static const double _blinkMaxInterval = 5.2;
  static const double _autoBlinkHold = 0.4;
  static const double _tail = 0.6;

  // — emotion —
  List<double> _emotionTarget = List<double>.filled(_auCount, 0);
  double _arousal = 0;
  final List<_Spring> _emotion = List<_Spring>.generate(
    _auCount,
    (_) => _Spring(),
  );

  // — speech —
  SpeechTimeline? _timeline;
  bool _speaking = false;
  bool _completed = false;
  Duration _lastPos = Duration.zero;
  double _endClock = -100;
  List<ProsodyMark> _nods = const <ProsodyMark>[];
  List<ProsodyMark> _peaks = const <ProsodyMark>[];
  final _Spring _jaw = _Spring();
  final _Spring _pucker = _Spring();
  final _Spring _stretch = _Spring();
  final _Spring _press = _Spring();
  final _Spring _tuck = _Spring();
  final _Spring _tongue = _Spring();
  final _Spring _mix = _Spring();

  // — prosody overlays —
  final _Spring _innerUp = _Spring();
  final _Spring _outerUp = _Spring();
  final _Spring _roll = _Spring();
  final _Spring _lift = _Spring();
  final _Spring _breathDecay = _Spring();
  double _breath = 0;
  double _clock = 0;
  double _lastBlink = -100;
  int _blinkSerial = 0;
  bool _sealed = false;

  FaceFrame _frame = FaceFrame.rest;

  /// The latest frame produced by [step].
  FaceFrame get frame => _frame;

  /// True when nothing moves: no speech or tail, every spring at its target
  /// and blinking handed back to the file.
  bool get isSettled {
    if (_speaking || _clock - _endClock < math.max(_tail, _autoBlinkHold)) {
      return false;
    }
    for (int i = 0; i < _auCount; i++) {
      if (!_emotion[i].isAt(_emotionTarget[i])) {
        return false;
      }
    }
    return <_Spring>[
      _jaw,
      _pucker,
      _stretch,
      _press,
      _tuck,
      _tongue,
      _mix,
      _innerUp,
      _outerUp,
      _roll,
      _lift,
      _breathDecay,
    ].every((_Spring s) => s.isAt(0));
  }

  /// Advances the performance by [dt] and returns the new frame.
  FaceFrame step(Duration dt) {
    final double h = (dt.inMicroseconds / 1e6).clamp(0.0, _maxDt);
    _clock += h;

    final Duration? pos = _currentPosition();
    final SpeechTimeline? tl = _timeline;
    _placeBlinks(pos, tl);

    // speech mouth target
    MouthShape speech = MouthShape.rest;
    _sealed = false;
    if (_speaking && tl != null && pos != null) {
      final MouthBlend ahead = _blender.shapeAt(tl, pos + _speechLead);
      speech = ahead.shape;
      _sealed = ahead.sealed || _blender.shapeAt(tl, pos).sealed;
    }

    // prosody targets from the (virtual) speech position
    final double? posS = _prosodyPosition(pos);
    double innerTarget = 0;
    double outerTarget = 0;
    double rollTarget = 0;
    double liftTarget = 0;
    double nod = 0;
    if (tl != null && posS != null) {
      final double gain = _lerp(0.7, 1.3, (_arousal + 1) / 2);
      double peak = 0;
      for (final ProsodyMark m in _peaks) {
        peak = math.max(peak, m.strength * _peakEnvelope(posS - _s(m.at)));
      }
      for (final ProsodyMark m in _nods) {
        final double tau = posS - _s(m.at);
        nod += _nodCurve(tau, m.strength);
        outerTarget += 0.1 * m.strength * _gauss(tau, 0, 0.09);
      }
      innerTarget += 0.2 * gain * peak;
      outerTarget += 0.3 * gain * peak;
      if (tl.isQuestion && _speaking) {
        final double q = _smoothstep((posS - (_s(tl.duration) - 0.4)) / 0.3);
        rollTarget = 0.35 * q;
        liftTarget = 0.12 * q;
        innerTarget += 0.3 * q;
        outerTarget += 0.3 * q;
      }
    }
    if (_completed) {
      // the full stop: a small settle down after the last word
      nod += -0.06 * _gauss(_clock - _endClock, 0.15, 0.1);
    }

    // breath over the leading silence, released as speech starts
    if (_speaking && tl != null && pos != null) {
      _breath = _breathAt(tl, _s(pos));
      _breathDecay.x = _breath;
      _breathDecay.v = 0;
    }

    final double settle = _lerp(
      _calmSettle,
      _excitedSettle,
      (_arousal + 1) / 2,
    );
    final double wEmotion = _omega(settle);
    final double wSpeech = _omega(_speechSettle);
    double remaining = h;
    while (remaining > 1e-9) {
      final double sub = math.min(remaining, _substep);
      remaining -= sub;
      for (int i = 0; i < _auCount; i++) {
        _emotion[i].step(_emotionTarget[i], wEmotion, sub);
      }
      _jaw.step(speech.jaw, wSpeech, sub);
      _pucker.step(speech.pucker, wSpeech, sub);
      _stretch.step(speech.stretch, wSpeech, sub);
      _press.step(speech.press, wSpeech, sub);
      _tuck.step(speech.lipTuck, wSpeech, sub);
      _tongue.step(speech.tongueUp, wSpeech, sub);
      _mix.step(_speaking ? 1 : 0, _omega(_mixSettle), sub);
      _innerUp.step(innerTarget, _omega(_overlaySettle), sub);
      _outerUp.step(outerTarget, _omega(_overlaySettle), sub);
      _roll.step(rollTarget, _omega(_rollSettle), sub);
      _lift.step(liftTarget, _omega(_rollSettle), sub);
      if (!_speaking) {
        _breathDecay.step(0, _omega(_breathSettle), sub);
      }
    }
    if (!_speaking) {
      _breath = _breathDecay.x;
    }
    if (_sealed) {
      // the lip seal never waits for a spring
      _jaw.x = 0;
      _jaw.v = 0;
      if (_press.x < 0.6) {
        _press.x = 0.6;
        _press.v = 0;
      }
    }

    _frame = _compose(nod);
    return _frame;
  }

  /// Cancels the stream subscriptions (the streams belong to their owners).
  Future<void> dispose() async {
    await _intentSub.cancel();
    await _playbackSub.cancel();
  }

  // — events —

  void _onIntent(PerformanceIntent intent) {
    _emotionTarget = _toList(actionUnitsForEmotion(intent.emotion));
    _arousal = intent.emotion.arousal;
  }

  void _onPlayback(PlaybackEvent event) {
    switch (event) {
      case SpeechTimelineEvent(:final SpeechTimeline timeline):
        _timeline = timeline;
        _speaking = true;
        _completed = false;
        _lastPos = Duration.zero;
        _nods = _spaced(timeline.marks, ProsodyMarkKind.stress, _nodGap);
        _peaks = _spaced(timeline.marks, ProsodyMarkKind.pitchPeak, _browGap);
        // a forced blink waits for a real interval into the sentence
        _lastBlink = math.max(_lastBlink, _clock - (_blinkMaxInterval - 2.5));
      case AnimationCompletedEvent():
        if (_speaking) {
          _speaking = false;
          _completed = true;
          _endClock = _clock;
        }
      case SpeakingStoppedEvent():
        if (_speaking || _completed) {
          _endClock = _clock;
        }
        _speaking = false;
        _completed = false;
        _timeline = null;
      default:
        break;
    }
  }

  // — speech helpers —

  Duration? _currentPosition() {
    if (!_speaking) {
      return null;
    }
    final Duration? p = _speechPosition();
    if (p == null) {
      return _lastPos;
    }
    // the clock never runs backwards (M1); keep that guarantee here too
    return p < _lastPos ? _lastPos : p;
  }

  /// Speech position for prosody; after a natural completion it keeps running
  /// for [_tail] so the last nod or brow lift finishes instead of snapping.
  double? _prosodyPosition(Duration? pos) {
    if (_speaking && pos != null) {
      return _s(pos);
    }
    if (_completed && _clock - _endClock < _tail) {
      return _s(_lastPos) + (_clock - _endClock);
    }
    return null;
  }

  void _placeBlinks(Duration? pos, SpeechTimeline? tl) {
    if (!_speaking || pos == null || tl == null) {
      return;
    }
    final Duration from = _lastPos;
    _lastPos = pos;
    if (pos <= from) {
      return;
    }
    bool blink = false;
    for (final ProsodyMark m in tl.marks) {
      if (m.kind != ProsodyMarkKind.pause) {
        continue;
      }
      final Duration at = m.at + const Duration(milliseconds: 40);
      if (at > from && at <= pos && _clock - _lastBlink >= _blinkGap) {
        blink = true;
      }
    }
    if (!blink && _clock - _lastBlink >= _blinkMaxInterval) {
      for (final VisemeSpan s in tl.visemes) {
        if (s.start > from && s.start <= pos && s.viseme != Viseme.pp) {
          blink = true;
          break;
        }
      }
    }
    if (blink) {
      _lastBlink = _clock;
      _blinkSerial++;
    }
  }

  double _breathAt(SpeechTimeline tl, double posS) {
    final double lead = _s(tl.leadingSilence);
    final double amount = lead < 0.12 ? 0.5 : 1.0;
    final double inhale = lead < 0.12 ? 0.15 : lead.clamp(0.12, 0.35);
    if (posS < inhale) {
      return amount * _smoothstep(posS / inhale);
    }
    return amount * (1 - _smoothstep((posS - inhale) / 0.4));
  }

  /// The strongest marks of [kind], at least [gap] seconds apart, in time
  /// order: acting beats stay sparse enough to read.
  static List<ProsodyMark> _spaced(
    List<ProsodyMark> marks,
    ProsodyMarkKind kind,
    double gap,
  ) {
    final List<ProsodyMark> byStrength =
        marks.where((ProsodyMark m) => m.kind == kind).toList()..sort(
          (ProsodyMark a, ProsodyMark b) => b.strength.compareTo(a.strength),
        );
    final List<ProsodyMark> out = <ProsodyMark>[];
    for (final ProsodyMark m in byStrength) {
      if (out.every((ProsodyMark o) => (_s(m.at) - _s(o.at)).abs() >= gap)) {
        out.add(m);
      }
    }
    return out..sort((ProsodyMark a, ProsodyMark b) => a.at.compareTo(b.at));
  }

  FaceFrame _compose(double nod) {
    final List<double> e = <double>[for (final _Spring s in _emotion) s.x];
    final double m = _mix.x.clamp(0.0, 1.0);
    double jaw = _lerp(e[_jawI], math.max(_jaw.x, 0.35 * e[_jawI]), m);
    jaw = math.max(jaw, 0.12 * _breath);
    double press = _lerp(e[_pressI], _press.x, m);
    if (_sealed) {
      jaw = 0;
      press = math.max(press, 0.6);
    }
    final List<double> au = List<double>.of(e);
    au[_jawI] = jaw;
    au[_pressI] = press;
    au[_puckerI] = _lerp(
      e[_puckerI],
      math.max(_pucker.x, 0.3 * e[_puckerI]),
      m,
    );
    au[_stretchI] = _lerp(e[_stretchI], _stretch.x + 0.5 * e[_stretchI], m);
    au[_innerI] += _innerUp.x;
    au[_outerI] += _outerUp.x;
    return FaceFrame(
      au: _fromList(au),
      lipTuck: (_tuck.x * m).clamp(0.0, 1.0),
      tongueUp: (_tongue.x * m).clamp(0.0, 1.0),
      breath: _breath.clamp(0.0, 1.0),
      roll: _roll.x.clamp(-1.0, 1.0),
      nodPitch: (nod + _lift.x).clamp(-1.0, 1.0),
      autoBlink: !(_speaking || _clock - _endClock < _autoBlinkHold),
      blinkSerial: _blinkSerial,
    );
  }

  // — curves —

  /// Brow lift around a pitch peak: rises over the 100 ms before it, holds
  /// 150 ms, releases over 250 ms.
  static double _peakEnvelope(double tau) {
    if (tau < -0.1 || tau > 0.4) {
      return 0;
    }
    if (tau < 0) {
      return _smoothstep((tau + 0.1) / 0.1);
    }
    if (tau <= 0.15) {
      return 1;
    }
    return 1 - _smoothstep((tau - 0.15) / 0.25);
  }

  /// A nod on a stressed syllable (pitch units, down is negative): an 18 %
  /// anticipation lift, the beat at the mark, a 12 % overshoot back up.
  static double _nodCurve(double tau, double strength) {
    final double a = 0.16 * strength;
    return -a *
        (_gauss(tau, 0, 0.07) -
            0.18 * _gauss(tau, -0.13, 0.05) -
            0.12 * _gauss(tau, 0.17, 0.06));
  }

  static double _gauss(double t, double mu, double sigma) {
    final double z = (t - mu) / sigma;
    return math.exp(-0.5 * z * z);
  }

  static double _smoothstep(double x) {
    final double c = x.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double _s(Duration d) => d.inMicroseconds / 1e6;

  /// Critically damped: within about 2 % of the target after [settle].
  static double _omega(double settle) => 5.8 / settle;
}

/// A critically damped spring, integrated exactly (stable at any step).
class _Spring {
  double x = 0;
  double v = 0;

  void step(double target, double omega, double h) {
    final double c1 = x - target;
    final double c2 = v + omega * c1;
    final double e = math.exp(-omega * h);
    x = target + (c1 + c2 * h) * e;
    v = (c2 - omega * (c1 + c2 * h)) * e;
  }

  bool isAt(double target) => (x - target).abs() < 0.002 && v.abs() < 0.01;
}

// ActionUnits field order (matches `AvatarRiveContract.actionUnitProps`).
const int _auCount = 14;
const int _innerI = 0;
const int _outerI = 1;
const int _stretchI = 9;
const int _puckerI = 10;
const int _pressI = 11;
const int _jawI = 12;

List<double> _toList(ActionUnits a) => <double>[
  a.browInnerUp,
  a.browOuterUp,
  a.browLower,
  a.lidTighten,
  a.upperLidRaise,
  a.cheekRaise,
  a.noseWrinkle,
  a.lipCornerPull,
  a.lipCornerDepress,
  a.lipStretch,
  a.lipPucker,
  a.lipPress,
  a.jawDrop,
  a.dimpler,
];

ActionUnits _fromList(List<double> v) {
  double c(int i) => v[i].clamp(0.0, 1.0);
  return ActionUnits(
    browInnerUp: c(0),
    browOuterUp: c(1),
    browLower: c(2),
    lidTighten: c(3),
    upperLidRaise: c(4),
    cheekRaise: c(5),
    noseWrinkle: c(6),
    lipCornerPull: c(7),
    lipCornerDepress: c(8),
    lipStretch: c(9),
    lipPucker: c(10),
    lipPress: c(11),
    jawDrop: c(12),
    dimpler: c(13),
  );
}
