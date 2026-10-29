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
///   frame; at the release the jaw, the rounding and the spread follow the
///   blender's eased release ramp exactly (about 60 ms, never one frame) and
///   its pop is added on time. Elsewhere the jaw opens at most [jawSlew] per
///   second, a th holds the tongue up, and a tucked lower lip (f, v) keeps
///   the jaw at [tuckJawFloor] or more (the lips never meet on an f).
/// - **Breath**: the pre-roll ([SpeechPrerollEvent]) draws an eased breath
///   from [breathLead] before the audio, the lips parting with it (no press;
///   the jaw peaks at 0.10 150 ms before the audio and is 0.08 at it) into
///   the first phoneme unless it is a p/b/m; pauses inside the sentence are
///   breathed for too.
/// - **Prosody acting** (marks are known ahead, so motion anticipates): brow
///   beats on the strongest pitch peaks (at most one per 1.5 s, none in the
///   0.9 s before a question's rise), at most [browBeatMax], scaled by the
///   pitch slope and shaped as an anticipation dip, an eased rise, a 12 %
///   overshoot and a decay; nods on stressed syllables (at most one per
///   450 ms) whose depth follows the stress (0.4–1.0 of [nodDepthFor] at
///   full strength) with seeded jitter, a few of them swapped for, or
///   joined by, small roll accents of alternating side. A question lifts
///   both brows to [questionTop] on its final rising syllable (the only beat
///   that high), 80 ms ahead of the audio, and holds them with a head tilt
///   through the listening pause, the gaze locked on the camera
///   ([FaceFrame.gazeLock]) from 400 ms before the rise. Blinks in pauses;
///   each blink the performer fires dips the brows and lifts the cheeks a
///   little while the lids are shut.
/// - **Full stop**: when the voice ends the jaw, rounding and spread ease to
///   rest over 220 ms with a 12 % undershoot (the lips meet and press), the
///   lip corners relax and the head settles about 2° down; one blink follows
///   [postStopBlink] after it and a small gaze saccade
///   ([FaceFrame.saccadeSerial]) [postStopSaccade] after it.
/// - **Idle life** ([idle], off under [reduceMotion]): once the face is not
///   speaking, a slow irregular breath (a [idleBreathPeriod] cycle that
///   starts on an inhale when the idle begins), a micro drift of each lip
///   corner and a slow head roll and nod drift, all seeded sine sums.
///
/// [step] allocates nothing once the face is still: it works in fixed
/// buffers and returns the previous [FaceFrame] while nothing changed (never
/// while the idle runs).
class FacePerformer {
  FacePerformer({
    required Stream<PerformanceIntent> intents,
    required Stream<PlaybackEvent> playback,
    required Duration? Function() speechPosition,
    VisemeBlender blender = const VisemeBlender(),
    int seed = 7,
    this.idle = true,
  }) : _speechPosition = speechPosition,
       _blender = blender,
       _rng = math.Random(seed),
       _idlePhase = _phasesFor(seed) {
    _intentSub = intents.listen(_onIntent);
    _playbackSub = playback.listen(_onPlayback);
  }

  final Duration? Function() _speechPosition;
  final VisemeBlender _blender;
  final math.Random _rng;
  late final StreamSubscription<PerformanceIntent> _intentSub;
  late final StreamSubscription<PlaybackEvent> _playbackSub;

  /// Living idle while not speaking (breath, lip corners, head drift). Off,
  /// the face rests still and [isSettled] can report true.
  bool idle;

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
  static const double _browSettle = 0.06;
  static const double _rollSettle = 0.25;
  static const double _breathSettle = 0.4;

  /// The speech springs lag their target by about a third of their settle
  /// time; reading the timeline this far ahead puts the mouth on the audio.
  static const Duration _speechLead = Duration(milliseconds: 20);

  /// The brow spring lags about this much: beats are read this far ahead.
  static const double _browLead = 0.02;
  static const double _nodGap = 0.45;
  static const double _browGap = 1.5;

  /// Statement brow beats stay this far clear of a question's rise.
  static const double _questionClear = 0.9;

  /// The highest a statement brow beat lifts a brow (its overshoot
  /// included): only a question's rise goes past it.
  static const double browBeatMax = 0.3;

  /// Lowest jaw under a fully tucked lower lip (f, v): the rig draws the
  /// tuck only over parted lips.
  static const double tuckJawFloor = 0.11;

  /// One blink this long after the full stop, a gaze saccade at
  /// [postStopSaccade].
  static const double postStopBlink = 0.33;
  static const double postStopSaccade = 0.7;

  /// The idle breath's cycle (s).
  static const double idleBreathPeriod = 3.8;
  static const double _blinkGap = 1.2;
  static const double _blinkMaxInterval = 5.2;
  static const double _autoBlinkHold = 0.4;
  static const double _tail = 1.0;
  static const double _questionHold = 0.9;
  static const double _preClose = 0.1;

  /// Fastest the jaw opens outside a release burst (units per second): a
  /// short vowel cannot spike open for one frame.
  static const double jawSlew = 8;

  /// How far the jaw bursts open on the release into a span of [length]:
  /// 0.3 for the shortest vowel (50 ms), 0.3 more per 100 ms, all of it from
  /// about 280 ms (the release pop rides on top).
  static double releaseJawCap(Duration length) =>
      (0.3 + 3.0 * (length.inMicroseconds / 1e6 - 0.05)).clamp(0.3, 1.0);

  /// The breath before speaking starts this long before the audio.
  static const double breathLead = 0.35;

  /// Jaw of the parted lips at the audio's start, and its peak 150 ms before.
  static const double _partedJaw = 0.08;
  static const double _partedPeak = 0.10;

  /// Full-stop settle: the mouth eases to rest over [_settleS] with
  /// [_undershoot]; the head drop and the corner relax last [_settleTotal].
  static const double _settleS = 0.22;
  static const double _undershoot = 0.12;
  static const double _settleTotal = 1.7;

  /// The full-stop head drop: 2° of the ±15° pitch range.
  static const double _settleDrop = 2 / 15;

  /// Largest nod depth (pitch units, at stress strength 1); the seed jitters
  /// it ±[_nodJitter].
  static const double _nodMax = 0.55;
  static const double _nodJitter = 0.08;

  /// The nod's eased return to rest after the beat, ±10 % seeded.
  static const double _nodRelease = 0.2;

  /// Roll accent size (roll units, before the roll spring) and the share of
  /// stresses that get one.
  static const double _accentRoll = 0.14;
  static const double _accentChance = 0.35;

  /// Largest left/right split of a pitch-peak brow pulse (each side gets
  /// 1 ± up to this share of it).
  static const double _browSplit = 0.15;

  /// Both brows' level (before its 12 % overshoot) on a question's final
  /// rise: 0.8 for a flat rise to 0.95 for a steep one (0.875 unknown).
  static double questionTop(double? slope) =>
      0.8 + 0.15 * (slope ?? 0.5).clamp(0.0, 1.0);

  /// The question's brow peak leads the final rising syllable by this much.
  static const double _questionLead = 0.08;

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

  /// Per nod: its depth (0 = swapped for a roll accent), release and roll
  /// accent (-1, 0 or 1); per peak: its signed left/right split (+ = more on
  /// the viewer's left). Drawn from the seed when the timeline arrives.
  List<double> _nodDepth = const <double>[];
  List<double> _nodReleaseOf = const <double>[];
  List<double> _accent = const <double>[];
  List<double> _peakSide = const <double>[];

  /// Sign of the next roll accent (they alternate, across sentences too).
  double _accentSign = 1;

  /// End of the last sounding span (s, speech time): where the voice stops.
  double _voiceEnd = 0;

  /// The question's final rising syllable (s, speech time; -1: not a
  /// question) and the slope of its rise (null: unknown).
  double _questionAt = -1;
  double? _questionSlope;

  /// Clock of the full stop (-100: none yet for this sentence) and the mouth
  /// it eases from.
  double _settleStart = -100;
  bool _settleArmed = false;
  double _settleJaw = 0;
  double _settlePucker = 0;
  double _settleStretch = 0;
  double _settlePress = 0;

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
  double _prerollLead = breathLead;
  Viseme? _prerollOnset;
  bool _prerolled = false;
  bool _sawPosition = false;

  /// 0..1: the lips parted for the breath before speaking (no press), and
  /// the jaw they part by.
  double _parted = 0;
  double _partedJawNow = 0;

  /// How far a tucked lip holds the jaw open (the pre-close into a seal
  /// takes it back to 0).
  double _tuckOpen = 1;

  /// The gaze stays on the camera (a question's end).
  bool _gazeLock = false;
  int _saccadeSerial = 0;

  /// 0..1: the lip corners relaxing after the full stop.
  double _relax = 0;

  // — idle life —
  final Float64List _idlePhase;
  final _Spring _idleMix = _Spring();
  bool _idleWas = false;
  double _idleEpoch = 0;
  double _idleBreath = 0;
  double _idleRoll = 0;
  double _idleNod = 0;
  double _idleCornerL = 0;
  double _idleCornerR = 0;

  /// Reduce motion: no nods, head tilt, lift, visible breath or idle life
  /// (the mouth, brows and blinks still act).
  bool reduceMotion = false;
  bool _inhaling = false;
  bool _breathRising = false;
  double _clock = 0;
  double _lastBlink = -100;

  /// Clock of the last blink actually fired (not the spacing bookkeeping of
  /// [_lastBlink]).
  double _blinkAt = -100;
  int _blinkSerial = 0;
  bool _sealed = false;

  /// Inside a th span this frame: the tongue shows at least
  /// [VisemeBlender.thTongue].
  bool _thNow = false;

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
    _idleMix,
  ];

  /// The latest frame produced by [step].
  FaceFrame get frame => _frame;

  bool get _idleOn => idle && !reduceMotion;

  /// True when nothing moves: no speech, tail or full-stop settle, no idle
  /// life, every spring at its target and blinking handed back to the file.
  /// The [step] that first reports it lands every spring exactly on its
  /// target, so a view that stops ticking here rests on the pose itself, not
  /// up to 0.002 short of it.
  bool get isSettled {
    if (_idleOn ||
        _speaking ||
        _clock - _endClock < math.max(_tail, _autoBlinkHold) ||
        _clock - _settleStart < _settleTotal) {
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

  /// Nod depth (pitch units, before jitter) for a stress of [strength]
  /// (0-1): 0.4 of the deepest nod for the weakest stress, all of it for the
  /// strongest.
  static double nodDepthFor(double strength) =>
      _nodMax * _lerp(0.4, 1.0, strength.clamp(0.0, 1.0));

  /// Brow beat scale for a pitch peak's [slope] (0.7 flat .. 1.3 steep; 1
  /// when unknown).
  static double slopeGain(double? slope) =>
      slope == null ? 1 : 0.7 + 0.6 * slope.clamp(0.0, 1.0);

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
    bool opening = false;
    double releaseCap = 1;
    _tuckOpen = 1;
    bool th = false;
    _thNow = false;
    if (_speaking && tl != null && pos != null) {
      if (_settleArmed && _s(pos) >= _voiceEnd) {
        // the voice has stopped: settle from the mouth as it is now
        _startSettle();
      }
      final MouthBlend ahead = _blender.shapeAt(tl, pos + _speechLead);
      final MouthBlend now = _blender.shapeAt(tl, pos);
      // inside a release the blender's ramp is the motion: follow it at the
      // audio's own position, unsmoothed
      opening = now.opening < 1;
      speech = opening ? now.shape : ahead.shape;
      _sealed = ahead.sealed || now.sealed;
      // the pop rides on top, at the audio's own position
      releasing = opening || ahead.pop > 0 || now.pop > 0;
      _pop = now.pop;
      final double aheadPop = opening ? now.pop : ahead.pop;
      if (aheadPop > 0) {
        speech = speech.copyWith(jaw: speech.jaw - aheadPop);
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
          _tuckOpen = k;
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
      // rounds half way (an ou always rounds: it is the rounding)
      final double? loud = tl.energyAt(pos + _speechLead);
      if (loud != null) {
        _loudness += (loud - _loudness) * (1 - math.exp(-h / 0.1));
      }
      final double life = loud == null
          ? 1 + 0.07 * math.sin(2 * math.pi * 4.3 * _s(pos))
          : 0.55 + 0.55 * _loudness.clamp(0.0, 1.0);
      final double excitement = _lerp(0.95, 1.2, (_arousal + 1) / 2);
      final VisemeSpan? span = tl.spanAt(pos);
      th = span?.viseme == Viseme.th;
      if (releasing && span != null) {
        releaseCap = releaseJawCap(span.end - span.start);
      }
      // rounded sounds round fully however short (an ou, an oh, a French
      // sh); a sombre mood narrows the spread a little, never the opening
      final bool brief =
          span != null &&
          span.viseme != Viseme.ou &&
          span.viseme != Viseme.oh &&
          !(tl.roundedSh && span.viseme == Viseme.ch) &&
          span.end - span.start < const Duration(milliseconds: 100);
      speech = speech.copyWith(
        jaw: speech.jaw * excitement * life,
        stretch: _valence < -0.3 ? speech.stretch * 0.7 : speech.stretch,
        pucker: brief ? speech.pucker * 0.5 : speech.pucker,
      );
    }
    final double sinceStop = _clock - _settleStart;
    final bool settling = sinceStop >= 0 && sinceStop < _settleS;
    if (settling) {
      releasing = false;
      opening = false;
      _sealed = false;
      _pop = 0;
    }
    _afterStop(sinceStop, h);

    // prosody targets from the (virtual) speech position
    final double? posS = _prosodyPosition(pos);
    double innerTarget = 0;
    double outerTarget = 0;
    double innerSideTarget = 0;
    double outerSideTarget = 0;
    double rollTarget = 0;
    double liftTarget = 0;
    double nod = 0;
    bool gazeLock = false;
    if (tl != null && posS != null) {
      final double gain = _lerp(0.7, 1.3, (_arousal + 1) / 2);
      final double brow = posS + _browLead;
      double peak = 0;
      double amp = 0;
      double env = 0;
      double split = 0;
      for (int i = 0; i < _peaks.length; i++) {
        final ProsodyMark m = _peaks[i];
        // a weak peak still reads: half the beat, plus its strength
        final double a = (0.5 + 0.5 * m.strength) * slopeGain(m.slope);
        final double e = _peakEnvelope(brow - _s(m.at));
        if ((a * e).abs() > peak.abs()) {
          peak = a * e;
          amp = a;
          env = e;
          split = _peakSide[i];
        }
      }
      for (int i = 0; i < _nods.length; i++) {
        final ProsodyMark m = _nods[i];
        final double tau = posS - _s(m.at);
        if (_nodDepth[i] > 0) {
          nod += _nodCurve(tau, _nodDepth[i], m.strength, _nodReleaseOf[i]);
        }
        if (_accent[i] != 0) {
          // the roll spring lags ~80 ms: aim the accent that much early
          rollTarget += _accentRoll * _accent[i] * _gauss(tau, -0.04, 0.12);
        }
      }
      // a sombre mood lifts only the inner brows (an outer lift reads as
      // surprise and contradicts the sadness); a beat never tops
      // [browBeatMax], overshoot included
      final bool sombre = _valence < -0.3;
      const double cap = browBeatMax / 1.12;
      final double innerPulse =
          math.min((sombre ? 0.35 : 0.3) * gain * amp, cap) * env;
      final double outerPulse = sombre
          ? 0.0
          : math.min(0.45 * gain * amp, cap) * env;
      innerTarget += innerPulse;
      outerTarget += outerPulse;
      // the two brows never lift as one: one side takes a little more
      innerSideTarget = innerPulse * split;
      outerSideTarget = outerPulse * split;
      final bool asking =
          _questionAt >= 0 &&
          (_speaking || (_completed && _clock - _endClock < _questionHold));
      if (asking) {
        // the final rise: the brows peak 80 ms ahead of the rising syllable
        // and hold with the tilt through the listening pause (0.5 s after the
        // end), then ease back over 0.4 s
        final double tau = posS - _questionAt + _questionLead;
        final double hold = _speaking
            ? 1
            : 1 - _smoothstep((_clock - _endClock - 0.5) / 0.4);
        final double top = questionTop(_questionSlope);
        final double q = _questionRise(tau + _browLead) * hold;
        final double tilt = _smoothstep((tau + 0.08 + 0.3) / 0.3) * hold;
        innerTarget += math.max(0, top - _emotionTarget[_innerI]) * q;
        if (!sombre) {
          outerTarget += math.max(0, top - _emotionTarget[_outerI]) * q;
        }
        rollTarget += 0.9 * tilt;
        liftTarget = 0.12 * tilt;
        // the eyes stay on the listener through the last word and the tilt
        gazeLock = tau >= _questionLead - 0.4 && hold > 0.05;
      }
    }

    // the full stop: the head settles a little down, the corners relax
    _relax = 0;
    if (sinceStop >= 0 && sinceStop < _settleTotal) {
      final double out = 1 - _smoothstep((sinceStop - 0.8) / 0.9);
      nod -= _settleDrop * _smoothstep(sinceStop / 0.35) * out;
      _relax =
          _smoothstep(sinceStop / 0.3) *
          (1 - _smoothstep((sinceStop - 0.5) / 0.8));
    }

    // breath over the leading silence, released as speech starts
    _parted = 0;
    if (_speaking && tl != null && pos != null) {
      _breath = _breathAt(tl, _s(pos));
      _inhaling = _breathRising;
      _breathDecay.x = _breath;
      _breathDecay.v = 0;
      if (_prerolled && _prerollOnset != Viseme.pp) {
        // the lips stay parted into the first phoneme, then hand over
        _parted =
            1 - _smoothstep((_s(pos) - _s(tl.leadingSilence)) / _speechSettle);
      }
    }
    _partedJawNow = _partedJaw * _parted;
    _gazeLock = gazeLock;

    final double settle = _lerp(
      _calmSettle,
      _excitedSettle,
      (_arousal + 1) / 2,
    );
    final double wEmotion = _omega(settle);
    final double wSpeech = _omega(_speechSettle);
    final double wShape = releasing
        ? _omega(_releaseSettle)
        : _omega(_shapeSettle);
    final bool prerolling = !_speaking && _prerollActive;
    final bool idleWanted =
        _idleOn &&
        !_speaking &&
        !prerolling &&
        (_settleStart < -50 || sinceStop > 0.4);
    if (idleWanted && !_idleWas && _idleMix.x < 0.05) {
      _idleEpoch = _clock;
    }
    _idleWas = idleWanted;
    final double jawBefore = _jaw.x;
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
      // lip shape changes take ~3 frames (width never jumps in one frame),
      // except on a release, where they open with the jaw
      _pucker.step(speech.pucker, wShape, sub);
      _stretch.step(speech.stretch, wShape, sub);
      _press.step(speech.press, wSpeech, sub);
      _tuck.step(speech.lipTuck, wSpeech, sub);
      _tongue.step(speech.tongueUp, wSpeech, sub);
      _mix.step(_speaking || settling ? 1 : 0, _omega(_mixSettle), sub);
      _innerUp.step(innerTarget, _omega(_browSettle), sub);
      _outerUp.step(outerTarget, _omega(_browSettle), sub);
      _innerSide.step(innerSideTarget, _omega(_browSettle), sub);
      _outerSide.step(outerSideTarget, _omega(_browSettle), sub);
      _roll.step(rollTarget, _omega(_rollSettle), sub);
      _lift.step(liftTarget, _omega(_rollSettle), sub);
      _idleMix.step(idleWanted ? 1 : 0, _omega(idleWanted ? 0.8 : 0.2), sub);
      if (!_speaking) {
        _breathDecay.step(0, _omega(_breathSettle), sub);
      }
    }
    if (opening) {
      // the release ramp is already eased: no second smoothing (the springs
      // would make the first frame after a closure a jump)
      _jaw.land(speech.jaw);
      _pucker.land(speech.pucker);
      _stretch.land(speech.stretch);
    }
    if (!settling) {
      // a short vowel cannot spike the jaw open in one frame: a release
      // bursts open only as far as the vowel's length allows, then like any
      // other opening at [jawSlew]
      final double limit = releasing
          ? math.max(releaseCap, jawBefore + jawSlew * h)
          : jawBefore + jawSlew * h;
      if (_jaw.x > limit) {
        _jaw.x = limit;
        _jaw.v = math.min(_jaw.v, jawSlew);
      }
    }
    if (settling) {
      _settleMouth(sinceStop / _settleS);
    }
    if (th && _tongue.x < VisemeBlender.thTongue) {
      _tongue.land(VisemeBlender.thTongue);
    }
    _thNow = th;
    if (!_speaking) {
      _breath = _breathDecay.x;
      _inhaling = false;
      if (prerolling) {
        _preroll(_clock - _prerollStart);
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
    _stepIdle();

    if (isSettled) {
      _snapToTargets();
    }
    _frame = _compose(nod);
    return _frame;
  }

  bool get _prerollActive {
    final double since = _clock - _prerollStart;
    return since >= 0 && since < _prerollLead + 0.05;
  }

  /// The breath before speaking, [since] the pre-roll started: an eased
  /// inhale from [breathLead] before the audio (rising over ~250 ms, less
  /// for a shorter lead), the lips parted with it; a p/b/m onset closes them
  /// over the last 100 ms.
  void _preroll(double since) {
    final double lead = _prerollLead;
    final double from = math.max(0, lead - breathLead);
    if (since < from) {
      return;
    }
    final double rise = (0.72 * math.min(lead, breathLead)).clamp(0.08, 0.25);
    _breath = math.max(_breath, _smoothstep((since - from) / rise));
    _parted = _smoothstep((since - from) / 0.1);
    _partedJawNow = partedJaw(since - lead, lead);
    if (_prerollOnset == Viseme.pp) {
      final double close = _smoothstep((lead - since) / 0.1);
      _parted *= close;
      _partedJawNow *= close;
    }
    _breathDecay.x = _breath;
    _breathDecay.v = 0;
  }

  /// The jaw of the lips parting for the pre-roll breath, [toAudio] seconds
  /// from the audio (negative before it) with a pre-roll of [lead]: it rises
  /// from the start of the breath to 0.10 at 150 ms before the audio (an
  /// eased 200 ms for the full lead), then eases to 0.08 at the audio.
  static double partedJaw(double toAudio, double lead) {
    final double start = -math.min(lead, breathLead);
    final double peakAt = math.max(start + 0.05, -0.15);
    if (toAudio < peakAt) {
      return _partedPeak * _smoothstep((toAudio - start) / (peakAt - start));
    }
    return _partedPeak +
        (_partedJaw - _partedPeak) * _smoothstep((toAudio - peakAt) / -peakAt);
  }

  /// The full stop's afterlife, [sinceStop] into it ([h] the frame): one
  /// blink at [postStopBlink] (unless one just happened), a gaze saccade at
  /// [postStopSaccade].
  void _afterStop(double sinceStop, double h) {
    if (_settleStart < -50) {
      return;
    }
    bool crossed(double at) => sinceStop >= at && sinceStop - h < at;
    if (crossed(postStopBlink) && _clock - _blinkAt > 0.6) {
      _fireBlink();
    }
    if (crossed(postStopSaccade)) {
      _saccadeSerial++;
    }
  }

  void _fireBlink() {
    _lastBlink = _clock;
    _blinkAt = _clock;
    _blinkSerial++;
  }

  /// The brow dip and cheek lift of a blink (0-1), [tau] after it fired:
  /// in over 20-50 ms, held while the lids are shut (to 100 ms), released
  /// over 120 ms.
  static double blinkFollow(double tau) {
    if (tau < 0.02 || tau >= 0.22) {
      return 0;
    }
    if (tau < 0.05) {
      return _smoothstep((tau - 0.02) / 0.03);
    }
    if (tau < 0.1) {
      return 1;
    }
    return 1 - _smoothstep((tau - 0.1) / 0.12);
  }

  /// Arms the full-stop settle from the mouth as it is now.
  void _startSettle() {
    _settleArmed = false;
    _settleStart = _clock;
    _settleJaw = _jaw.x.clamp(0.0, 1.0);
    _settlePucker = _pucker.x.clamp(0.0, 1.0);
    _settleStretch = _stretch.x.clamp(0.0, 1.0);
    _settlePress = _press.x.clamp(0.0, 1.0);
  }

  /// The mouth at [u] (0-1) through the full-stop settle: jaw, rounding and
  /// spread ease from where the voice left them to rest, passing 12 % beyond
  /// it (the lips meet and press; rounding gives way to a hint of spread and
  /// back) before coming back to rest.
  void _settleMouth(double u) {
    final double c = _settleCurve(u);
    final double over = math.max(0, -c);
    final double on = math.max(0, c);
    _jaw.land(_settleJaw * on);
    _pucker.land(_settlePucker * on + _settleStretch * over);
    _stretch.land(_settleStretch * on + _settlePucker * over);
    _press.land(math.max(_settlePress * on, 2 * over));
  }

  /// 1 → -[_undershoot] over the first 65 %, eased, then back to 0.
  static double _settleCurve(double u) {
    if (u < 0.65) {
      return 1 - (1 + _undershoot) * _smoothstep(u / 0.65);
    }
    return -_undershoot * (1 - _smoothstep((u - 0.65) / 0.35));
  }

  /// The idle layer at the current clock, faded by [_idleMix].
  void _stepIdle() {
    final double w = _idleMix.x;
    if (w <= 1e-6) {
      _idleBreath = 0;
      _idleRoll = 0;
      _idleNod = 0;
      _idleCornerL = 0;
      _idleCornerR = 0;
      return;
    }
    final double t = _clock;
    final Float64List p = _idlePhase;
    double wave(double period, double phase) =>
        math.sin(2 * math.pi * t / period + phase);
    // a 3.8 s breath whose pace and depth wander a little, starting half
    // way into an inhale as the idle fades in: the first one peaks about
    // 1 s later (the face breathes right after speaking)
    final double since = t - _idleEpoch;
    final double wander =
        0.4 *
        (wave(17.3, p[0]) - math.sin(2 * math.pi * _idleEpoch / 17.3 + p[0]));
    final double cycle =
        2 * math.pi * since / idleBreathPeriod + math.pi / 2 + wander;
    _idleBreath =
        w * (0.3 + 0.05 * wave(23.1, p[2])) * (0.5 - 0.5 * math.cos(cycle));
    _idleCornerL =
        w * (0.015 + 0.02 * (0.6 * wave(5.3, p[3]) + 0.4 * wave(8.9, p[4])));
    _idleCornerR =
        w * (0.015 + 0.02 * (0.6 * wave(6.1, p[5]) + 0.4 * wave(9.7, p[6])));
    _idleRoll = w * 0.05 * (0.6 * wave(7.7, p[7]) + 0.4 * wave(12.9, p[8]));
    _idleNod = w * 0.03 * (0.6 * wave(9.4, p[9]) + 0.4 * wave(6.3, p[10]));
  }

  static Float64List _phasesFor(int seed) {
    final math.Random r = math.Random(seed * 7919 + 13);
    return Float64List.fromList(<double>[
      for (int i = 0; i < 11; i++) r.nextDouble() * 2 * math.pi,
    ]);
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
        _voiceEnd = _voiceEndOf(timeline);
        _settleArmed = true;
        _settleStart = -100;
        final ProsodyMark? rise = _finalRise(timeline);
        _questionAt = timeline.isQuestion
            ? _risingSyllable(timeline, rise)
            : -1;
        _questionSlope = rise?.slope;
        _nods = _spaced(timeline.marks, ProsodyMarkKind.stress, _nodGap);
        // statement beats: the strongest, 1.5 s apart, clear of the
        // question's rise (it is the one that stands out)
        _peaks = _spaced(
          <ProsodyMark>[
            for (final ProsodyMark m in timeline.marks)
              if (_questionAt < 0 ||
                  (!identical(m, rise) &&
                      _s(m.at) <= _questionAt - _questionClear))
                m,
          ],
          ProsodyMarkKind.pitchPeak,
          _browGap,
        );
        // the seeded variety, drawn once per sentence in a fixed order
        _peakSide = <double>[
          for (int i = 0; i < _peaks.length; i++) _drawSplit(),
        ];
        _drawNods();
        // a forced blink waits for a real interval into the sentence
        _lastBlink = math.max(_lastBlink, _clock - (_blinkMaxInterval - 2.5));
        _sawPosition = false;
        _prerolled = _clock - _prerollStart < _prerollLead + 0.3;
      case SpeechPrerollEvent(:final Duration lead, :final Viseme? onset):
        _prerollStart = _clock;
        _prerollLead = math.max(_s(lead), 0.08);
        _prerollOnset = onset;
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

  /// Per nod, in time order: its depth ([nodDepthFor] ±[_nodJitter]), its
  /// release (±10 %) and its roll accent. A weak stress (under 0.4) is
  /// swapped for a roll accent half the time; any other gets one too
  /// [_accentChance] of the time. Accents alternate sides.
  void _drawNods() {
    final int n = _nods.length;
    _nodDepth = List<double>.filled(n, 0);
    _nodReleaseOf = List<double>.filled(n, _nodRelease);
    _accent = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final double strength = _nods[i].strength;
      final double jitter = _nodJitter * (2 * _rng.nextDouble() - 1);
      final double release = 0.9 + 0.2 * _rng.nextDouble();
      final double roll = _rng.nextDouble();
      final bool swap = strength < 0.4 && roll < 0.5;
      _nodDepth[i] = swap ? 0 : nodDepthFor(strength) * (1 + jitter);
      _nodReleaseOf[i] = _nodRelease * release;
      if (swap || roll > 1 - _accentChance) {
        _accent[i] = _accentSign;
        _accentSign = -_accentSign;
      }
    }
  }

  void _complete() {
    if (_speaking) {
      _speaking = false;
      _completed = true;
      _endClock = _clock;
      if (_settleArmed) {
        _startSettle();
      }
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
    _settleArmed = false;
    _settleStart = -100;
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
      _fireBlink();
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

  /// End of the last sounding span (s), or the timeline's duration.
  static double _voiceEndOf(SpeechTimeline tl) {
    for (int i = tl.visemes.length - 1; i >= 0; i--) {
      if (tl.visemes[i].viseme != Viseme.sil) {
        return _s(tl.visemes[i].end);
      }
    }
    return _s(tl.duration);
  }

  /// The pitch peak a question rises on: the last one within the final
  /// 600 ms of the voice.
  static ProsodyMark? _finalRise(SpeechTimeline tl) {
    final double end = _voiceEndOf(tl);
    ProsodyMark? last;
    for (final ProsodyMark m in tl.marks) {
      final double at = _s(m.at);
      if (m.kind == ProsodyMarkKind.pitchPeak &&
          at >= end - 0.6 &&
          at <= end + 0.1) {
        last = m;
      }
    }
    return last;
  }

  /// Where a question's final rising syllable peaks (s): its pitch peak when
  /// there is one, else 60 % into the last vowel, no earlier than 200 ms
  /// before the voice ends.
  static double _risingSyllable(SpeechTimeline tl, ProsodyMark? rise) {
    if (rise != null) {
      return _s(rise.at);
    }
    final double end = _voiceEndOf(tl);
    for (int i = tl.visemes.length - 1; i >= 0; i--) {
      final VisemeSpan v = tl.visemes[i];
      if (_vowels.contains(v.viseme)) {
        final double start = _s(v.start);
        return math.max(start + 0.6 * (_s(v.end) - start), end - 0.2);
      }
    }
    return end - 0.2;
  }

  static const Set<Viseme> _vowels = <Viseme>{
    Viseme.aa,
    Viseme.e,
    Viseme.ih,
    Viseme.oh,
    Viseme.ou,
  };

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
    jaw = math.max(jaw, _partedJawNow);
    // a tucked lower lip keeps the lips apart (an f never draws a closed
    // bar)
    final double tuck = (_tuck.x * m).clamp(0.0, 1.0);
    jaw = math.max(
      jaw,
      tuckJawFloor * (tuck / 0.4).clamp(0.0, 1.0) * _tuckOpen,
    );
    jaw += _pop * m;
    double press = _lerp(au[_pressI], _press.x, m) * (1 - _parted);
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
    // a rounded vowel keeps its shape whatever the mood: the corners and the
    // mood's own spread give way
    final double round = (_pucker.x / 0.3).clamp(0.0, 1.0) * m;
    au[_stretchI] = _lerp(
      au[_stretchI],
      _stretch.x + 0.5 * au[_stretchI] * (1 - round),
      m,
    );
    final double pull = 1 - 0.8 * round;
    // an open jaw from a downturned mouth reads as a wince and the frown
    // pulls the opening into a slit: the frown halves as speech opens it
    final double depress =
        pull * (1 - 0.5 * _smoothstep((jaw - 0.05) / 0.2) * m);
    au[_pullI] *= pull;
    au[_depressI] *= depress;
    // the full stop relaxes the corners: a softer mouth, a lighter frown
    if (_valence >= -0.3) {
      au[_pullI] += 0.06 * _relax;
    } else {
      au[_depressI] *= 1 - 0.25 * _relax;
    }
    au[_innerI] += _innerUp.x;
    au[_outerI] += _outerUp.x;
    // a blink the performer fired: the brows dip, the cheeks lift
    final double follow = blinkFollow(_clock - _blinkAt);
    au[_browLowerI] += 0.1 * follow;
    au[_cheekI] += 0.1 * follow;

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
          v = v * pull + (side == 0 ? _idleCornerL : _idleCornerR);
        } else if (i == _sideDepressI) {
          v *= depress;
        }
        out[to + i] = v.clamp(-1.0, 1.0);
      }
    }
    out[_tuckO] = tuck;
    out[_tongueO] = math
        .max(_tongue.x * m, _thNow ? VisemeBlender.thTongue : 0.0)
        .clamp(0.0, 1.0);
    out[_breathO] = reduceMotion
        ? 0
        : math.max(_breath, _idleBreath).clamp(0.0, 1.0);
    out[_rollO] = reduceMotion ? 0 : (_roll.x + _idleRoll).clamp(-1.0, 1.0);
    out[_nodO] = reduceMotion ? 0 : (nod + _lift.x + _idleNod).clamp(-1.0, 1.0);
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
        _blinkSerial == _frame.blinkSerial &&
        _gazeLock == _frame.gazeLock &&
        _saccadeSerial == _frame.saccadeSerial) {
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
      gazeLock: _gazeLock,
      saccadeSerial: _saccadeSerial,
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

  /// Brow beat around a pitch peak, no plateau: an 18 % dip just before it
  /// (anticipation), an eased 150 ms rise to a 12 % overshoot at the peak,
  /// then a decay that gives the overshoot back within ~100 ms and eases out
  /// to the mood's own brows over 600 ms.
  static double _peakEnvelope(double tau) {
    if (tau < -0.32 || tau > 0.6) {
      return 0;
    }
    if (tau < -0.15) {
      final double s = math.sin(math.pi * (tau + 0.32) / 0.17);
      return -0.18 * s * s;
    }
    if (tau < 0) {
      return 1.12 * _smoothstep((tau + 0.15) / 0.15);
    }
    return _easeRelease(tau / 0.6) + 0.12 * math.exp(-tau / 0.05);
  }

  /// A question's final rise: an eased 300 ms rise to a 12 % overshoot at
  /// [tau] 0, settling to 1 over 150 ms and held.
  static double _questionRise(double tau) {
    if (tau < -0.3) {
      return 0;
    }
    if (tau < 0) {
      return 1.12 * _smoothstep((tau + 0.3) / 0.3);
    }
    return 1.12 - 0.12 * _smoothstep(tau / 0.15);
  }

  /// A nod on a stressed syllable (pitch units, down is negative) of [depth]
  /// (about 3-8 degrees: a nod that reads at phone size): an 18 %
  /// anticipation lift, the beat at the mark (a stronger stress dips more
  /// slowly), an eased-out return over [release] with a 12 % overshoot back
  /// up.
  static double _nodCurve(
    double tau,
    double depth,
    double strength,
    double release,
  ) {
    final double attack = 0.055 + 0.03 * strength.clamp(0.0, 1.0);
    final double beat = tau <= 0
        ? _gauss(tau, 0, attack)
        : _easeRelease(tau / release);
    return -depth *
        (beat -
            0.18 * _gauss(tau, -0.13, 0.05) -
            0.12 * _gauss(tau, release * 0.8, 0.06));
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
const int _browLowerI = 2;
const int _cheekI = 5;
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
