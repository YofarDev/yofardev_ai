import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../../core/models/performance/performance.dart';
import '../../../talking/talking.dart';
import '../models/face_frame.dart';
import '../models/performance_intent.dart';
import 'viseme_blender.dart';

/// Turns the director's emotion and the speech timeline into one
/// [FaceFrame] per rendered frame (contract v6 face rig).
///
/// Pull-based like `HeadMotionSolver`: the avatar view calls [step] from its
/// frame ticker. Everything is deterministic for a given input sequence and
/// [seed] (the only source of the acting's variety).
///
/// - **Emotion**: each action unit and each per-side offset follows a
///   critically damped spring toward `actionUnitsForEmotion` /
///   `sidesForEmotion` of the intent's emotion; higher arousal settles faster
///   (0.55 s calm, 0.28 s excited). Springs move straight through AU space, so
///   a mood change never detours through another expression.
/// - **Speech** (from `SpeechTimelineEvent` to completion or stop): the
///   [VisemeBlender] shape at the playback position drives fast springs for
///   the mouth. Speech wins the jaw and the lip seal; emotion keeps corners,
///   cheeks, brows and lids. Inside a p/b/m span the jaw is written 0 that very
///   frame; at the release the jaw bursts open on a fast spring and the
///   blender's pop is added on time, after the spring.
/// - **Prosody acting** (marks are known ahead, so motion anticipates): brow
///   lifts on the strongest pitch peaks (0.9 s apart), split unevenly between
///   the two sides; nods on stressed syllables (at most one per 450 ms), deeper
///   for stronger stresses with a little seeded jitter; both release with an
///   ease-out. A head tilt and lifted brows at the end of a question, blinks
///   in pauses, a breath over the leading silence and a small settle at the
///   full stop.
///
/// [step] allocates nothing once the face is still: it works in fixed
/// buffers and returns the previous [FaceFrame] while nothing changed.
class FacePerformer {
  FacePerformer({
    required Stream<PerformanceIntent> intents,
    required Stream<PlaybackEvent> playback,
    required Duration? Function() speechPosition,
    VisemeBlender blender = const VisemeBlender(),
    int seed = 7,
  }) : _speechPosition = speechPosition,
       _blender = blender,
       _rng = math.Random(seed) {
    _intentSub = intents.listen(_onIntent);
    _playbackSub = playback.listen(_onPlayback);
  }

  final Duration? Function() _speechPosition;
  final VisemeBlender _blender;
  final math.Random _rng;
  late final StreamSubscription<PerformanceIntent> _intentSub;
  late final StreamSubscription<PlaybackEvent> _playbackSub;

  // — tuning (seconds unless noted) —
  static const double _maxDt = 0.1;
  static const double _substep = 1 / 120;
  static const double _calmSettle = 0.55;
  static const double _excitedSettle = 0.28;
  static const double _speechSettle = 0.06;

  /// The jaw spring right after a closure: the lips burst open.
  static const double _releaseSettle = 0.025;
  static const double _shapeSettle = 0.12;
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
  static const double _tail = 1.0;
  static const double _questionHold = 0.9;
  static const double _preClose = 0.1;

  /// Nod depth (pitch units) at stress strength 0.5; strength scales it
  /// 0.75–1.25×, the seed jitters it ±[_nodJitter].
  static const double _nodBase = 0.48;
  static const double _nodJitter = 0.1;

  /// The nod's eased return to rest after the beat.
  static const double _nodRelease = 0.22;

  /// Largest left/right split of a pitch-peak brow pulse (each side gets
  /// 1 ± up to this share of it).
  static const double _browSplit = 0.15;

  // — emotion —
  final Float64List _emotionTarget = Float64List(_auCount);
  final Float64List _sideTarget = Float64List(_sideCount * 2);
  double _arousal = 0;
  double _valence = 0;
  final List<_Spring> _emotion = List<_Spring>.generate(
    _auCount,
    (_) => _Spring(),
  );

  /// Left offsets at 0..6, right at 7..13 (`ActionUnitSides` field order).
  final List<_Spring> _sides = List<_Spring>.generate(
    _sideCount * 2,
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

  /// Per nod: its depth; per peak: its signed left/right split (+ = more on
  /// the viewer's left). Drawn from the seed when the timeline arrives.
  List<double> _nodDepth = const <double>[];
  List<double> _peakSide = const <double>[];
  final _Spring _jaw = _Spring();
  final _Spring _pucker = _Spring();
  final _Spring _stretch = _Spring();
  final _Spring _press = _Spring();
  final _Spring _tuck = _Spring();
  final _Spring _tongue = _Spring();
  final _Spring _mix = _Spring();

  /// The release pop (jaw) at the playback position, added after the spring.
  double _pop = 0;

  // — prosody overlays —
  final _Spring _innerUp = _Spring();
  final _Spring _outerUp = _Spring();

  /// The part of the brow pulse the viewer's left gets on top of the
  /// symmetric one (the right gets its negative).
  final _Spring _innerSide = _Spring();
  final _Spring _outerSide = _Spring();
  final _Spring _roll = _Spring();
  final _Spring _lift = _Spring();
  final _Spring _breathDecay = _Spring();
  double _breath = 0;
  double _loudness = 0;
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

  // — fixed output buffers (no per-frame allocation) —
  final Float64List _au = Float64List(_auCount);
  final Float64List _out = Float64List(_outCount);
  final Float64List _last = Float64List(_outCount);

  /// Springs that rest at 0 when the face is still (see [isSettled]).
  late final List<_Spring> _restingSprings = <_Spring>[
    _jaw,
    _pucker,
    _stretch,
    _press,
    _tuck,
    _tongue,
    _mix,
    _innerUp,
    _outerUp,
    _innerSide,
    _outerSide,
    _roll,
    _lift,
    _breathDecay,
  ];

  /// The latest frame produced by [step].
  FaceFrame get frame => _frame;

  /// True when nothing moves: no speech or tail, every spring at its target
  /// and blinking handed back to the file. The [step] that first reports it
  /// lands every spring exactly on its target, so a view that stops ticking
  /// here rests on the pose itself, not up to 0.002 short of it.
  bool get isSettled {
    if (_speaking || _clock - _endClock < math.max(_tail, _autoBlinkHold)) {
      return false;
    }
    for (int i = 0; i < _auCount; i++) {
      if (!_emotion[i].isAt(_emotionTarget[i])) {
        return false;
      }
    }
    for (int i = 0; i < _sides.length; i++) {
      if (!_sides[i].isAt(_sideTarget[i])) {
        return false;
      }
    }
    for (int i = 0; i < _restingSprings.length; i++) {
      if (!_restingSprings[i].isAt(0)) {
        return false;
      }
    }
    return true;
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
    _pop = 0;
    bool releasing = false;
    if (_speaking && tl != null && pos != null) {
      final MouthBlend ahead = _blender.shapeAt(tl, pos + _speechLead);
      final MouthBlend now = _blender.shapeAt(tl, pos);
      speech = ahead.shape;
      _sealed = ahead.sealed || now.sealed;
      // the pop rides on top of the spring, at the audio's own position
      releasing = ahead.pop > 0 || now.pop > 0;
      _pop = now.pop;
      if (ahead.pop > 0) {
        speech = speech.copyWith(jaw: speech.jaw - ahead.pop);
      }
      if (now.sealed && now.shape.press > speech.press) {
        // the read-ahead already sees the release: the lips stay compressed
        // until the audio gets there
        speech = speech.copyWith(press: now.shape.press);
      }
      // ease the jaw shut into a coming seal instead of snapping it there
      final Duration? seal = _nextSealStart(tl, pos);
      if (!_sealed && seal != null) {
        final double ahead = _s(seal - pos);
        if (ahead < _preClose) {
          final double k = _smoothstep(ahead / _preClose);
          speech = speech.copyWith(
            jaw: speech.jaw * k,
            press: math.max(
              speech.press,
              VisemeBlender.sealPressStart * (1 - k),
            ),
          );
        }
      }
      // the jaw follows the voice's loudness (smoothed ~100 ms), so a long
      // vowel keeps moving; an excited mood speaks with a bigger jaw, a
      // sombre one with less stretch; a vowel too short to round fully
      // rounds half way
      final double? loud = tl.energyAt(pos + _speechLead);
      if (loud != null) {
        _loudness += (loud - _loudness) * (1 - math.exp(-h / 0.1));
      }
      final double life = loud == null
          ? 1 + 0.07 * math.sin(2 * math.pi * 4.3 * _s(pos))
          : 0.55 + 0.55 * _loudness.clamp(0.0, 1.0);
      final double excitement = _lerp(0.95, 1.2, (_arousal + 1) / 2);
      final VisemeSpan? span = tl.spanAt(pos);
      final bool brief =
          span != null &&
          span.end - span.start < const Duration(milliseconds: 100);
      speech = speech.copyWith(
        jaw: speech.jaw * excitement * life,
        stretch: _valence < -0.3 ? speech.stretch * 0.5 : speech.stretch,
        pucker: brief ? speech.pucker * 0.5 : speech.pucker,
      );
    }

    // prosody targets from the (virtual) speech position
    final double? posS = _prosodyPosition(pos);
    double innerTarget = 0;
    double outerTarget = 0;
    double innerSideTarget = 0;
    double outerSideTarget = 0;
    double rollTarget = 0;
    double liftTarget = 0;
    double nod = 0;
    if (tl != null && posS != null) {
      final double gain = _lerp(0.7, 1.3, (_arousal + 1) / 2);
      double peak = 0;
      double split = 0;
      for (int i = 0; i < _peaks.length; i++) {
        final ProsodyMark m = _peaks[i];
        // a weak peak still reads: half the beat, plus its strength
        final double beat =
            (0.5 + 0.5 * m.strength) * _peakEnvelope(posS - _s(m.at));
        if (beat > peak) {
          peak = beat;
          split = _peakSide[i];
        }
      }
      for (int i = 0; i < _nods.length; i++) {
        final ProsodyMark m = _nods[i];
        final double tau = posS - _s(m.at);
        nod += _nodCurve(tau, _nodDepth[i]);
        if (_valence >= -0.3) {
          outerTarget += 0.1 * m.strength * _gauss(tau, 0, 0.09);
        }
      }
      // a sombre mood lifts only the inner brows (an outer lift reads as
      // surprise and contradicts the sadness)
      final bool sombre = _valence < -0.3;
      final double innerPulse = (sombre ? 0.35 : 0.3) * gain * peak;
      final double outerPulse = (sombre ? 0 : 0.45) * gain * peak;
      innerTarget += innerPulse;
      outerTarget += outerPulse;
      // the two brows never lift as one: one side takes a little more
      innerSideTarget = innerPulse * split;
      outerSideTarget = outerPulse * split;
      final bool asking =
          tl.isQuestion &&
          (_speaking || (_completed && _clock - _endClock < _questionHold));
      if (asking) {
        // the tilt starts on the last words, holds 0.5 s into the listening
        // pause, then eases back over 0.4 s
        final double since = _clock - _endClock;
        final double q = _speaking
            ? _smoothstep((posS - (_s(tl.duration) - 0.35)) / 0.3)
            : 1 - _smoothstep((since - 0.5) / 0.4);
        rollTarget = 0.9 * q;
        liftTarget = 0.12 * q;
        innerTarget += 0.3 * q;
        outerTarget += 0.3 * q;
      }
    }
    if (_completed && _clock - _endClock < _tail) {
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
      for (int i = 0; i < _sides.length; i++) {
        _sides[i].step(_sideTarget[i], wEmotion, sub);
      }
      _jaw.step(speech.jaw, releasing ? _omega(_releaseSettle) : wSpeech, sub);
      // lip shape changes take ~3 frames: width never jumps in one frame
      _pucker.step(speech.pucker, _omega(_shapeSettle), sub);
      _stretch.step(speech.stretch, _omega(_shapeSettle), sub);
      _press.step(speech.press, wSpeech, sub);
      _tuck.step(speech.lipTuck, wSpeech, sub);
      _tongue.step(speech.tongueUp, wSpeech, sub);
      _mix.step(_speaking ? 1 : 0, _omega(_mixSettle), sub);
      _innerUp.stepUnder(innerTarget, _omega(_overlaySettle), _browZeta, sub);
      _outerUp.stepUnder(outerTarget, _omega(_overlaySettle), _browZeta, sub);
      _innerSide.stepUnder(
        innerSideTarget,
        _omega(_overlaySettle),
        _browZeta,
        sub,
      );
      _outerSide.stepUnder(
        outerSideTarget,
        _omega(_overlaySettle),
        _browZeta,
        sub,
      );
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

    if (isSettled) {
      _snapToTargets();
    }
    _frame = _compose(nod);
    return _frame;
  }

  /// Puts every spring on its target, at rest ([isSettled] holds: what is
  /// left is under the 0.002 tolerance).
  void _snapToTargets() {
    for (int i = 0; i < _auCount; i++) {
      _emotion[i].land(_emotionTarget[i]);
    }
    for (int i = 0; i < _sides.length; i++) {
      _sides[i].land(_sideTarget[i]);
    }
    for (int i = 0; i < _restingSprings.length; i++) {
      _restingSprings[i].land(0);
    }
    _breath = 0;
  }

  /// Cancels the stream subscriptions (the streams belong to their owners).
  Future<void> dispose() async {
    await _intentSub.cancel();
    await _playbackSub.cancel();
  }

  // — events —

  void _onIntent(PerformanceIntent intent) {
    _writeAus(actionUnitsForEmotion(intent.emotion), _emotionTarget);
    final ({ActionUnitSides left, ActionUnitSides right}) sides =
        sidesForEmotion(intent.emotion);
    _writeSides(sides.left, _sideTarget, 0);
    _writeSides(sides.right, _sideTarget, _sideCount);
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
        // the seeded variety, drawn once per sentence in a fixed order
        _peakSide = <double>[
          for (int i = 0; i < _peaks.length; i++) _drawSplit(),
        ];
        _nodDepth = <double>[
          for (final ProsodyMark m in _nods) _drawNodDepth(m.strength),
        ];
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

  /// A brow pulse's signed split: 7.5–15 % to one side, the side seeded.
  double _drawSplit() {
    final double sign = _rng.nextBool() ? 1 : -1;
    return sign * _browSplit * (0.5 + 0.5 * _rng.nextDouble());
  }

  /// A nod's depth: 0.75–1.25 × [_nodBase] by stress strength, ±10 % jitter.
  double _drawNodDepth(double strength) {
    final double jitter = _nodJitter * (2 * _rng.nextDouble() - 1);
    return _nodBase *
        _lerp(0.75, 1.25, strength.clamp(0.0, 1.0)) *
        (1 + jitter);
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
      // drawn during the pre-roll: the exhale starts with the voice
      b = 1 - _smoothstep(posS / 0.45);
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
    // emotion AUs, then the speech merge in place (each AU is read before it
    // is written)
    final Float64List au = _au;
    for (int i = 0; i < _auCount; i++) {
      au[i] = _emotion[i].x;
    }
    final double m = _mix.x.clamp(0.0, 1.0);
    final double eJaw = au[_jawI];
    double jaw = _lerp(eJaw, math.max(_jaw.x, 0.35 * eJaw), m);
    if (_inhaling) {
      jaw = math.max(jaw, 0.12 * _breath);
    }
    jaw += _pop * m;
    double press = _lerp(au[_pressI], _press.x, m);
    if (_sealed) {
      jaw = 0;
      press = math.max(press, 0.6);
    }
    au[_jawI] = jaw;
    au[_pressI] = press;
    au[_puckerI] = _lerp(
      au[_puckerI],
      math.max(_pucker.x, 0.3 * au[_puckerI]),
      m,
    );
    au[_stretchI] = _lerp(au[_stretchI], _stretch.x + 0.5 * au[_stretchI], m);
    // a rounded vowel keeps its shape whatever the mood: the corners give way
    final double round = (_pucker.x / 0.3).clamp(0.0, 1.0) * m;
    final double pull = 1 - 0.8 * round;
    // an open jaw from a downturned mouth reads as a wince: the frown eases
    final double depress =
        pull * (1 - 0.4 * ((jaw - 0.15) / 0.3).clamp(0.0, 1.0) * m);
    au[_pullI] *= pull;
    au[_depressI] *= depress;
    au[_innerI] += _innerUp.x;
    au[_outerI] += _outerUp.x;

    final Float64List out = _out;
    for (int i = 0; i < _auCount; i++) {
      out[i] = au[i].clamp(0.0, 1.0);
    }
    for (int side = 0; side < 2; side++) {
      final int from = side * _sideCount;
      final int to = _auCount + from;
      final double sign = side == 0 ? 1 : -1;
      for (int i = 0; i < _sideCount; i++) {
        double v = _sides[from + i].x;
        if (i == _sideInnerI) {
          v += sign * _innerSide.x;
        } else if (i == _sideOuterI) {
          v += sign * _outerSide.x;
        } else if (i == _sidePullI) {
          v *= pull;
        } else if (i == _sideDepressI) {
          v *= depress;
        }
        out[to + i] = v.clamp(-1.0, 1.0);
      }
    }
    out[_tuckO] = (_tuck.x * m).clamp(0.0, 1.0);
    out[_tongueO] = (_tongue.x * m).clamp(0.0, 1.0);
    out[_breathO] = reduceMotion ? 0 : _breath.clamp(0.0, 1.0);
    out[_rollO] = reduceMotion ? 0 : _roll.x.clamp(-1.0, 1.0);
    out[_nodO] = reduceMotion ? 0 : (nod + _lift.x).clamp(-1.0, 1.0);
    final bool autoBlink = !(_speaking || _clock - _endClock < _autoBlinkHold);

    // a still face returns the previous frame: no allocation
    final bool auSame = _same(0, _auCount);
    final bool leftSame = _same(_auCount, _sideCount);
    final bool rightSame = _same(_auCount + _sideCount, _sideCount);
    final bool restSame = _same(_tuckO, _outCount - _tuckO);
    if (auSame &&
        leftSame &&
        rightSame &&
        restSame &&
        autoBlink == _frame.autoBlink &&
        _blinkSerial == _frame.blinkSerial) {
      return _frame;
    }
    _last.setAll(0, out);
    return FaceFrame(
      au: auSame ? _frame.au : _actionUnits(out),
      left: leftSame ? _frame.left : _sidesOf(out, _auCount),
      right: rightSame ? _frame.right : _sidesOf(out, _auCount + _sideCount),
      lipTuck: out[_tuckO],
      tongueUp: out[_tongueO],
      breath: out[_breathO],
      roll: out[_rollO],
      nodPitch: out[_nodO],
      autoBlink: autoBlink,
      blinkSerial: _blinkSerial,
    );
  }

  /// Whether [_out] equals the last frame's values over [from]..+[count].
  bool _same(int from, int count) {
    for (int i = from; i < from + count; i++) {
      if (_out[i] != _last[i]) {
        return false;
      }
    }
    return true;
  }

  // — curves —

  /// Brow beat around a pitch peak: an 18 % dip just before it
  /// (anticipation), an eased 120 ms attack, a 160 ms top, then an eased
  /// 400 ms return to the mood's own brows (the brow spring adds the
  /// overshoot).
  static double _peakEnvelope(double tau) {
    if (tau < -0.25 || tau > 0.56) {
      return 0;
    }
    final double dip = -0.18 * _gauss(tau, -0.17, 0.04);
    if (tau < -0.12) {
      return dip;
    }
    if (tau < 0) {
      return dip + _smoothstep((tau + 0.12) / 0.12);
    }
    if (tau <= 0.16) {
      return 1;
    }
    return _easeRelease((tau - 0.16) / 0.4);
  }

  /// A nod on a stressed syllable (pitch units, down is negative) of [depth]
  /// (about 3-5 degrees: a nod that reads at phone size): an 18 %
  /// anticipation lift, the beat at the mark, an eased-out return over
  /// [_nodRelease] with a 12 % overshoot back up.
  static double _nodCurve(double tau, double depth) {
    final double beat = tau <= 0
        ? _gauss(tau, 0, 0.07)
        : _easeRelease(tau / _nodRelease);
    return -depth *
        (beat -
            0.18 * _gauss(tau, -0.13, 0.05) -
            0.12 * _gauss(tau, 0.17, 0.06));
  }

  /// 1 → 0 over x in [0, 1] with an ease-out: it leaves smoothly (zero slope
  /// at 0), falls fastest a third of the way in, then decelerates into rest:
  /// `(1 - x)^3 (1 + 3x)`.
  static double _easeRelease(double x) {
    final double c = x.clamp(0.0, 1.0);
    final double r = 1 - c;
    return r * r * r * (1 + 3 * c);
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
    _snap(target);
  }

  /// An underdamped step (damping ratio [zeta] < 1): it overshoots, then
  /// settles. Semi-implicit Euler; [h] is a substep of at most 1/120 s.
  void stepUnder(double target, double omega, double zeta, double h) {
    v += (-2 * zeta * omega * v - omega * omega * (x - target)) * h;
    x += v * h;
    _snap(target);
  }

  bool isAt(double target) => (x - target).abs() < 0.002 && v.abs() < 0.01;

  /// Sets the spring at rest on [target].
  void land(double target) {
    x = target;
    v = 0;
  }

  /// Lands exactly on [target] once the remaining motion is invisible, so a
  /// still face produces bit-identical frames.
  void _snap(double target) {
    if ((x - target).abs() < 1e-6 && v.abs() < 1e-5) {
      x = target;
      v = 0;
    }
  }
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

// ActionUnitSides field order.
const int _sideCount = 7;
const int _sideInnerI = 0;
const int _sideOuterI = 1;
const int _sidePullI = 5;
const int _sideDepressI = 6;

// Output vector: the AUs, the left and right sides, then the scalars.
const int _tuckO = _auCount + 2 * _sideCount;
const int _tongueO = _tuckO + 1;
const int _breathO = _tuckO + 2;
const int _rollO = _tuckO + 3;
const int _nodO = _tuckO + 4;
const int _outCount = _tuckO + 5;

void _writeAus(ActionUnits a, Float64List to) {
  to[0] = a.browInnerUp;
  to[1] = a.browOuterUp;
  to[2] = a.browLower;
  to[3] = a.lidTighten;
  to[4] = a.upperLidRaise;
  to[5] = a.cheekRaise;
  to[6] = a.noseWrinkle;
  to[7] = a.lipCornerPull;
  to[8] = a.lipCornerDepress;
  to[9] = a.lipStretch;
  to[10] = a.lipPucker;
  to[11] = a.lipPress;
  to[12] = a.jawDrop;
  to[13] = a.dimpler;
}

void _writeSides(ActionUnitSides s, Float64List to, int at) {
  to[at] = s.browInnerUp;
  to[at + 1] = s.browOuterUp;
  to[at + 2] = s.browLower;
  to[at + 3] = s.lidTighten;
  to[at + 4] = s.cheekRaise;
  to[at + 5] = s.lipCornerPull;
  to[at + 6] = s.lipCornerDepress;
}

/// The (already clamped) AUs at the start of [v].
ActionUnits _actionUnits(Float64List v) => ActionUnits(
  browInnerUp: v[0],
  browOuterUp: v[1],
  browLower: v[2],
  lidTighten: v[3],
  upperLidRaise: v[4],
  cheekRaise: v[5],
  noseWrinkle: v[6],
  lipCornerPull: v[7],
  lipCornerDepress: v[8],
  lipStretch: v[9],
  lipPucker: v[10],
  lipPress: v[11],
  jawDrop: v[12],
  dimpler: v[13],
);

/// The (already clamped) side offsets at [at] in [v].
ActionUnitSides _sidesOf(Float64List v, int at) => ActionUnitSides(
  browInnerUp: v[at],
  browOuterUp: v[at + 1],
  browLower: v[at + 2],
  lidTighten: v[at + 3],
  cheekRaise: v[at + 4],
  lipCornerPull: v[at + 5],
  lipCornerDepress: v[at + 6],
);
