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
  static const double _nodGap = 0.45;

  /// Brow springs ring a little (about 12 % overshoot).
  static const double _browZeta = 0.55;
  static const double _browGap = 0.9;
  static const double _blinkGap = 1.2;
  static const double _blinkMaxInterval = 5.2;
  static const double _autoBlinkHold = 0.4;
  static const double _tail = 0.9;
  static const double _questionHold = 0.8;
  static const double _preClose = 0.1;

  // — emotion —
  List<double> _emotionTarget = List<double>.filled(_auCount, 0);
  double _arousal = 0;
  double _valence = 0;
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
  double _prerollStart = -100;
  double _prerollLead = 0.2;
  bool _prerolled = false;
  bool _sawPosition = false;

  /// Reduce motion: no nods, head tilt, lift or visible breath (the mouth,
  /// brows and blinks still act).
  bool reduceMotion = false;
  bool _inhaling = false;
  bool _breathRising = false;
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
      // ease the jaw shut into a coming seal instead of snapping it there
      final Duration? seal = _nextSealStart(tl, pos);
      if (!_sealed && seal != null) {
        final double ahead = _s(seal - pos);
        if (ahead < _preClose) {
          final double k = _smoothstep(ahead / _preClose);
          speech = speech.copyWith(
            jaw: speech.jaw * k,
            press: math.max(speech.press, VisemeBlender.sealPress * (1 - k)),
          );
        }
      }
      // a held vowel keeps a little life (about 4 Hz, +/- 7 %); an excited
      // mood speaks with a bigger jaw, a sombre one with less stretch
      final double energy = _lerp(0.95, 1.2, (_arousal + 1) / 2);
      speech = speech.copyWith(
        jaw:
            speech.jaw *
            energy *
            (1 + 0.07 * math.sin(2 * math.pi * 4.3 * _s(pos))),
        stretch: _valence < -0.3 ? speech.stretch * 0.5 : speech.stretch,
      );
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
        if (_valence >= -0.3) {
          outerTarget += 0.1 * m.strength * _gauss(tau, 0, 0.09);
        }
      }
      // a sombre mood lifts only the inner brows (an outer lift reads as
      // surprise and contradicts the sadness)
      final bool sombre = _valence < -0.3;
      innerTarget += (sombre ? 0.4 : 0.3) * gain * peak;
      outerTarget += (sombre ? 0 : 0.45) * gain * peak;
      final bool asking =
          tl.isQuestion &&
          (_speaking || (_completed && _clock - _endClock < _questionHold));
      if (asking) {
        // the tilt holds into the listening pause after the question
        final double q = _speaking
            ? _smoothstep((posS - (_s(tl.duration) - 0.4)) / 0.3)
            : 1;
        rollTarget = 0.9 * q;
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
      _inhaling = _breathRising;
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
      _innerUp.stepUnder(innerTarget, _omega(_overlaySettle), _browZeta, sub);
      _outerUp.stepUnder(outerTarget, _omega(_overlaySettle), _browZeta, sub);
      _roll.step(rollTarget, _omega(_rollSettle), sub);
      _lift.step(liftTarget, _omega(_rollSettle), sub);
      if (!_speaking) {
        _breathDecay.step(0, _omega(_breathSettle), sub);
      }
    }
    if (!_speaking) {
      _breath = _breathDecay.x;
      _inhaling = false;
      final double since = _clock - _prerollStart;
      if (since >= 0 && since < _prerollLead + 0.05) {
        // the breath before speaking: drawn over the pre-roll, lips parted,
        // closing again just before the voice
        final double inhale = math.max(0.08, _prerollLead - 0.06);
        _breath = math.max(_breath, _smoothstep(since / inhale));
        _inhaling = since < inhale;
        _breathDecay.x = _breath;
        _breathDecay.v = 0;
      }
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
    _valence = intent.emotion.valence;
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
        _sawPosition = false;
        _prerolled = _clock - _prerollStart < _prerollLead + 0.3;
      case SpeechPrerollEvent(:final Duration lead):
        _prerollStart = _clock;
        _prerollLead = math.max(_s(lead), 0.08);
      case AnimationCompletedEvent():
        _complete();
      // A sentence that ends calls stop() too (sometimes before the animation
      // noticed the end): only an interruption drops the end-of-sentence
      // acting.
      case SpeakingStoppedEvent(:final bool interrupted):
        if (interrupted) {
          _cut();
        } else {
          _complete();
        }
      default:
        break;
    }
  }

  void _complete() {
    if (_speaking) {
      _speaking = false;
      _completed = true;
      _endClock = _clock;
    }
  }

  void _cut() {
    if (_speaking || _completed) {
      _endClock = _clock;
    }
    _speaking = false;
    _completed = false;
    _timeline = null;
    _prerollStart = -100;
  }

  // — speech helpers —

  Duration? _currentPosition() {
    if (!_speaking) {
      return null;
    }
    final Duration? p = _speechPosition();
    if (p == null) {
      if (_sawPosition) {
        // the playback was cancelled under us (an interrupt is on its way):
        // relax now instead of holding the last mouth shape
        _cut();
        return null;
      }
      return _lastPos;
    }
    _sawPosition = true;
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
        // only where the voice dips: a blink mid-vowel reads as a glitch
        if (s.start > from &&
            s.start <= pos &&
            (s.viseme == Viseme.sil ||
                s.viseme == Viseme.nn ||
                s.weight < 0.3)) {
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

  /// The breath: over the leading silence, and again across every pause
  /// inside the sentence (a new phrase is breathed for). The inhale peaks
  /// 150 ms before the voice returns (the lips close again by the onset) and
  /// releases over 400 ms once it is back. Sets [_breathRising] while the
  /// breath is still being drawn (the lips part only then).
  double _breathAt(SpeechTimeline tl, double posS) {
    _breathRising = false;
    double b = 0;
    void phase(double start, double end, double amount) {
      final double peak = math.max(start + 0.06, end - 0.15);
      if (posS >= start && posS < peak) {
        final double v = amount * _smoothstep((posS - start) / (peak - start));
        if (v > b) {
          b = v;
          _breathRising = true;
        }
      } else if (posS >= peak && posS < end) {
        if (amount > b) {
          b = amount;
          _breathRising = false;
        }
      } else if (posS >= end && posS < end + 0.4) {
        b = math.max(b, amount * (1 - _smoothstep((posS - end) / 0.4)));
      }
    }

    final double lead = _s(tl.leadingSilence);
    if (_prerolled) {
      // drawn during the pre-roll: held over the leading silence
      phase(-_prerollLead, math.max(lead, 0.1), 1.0);
    } else {
      phase(0, math.max(lead, 0.15), lead < 0.12 ? 0.5 : 1.0);
    }
    for (final ProsodyMark m in tl.marks) {
      if (m.kind == ProsodyMarkKind.pause) {
        final double at = _s(m.at);
        phase(at, at + math.max(_s(m.length), 0.12), 0.8);
      }
    }
    return b;
  }

  /// Start of the first p/b/m span after [pos], if any.
  static Duration? _nextSealStart(SpeechTimeline tl, Duration pos) {
    for (final VisemeSpan s in tl.visemes) {
      if (s.start > pos && s.viseme == Viseme.pp) {
        return s.start;
      }
    }
    return null;
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
    if (_inhaling) {
      jaw = math.max(jaw, 0.12 * _breath);
    }
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
    // a rounded vowel keeps its shape whatever the mood: the corners give way
    final double round = (_pucker.x / 0.4).clamp(0.0, 1.0) * m;
    au[_pullI] *= 1 - 0.6 * round;
    au[_depressI] *= 1 - 0.6 * round;
    // an open jaw from a downturned mouth reads as a wince: the frown eases
    au[_depressI] *= 1 - 0.4 * ((jaw - 0.15) / 0.3).clamp(0.0, 1.0) * m;
    au[_innerI] += _innerUp.x;
    au[_outerI] += _outerUp.x;
    return FaceFrame(
      au: _fromList(au),
      lipTuck: (_tuck.x * m).clamp(0.0, 1.0),
      tongueUp: (_tongue.x * m).clamp(0.0, 1.0),
      breath: reduceMotion ? 0 : _breath.clamp(0.0, 1.0),
      roll: reduceMotion ? 0 : _roll.x.clamp(-1.0, 1.0),
      nodPitch: reduceMotion ? 0 : (nod + _lift.x).clamp(-1.0, 1.0),
      autoBlink: !(_speaking || _clock - _endClock < _autoBlinkHold),
      blinkSerial: _blinkSerial,
    );
  }

  // — curves —

  /// Brow beat around a pitch peak: a small dip 130 ms before it
  /// (anticipation), a rise over the last 80 ms, a 50 ms top, then a decay
  /// (time constant 220 ms) that follows the falling pitch instead of a
  /// held plateau; the underdamped brow spring adds the overshoot.
  static double _peakEnvelope(double tau) {
    if (tau < -0.2 || tau > 0.9) {
      return 0;
    }
    final double dip = -0.12 * _gauss(tau, -0.13, 0.035);
    if (tau < -0.08) {
      return dip;
    }
    if (tau < 0) {
      return dip + _smoothstep((tau + 0.08) / 0.08);
    }
    if (tau <= 0.05) {
      return 1;
    }
    return math.exp(-(tau - 0.05) / 0.22);
  }

  /// A nod on a stressed syllable (pitch units, down is negative): an 18 %
  /// anticipation lift, the beat at the mark, a 12 % overshoot back up.
  static double _nodCurve(double tau, double strength) {
    // 3-5 degrees of pitch: a nod that reads at phone size
    final double a = 0.2 + 0.15 * strength;
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

  /// An underdamped step (damping ratio [zeta] < 1): it overshoots, then
  /// settles. Semi-implicit Euler; [h] is a substep of at most 1/120 s.
  void stepUnder(double target, double omega, double zeta, double h) {
    v += (-2 * zeta * omega * v - omega * omega * (x - target)) * h;
    x += v * h;
  }

  bool isAt(double target) => (x - target).abs() < 0.002 && v.abs() < 0.01;
}

// ActionUnits field order (matches `AvatarRiveContract.actionUnitProps`).
const int _auCount = 14;
const int _innerI = 0;
const int _outerI = 1;
const int _pullI = 7;
const int _depressI = 8;
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
