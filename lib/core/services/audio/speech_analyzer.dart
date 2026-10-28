import 'dart:math' as math;
import 'dart:typed_data';

import '../../models/performance/speech_timeline.dart';
import '../../models/performance/viseme.dart';
import 'wav_pcm.dart';

/// Acoustic features of one 25 ms analysis frame.
class SpeechFrameFeatures {
  const SpeechFrameFeatures({
    required this.start,
    required this.rms,
    required this.db,
    required this.zcr,
    required this.bandShares,
    required this.periodicity,
    required this.f0,
  });

  /// Start of the frame in the audio.
  final Duration start;

  /// Linear RMS of the frame's samples.
  final double rms;

  /// RMS in dB relative to the sentence's 95th-percentile frame RMS.
  final double db;

  /// Zero-crossing rate (crossings per sample, 0-1).
  final double zcr;

  /// Energy shares of the bands 80-700, 700-1800, 1800-3500 and 3500-8000 Hz
  /// (sum 1, or all 0 when the frame has no energy in them).
  final List<double> bandShares;

  /// Peak of the normalised autocorrelation over 70-400 Hz (0-1).
  final double periodicity;

  /// Fundamental frequency in Hz when the frame is voiced, else null.
  final double? f0;

  bool get isVoiced => f0 != null;
}

/// On-device audio-to-viseme classifier and prosody detector.
///
/// Pure Dart and deterministic: 25 ms frames, a 512-point Hann FFT centred
/// on each frame for four band energies, the zero-crossing rate, and f0 from
/// a normalised autocorrelation. Each frame gets a viseme class, short lip
/// closures between voiced frames become `pp` when the sentence [text]
/// allows p/b/m there, classes are smoothed into spans of at least 50 ms,
/// and pitch peaks, stresses and pauses are marked.
class SpeechAnalyzer {
  const SpeechAnalyzer();

  /// Analysis hop (one frame).
  static const Duration frameDuration = Duration(milliseconds: 25);

  static const int _fftSize = 512;

  /// Frames this far under the sentence's p95 RMS are silence.
  static const double _silenceDb = -35;

  /// Absolute floor (about -74 dBFS): quieter frames are always silence.
  static const double _silenceFloor = 2e-4;

  /// Murmur (voice bar): low-band share of the tilted spectrum, and how far
  /// under the 200 ms neighbourhood peak.
  static const double _murmurLowShare = 0.85;
  static const double _murmurDipDb = 6;

  /// Unvoiced frames this far under the p95 can be a closure's tail.
  static const double _quietDb = -20;

  /// A sibilant frame at or under this level is a labiodental (f, v) when the
  /// text allows one there: /f/ is the same high-band noise as /s/, weaker.
  static const double _weakFricativeDb = -14.5;

  /// B2 / (B1 + B2) of the tilted spectrum at or above which a voiced frame
  /// is open (`aa`).
  static const double _openRatio = 0.35;

  /// A normalised autocorrelation peak at least this high is voiced.
  static const double _voicedPeriodicity = 0.45;

  /// Analysis rate of the f0 tracker (the input is decimated towards it).
  static const int _pitchRate = 8000;
  static const double _minF0 = 70;
  static const double _maxF0 = 400;

  static const Duration _minClosure = Duration(milliseconds: 30);
  static const Duration _maxClosure = Duration(milliseconds: 140);
  static const Duration _minSpan = Duration(milliseconds: 50);
  static const Duration _minPause = Duration(milliseconds: 180);
  static const Duration _pitchPeakGap = Duration(milliseconds: 300);
  static const Duration _stressGap = Duration(milliseconds: 600);
  static const Duration _questionWindow = Duration(milliseconds: 300);

  static const List<double> _bandEdges = <double>[80, 700, 1800, 3500, 8000];

  /// Per-frame acoustic features of [pcm] (exposed for tests and tools).
  List<SpeechFrameFeatures> features(WavPcm pcm) => _Analysis(pcm, null).frames;

  /// The viseme spans and prosody marks of [pcm]; [text] (the sentence that
  /// was synthesised) is a hint for p/b/m and f/v and decides [isQuestion].
  SpeechTimeline analyze(WavPcm pcm, {String? text}) {
    final _Analysis a = _Analysis(pcm, text);
    return a.timeline();
  }
}

/// One analysis run (all intermediate arrays live here).
class _Analysis {
  _Analysis(WavPcm pcm, String? text)
    : sampleRate = math.max(1, pcm.sampleRate),
      samples = _sanitize(pcm.samples),
      text = (text == null || text.trim().isEmpty) ? null : text.trim() {
    hop = math.max(
      1,
      (sampleRate * SpeechAnalyzer.frameDuration.inMicroseconds / 1e6).round(),
    );
    frameCount = (samples.length + hop - 1) ~/ hop;
    letters = this.text == null
        ? ''
        : this.text!.toLowerCase().replaceAll(_nonLetter, '');
    wordInitial = _wordInitials(this.text ?? '');
    frames = _computeFrames();
  }

  static final RegExp _nonLetter = RegExp(r'[^\p{L}]', unicode: true);

  final int sampleRate;
  final Float32List samples;
  final String? text;
  late final int hop;
  late final int frameCount;
  late final String letters;

  /// For each letter of [letters]: true when it starts a word.
  late final List<bool> wordInitial;

  static List<bool> _wordInitials(String text) {
    final List<bool> out = <bool>[];
    bool previousLetter = false;
    for (final String ch in text.split('')) {
      final bool letter = _nonLetter.allMatches(ch).isEmpty;
      if (letter) {
        out.add(!previousLetter);
      }
      previousLetter = letter;
    }
    return out;
  }

  late final List<SpeechFrameFeatures> frames;

  /// Sentence reference RMS (95th percentile of the frame RMS).
  double reference = 0;

  /// Non-finite samples (a corrupt float WAV) become 0, the rest is clamped
  /// to [-1, 1].
  static Float32List _sanitize(Float32List input) {
    if (input.every((double v) => v.isFinite && v.abs() <= 1)) {
      return input;
    }
    return Float32List.fromList(<double>[
      for (final double v in input) v.isFinite ? v.clamp(-1.0, 1.0) : 0,
    ]);
  }

  Duration timeOf(int sample) =>
      Duration(microseconds: sample * 1000000 ~/ sampleRate);

  Duration frameStart(int i) => timeOf(i * hop);

  Duration frameEnd(int i) => timeOf(math.min((i + 1) * hop, samples.length));

  Duration frameCentre(int i) =>
      timeOf(math.min(i * hop + hop ~/ 2, samples.length));

  Duration get duration => timeOf(samples.length);

  // ── Features ────────────────────────────────────────────────────────────

  List<SpeechFrameFeatures> _computeFrames() {
    if (frameCount == 0) {
      return const <SpeechFrameFeatures>[];
    }
    final Float64List rms = Float64List(frameCount);
    final Float64List zcr = Float64List(frameCount);
    for (int f = 0; f < frameCount; f++) {
      final int start = f * hop;
      final int end = math.min(start + hop, samples.length);
      double sum = 0;
      int crossings = 0;
      for (int i = start; i < end; i++) {
        final double x = samples[i];
        sum += x * x;
        if (i > start && (x >= 0) != (samples[i - 1] >= 0)) {
          crossings++;
        }
      }
      rms[f] = math.sqrt(sum / (end - start));
      zcr[f] = end - start > 1 ? crossings / (end - start - 1) : 0;
    }

    final List<double> sorted = rms.toList()..sort();
    reference = sorted[((sorted.length - 1) * 0.95).round()];
    if (reference < SpeechAnalyzer._silenceFloor) {
      reference = sorted.last;
    }

    final _Spectrum spectrum = _Spectrum(sampleRate);
    final _PitchTracker pitch = _PitchTracker(samples, sampleRate);
    final List<SpeechFrameFeatures> out = <SpeechFrameFeatures>[];
    for (int f = 0; f < frameCount; f++) {
      final bool audible = rms[f] >= SpeechAnalyzer._silenceFloor;
      final double db = audible && reference > 0
          ? 20 * math.log(rms[f] / reference) / math.ln10
          : -120;
      final int centre = f * hop + hop ~/ 2;
      final bool silent = !audible || db < SpeechAnalyzer._silenceDb;
      final List<double> shares = silent
          ? const <double>[0, 0, 0, 0]
          : spectrum.bandShares(samples, centre);
      double periodicity = 0;
      double? f0;
      if (!silent) {
        final (double, double?) p = pitch.at(centre);
        periodicity = p.$1;
        f0 = p.$2;
      }
      out.add(
        SpeechFrameFeatures(
          start: frameStart(f),
          rms: rms[f],
          db: db,
          zcr: zcr[f],
          bandShares: shares,
          periodicity: periodicity,
          f0: f0,
        ),
      );
    }
    return out;
  }

  bool isSilent(int f) => frames[f].db < SpeechAnalyzer._silenceDb;

  // ── Text hint ───────────────────────────────────────────────────────────

  /// Number of sounding (non-silent) frames before each frame index
  /// (length frameCount + 1): the clock the text's letters are spread on,
  /// so pauses do not shift the hint.
  late final Int32List _soundingBefore = () {
    final Int32List out = Int32List(frameCount + 1);
    for (int f = 0; f < frameCount; f++) {
      out[f + 1] = out[f] + (isSilent(f) ? 0 : 1);
    }
    return out;
  }();

  /// Whether a letter of [cls] sits near the frame range [from, to) once the
  /// letters of the text are spread evenly over the sounding frames: within
  /// +/- 8 % of the letter count (at least 1.5 letters). Null when there is
  /// no text.
  bool? hintAllows(String cls, int from, int to) {
    if (letters.isEmpty) {
      return null;
    }
    final int total = _soundingBefore[frameCount];
    if (total == 0) {
      return letters.split('').any(cls.contains);
    }
    final double fraction =
        (_soundingBefore[from] + _soundingBefore[to]) / 2 / total;
    final int n = letters.length;
    final double centre = fraction * n;
    final double radius = math.max(1.5, 0.08 * n);
    final int lo = math.max(0, (centre - radius).floor());
    final int hi = math.min(n - 1, (centre + radius).ceil() - 1);
    for (int k = lo; k <= hi; k++) {
      if (cls.contains(letters[k])) {
        return true;
      }
    }
    return false;
  }

  // ── Classification ──────────────────────────────────────────────────────

  static const String _lipLetters = 'pbm';
  static const String _labiodentalLetters = 'fv';
  static const String _sibilantLetters = 'szcxj';

  List<Viseme> classify() {
    final List<Viseme> raw = List<Viseme>.filled(frameCount, Viseme.sil);
    final List<bool> murmur = List<bool>.filled(frameCount, false);
    for (int f = 0; f < frameCount; f++) {
      final SpeechFrameFeatures x = frames[f];
      if (isSilent(f)) {
        continue;
      }
      final List<double> s = x.bandShares;
      if (_isMurmur(f)) {
        raw[f] = Viseme.nn;
        murmur[f] = true;
        continue;
      }
      // Sibilant noise, voiced (z) or not (s). A labiodental (f) is the same
      // high-band noise, only weaker: the text decides between them.
      if (x.zcr >= 0.25 && s[3] >= 0.45) {
        final bool allowsF = hintAllows(_labiodentalLetters, f, f + 1) ?? false;
        final bool allowsS = hintAllows(_sibilantLetters, f, f + 1) ?? true;
        raw[f] =
            allowsF && (!allowsS || x.db <= SpeechAnalyzer._weakFricativeDb)
            ? Viseme.ff
            : Viseme.ss;
        continue;
      }
      if (!x.isVoiced) {
        if (s[2] >= 0.4) {
          raw[f] = Viseme.ch;
        } else {
          final bool allowsF =
              hintAllows(_labiodentalLetters, f, f + 1) ?? false;
          raw[f] = allowsF ? Viseme.ff : Viseme.kk;
        }
        continue;
      }
      final double low = s[0] + s[1];
      final double r2 = low > 0 ? s[1] / low : 0;
      if (r2 >= SpeechAnalyzer._openRatio) {
        raw[f] = Viseme.aa;
      } else if (s[2] >= 0.2) {
        raw[f] = x.db >= -6 ? Viseme.e : Viseme.ih;
      } else if (r2 < 0.25 && s[2] < 0.1) {
        raw[f] = x.db >= -8 ? Viseme.oh : Viseme.ou;
      } else {
        raw[f] = Viseme.ih;
      }
    }

    final List<Viseme> smoothed = _modeFilter(raw);
    _markClosures(smoothed, murmur);
    _enforceLetters(smoothed, _lipLetters, Viseme.pp);
    _enforceLetters(smoothed, _labiodentalLetters, Viseme.ff);
    return smoothed;
  }

  /// The first sounding frame after a silence, within 3 frames before [lo] up
  /// to [hi]; -1 when the window has no voice onset.
  int _onsetNear(int lo, int hi) {
    for (int f = math.max(1, lo - 3); f <= hi && f < frameCount; f++) {
      if (isSilent(f - 1) && !isSilent(f)) {
        return f;
      }
    }
    return -1;
  }

  /// Every letter of [cls] in the text (a doubled letter counts once) gets a
  /// [target] span near where it is said: the letters are spread over the
  /// sounding frames, and when no [target] frame lies within +/- 2 % of the
  /// letter count (at least 0.9 letters) of the expected one, the two
  /// quietest sounding frames there become [target]. A nasal or a lip
  /// closure with no dip in the audio ("I'm") still closes the lips.
  void _enforceLetters(List<Viseme> classes, String cls, Viseme target) {
    final int total = _soundingBefore[frameCount];
    final int n = letters.length;
    if (n == 0 || total == 0) {
      return;
    }
    final List<int> sounding = <int>[
      for (int f = 0; f < frameCount; f++)
        if (!isSilent(f)) f,
    ];
    final double radius = math.max(0.9, 0.02 * n);
    for (int k = 0; k < n; k++) {
      if (!cls.contains(letters[k]) ||
          (k > 0 && cls.contains(letters[k - 1]))) {
        continue;
      }
      int frameAt(double letter) =>
          sounding[(letter / n * total).floor().clamp(0, total - 1)];
      final int lo = frameAt(math.max(0, k + 0.5 - radius));
      final int hi = frameAt(math.min(n - 0.001, k + 0.5 + radius));
      // A phrase that starts on this letter ("Maybe", after a pause): the
      // lips are already shut as the voice comes in.
      if (target == Viseme.pp && k < wordInitial.length && wordInitial[k]) {
        final int onset = _onsetNear(lo, hi);
        if (onset > 0) {
          for (int f = math.max(0, onset - 2); f <= onset; f++) {
            classes[f] = target;
          }
          continue;
        }
      }
      bool found = false;
      for (int f = lo; f <= hi && !found; f++) {
        found = classes[f] == target;
      }
      if (found) {
        continue;
      }
      int best = -1;
      for (int f = lo; f < hi; f++) {
        if (isSilent(f) || isSilent(f + 1)) {
          continue;
        }
        final double db = math.max(frames[f].db, frames[f + 1].db);
        if (best < 0 || db < math.max(frames[best].db, frames[best + 1].db)) {
          best = f;
        }
      }
      if (best >= 0) {
        classes[best] = target;
        classes[best + 1] = target;
      }
    }
  }

  /// A voice bar: energy only under 700 Hz, well under the neighbourhood
  /// (a lip or tongue closure with the voice running, or a nasal). Quiet
  /// unvoiced frames qualify too (a closure's tail before the burst).
  bool _isMurmur(int f) {
    final SpeechFrameFeatures x = frames[f];
    return (x.isVoiced || x.db < SpeechAnalyzer._quietDb) &&
        x.bandShares[0] >= SpeechAnalyzer._murmurLowShare &&
        x.db <= _neighbourhoodPeakDb(f) - SpeechAnalyzer._murmurDipDb;
  }

  /// Loudest frame within +/- 100 ms (a 200 ms neighbourhood).
  double _neighbourhoodPeakDb(int f) {
    double peak = -120;
    for (
      int k = math.max(0, f - 4);
      k <= math.min(frameCount - 1, f + 4);
      k++
    ) {
      peak = math.max(peak, frames[k].db);
    }
    return peak;
  }

  /// 3-frame median of categories: a lone frame whose two neighbours agree
  /// takes their class.
  List<Viseme> _modeFilter(List<Viseme> raw) {
    final List<Viseme> out = List<Viseme>.of(raw);
    for (int f = 1; f < raw.length - 1; f++) {
      if (raw[f - 1] == raw[f + 1] && raw[f] != raw[f - 1]) {
        out[f] = raw[f - 1];
      }
    }
    return out;
  }

  bool _isVoicedSound(List<Viseme> classes, int f) =>
      frames[f].isVoiced && classes[f] != Viseme.sil && classes[f] != Viseme.nn;

  /// A silence or murmur run of 30-140 ms between voiced frames is a lip or
  /// tongue closure: `pp` when the text allows p/b/m there (no text: silent
  /// closures only), else `dd` (silence) or `nn` (murmur).
  void _markClosures(List<Viseme> classes, List<bool> murmur) {
    int f = 0;
    while (f < frameCount) {
      if (classes[f] != Viseme.sil && classes[f] != Viseme.nn) {
        f++;
        continue;
      }
      final int start = f;
      bool anySilence = false;
      while (f < frameCount &&
          (classes[f] == Viseme.sil || classes[f] == Viseme.nn)) {
        anySilence = anySilence || classes[f] == Viseme.sil;
        f++;
      }
      final int end = f; // exclusive
      if (start == 0 || end >= frameCount) {
        continue;
      }
      final Duration length = frameStart(end) - frameStart(start);
      // Voiced before; after, either voice or the release burst.
      final bool between =
          _isVoicedSound(classes, start - 1) && classes[end] != Viseme.sil;
      if (!between ||
          length < SpeechAnalyzer._minClosure ||
          length > SpeechAnalyzer._maxClosure) {
        continue;
      }
      final bool? hint = hintAllows(_lipLetters, start, end);
      final bool lips = hint ?? anySilence;
      final Viseme closure = lips
          ? Viseme.pp
          : (anySilence ? Viseme.dd : Viseme.nn);
      for (int k = start; k < end; k++) {
        classes[k] = closure;
      }
    }
  }

  // ── Spans ───────────────────────────────────────────────────────────────

  List<VisemeSpan> spans(List<Viseme> classes) {
    // Runs of equal classes, in time.
    final List<_Run> runs = <_Run>[];
    for (int f = 0; f < frameCount; f++) {
      if (runs.isNotEmpty && runs.last.viseme == classes[f]) {
        runs.last.end = frameEnd(f);
      } else {
        runs.add(_Run(classes[f], frameStart(f), frameEnd(f)));
      }
    }

    // Short spans merge into their longer neighbour (lip closures and
    // labiodentals excepted: they must stay visible).
    bool changed = true;
    while (changed && runs.length > 1) {
      changed = false;
      int shortest = -1;
      for (int i = 0; i < runs.length; i++) {
        final _Run r = runs[i];
        if (r.length < SpeechAnalyzer._minSpan &&
            !_protected(r.viseme) &&
            (shortest < 0 || r.length < runs[shortest].length)) {
          shortest = i;
        }
      }
      if (shortest >= 0) {
        final _Run? left = shortest > 0 ? runs[shortest - 1] : null;
        final _Run? right = shortest < runs.length - 1
            ? runs[shortest + 1]
            : null;
        final _Run target = _mergeTarget(left, right);
        if (identical(target, left)) {
          left!.end = runs[shortest].end;
        } else {
          target.start = runs[shortest].start;
        }
        runs.removeAt(shortest);
        _mergeEqual(runs);
        changed = true;
      }
    }

    // Protected short spans steal from their neighbours to reach 50 ms.
    for (int i = 0; i < runs.length; i++) {
      final _Run r = runs[i];
      Duration need = SpeechAnalyzer._minSpan - r.length;
      if (need <= Duration.zero || !_protected(r.viseme)) {
        continue;
      }
      final _Run? left = i > 0 ? runs[i - 1] : null;
      final _Run? right = i < runs.length - 1 ? runs[i + 1] : null;
      // The longer neighbour gives first, never dropping under 50 ms itself.
      final List<_Run> donors = <_Run>[?left, ?right]
        ..sort((_Run a, _Run b) => b.length.compareTo(a.length));
      for (final _Run d in donors) {
        final Duration give = _min(need, d.length - SpeechAnalyzer._minSpan);
        if (give <= Duration.zero) continue;
        if (identical(d, left)) {
          d.end -= give;
          r.start -= give;
        } else {
          d.start += give;
          r.end += give;
        }
        need -= give;
      }
    }

    return <VisemeSpan>[
      for (final _Run r in runs)
        VisemeSpan(
          viseme: r.viseme,
          start: r.start,
          end: r.end,
          weight: r.viseme == Viseme.sil ? 1.0 : _weight(r.start, r.end),
        ),
    ];
  }

  /// The longer neighbour, preferring one that is not a lip closure or a
  /// labiodental (growing those would seal the lips where there is sound).
  static _Run _mergeTarget(_Run? left, _Run? right) {
    if (left == null) return right!;
    if (right == null) return left;
    final bool leftOpen = !_protected(left.viseme);
    final bool rightOpen = !_protected(right.viseme);
    if (leftOpen != rightOpen) {
      return leftOpen ? left : right;
    }
    return left.length >= right.length ? left : right;
  }

  static bool _protected(Viseme v) => v == Viseme.pp || v == Viseme.ff;

  static Duration _min(Duration a, Duration b) => a < b ? a : b;

  static void _mergeEqual(List<_Run> runs) {
    for (int i = runs.length - 1; i > 0; i--) {
      if (runs[i].viseme == runs[i - 1].viseme) {
        runs[i - 1].end = runs[i].end;
        runs.removeAt(i);
      }
    }
  }

  /// Mean linear RMS of the frames starting in [start, end) over the
  /// sentence reference, clamped 0.15-1.
  double _weight(Duration start, Duration end) {
    double sum = 0;
    int n = 0;
    for (int f = 0; f < frameCount; f++) {
      final Duration s = frameStart(f);
      if (s >= end) break;
      if (s >= start) {
        sum += frames[f].rms;
        n++;
      }
    }
    if (n == 0 || reference <= 0) {
      return 0.15;
    }
    return (sum / n / reference).clamp(0.15, 1.0);
  }

  // ── Prosody ─────────────────────────────────────────────────────────────

  List<ProsodyMark> pauses(List<VisemeSpan> spans) => <ProsodyMark>[
    for (int i = 1; i < spans.length - 1; i++)
      if (spans[i].viseme == Viseme.sil &&
          spans[i].end - spans[i].start >= SpeechAnalyzer._minPause)
        ProsodyMark(
          kind: ProsodyMarkKind.pause,
          at: spans[i].start,
          length: spans[i].end - spans[i].start,
        ),
  ];

  /// Voiced f0 smoothed over 3 frames (voiced neighbours only); NaN when
  /// unvoiced.
  late final Float64List _smoothF0 = () {
    final Float64List out = Float64List(frameCount)
      ..fillRange(0, frameCount, double.nan);
    for (int f = 0; f < frameCount; f++) {
      if (frames[f].f0 == null) continue;
      double sum = 0;
      int n = 0;
      for (
        int k = math.max(0, f - 1);
        k <= math.min(frameCount - 1, f + 1);
        k++
      ) {
        final double? v = frames[k].f0;
        if (v != null) {
          sum += v;
          n++;
        }
      }
      out[f] = sum / n;
    }
    return out;
  }();

  List<ProsodyMark> pitchPeaks() {
    final List<double> voiced = <double>[
      for (final SpeechFrameFeatures x in frames)
        if (x.f0 != null) x.f0!,
    ]..sort();
    if (voiced.length < 3) {
      return const <ProsodyMark>[];
    }
    final double median = voiced[voiced.length ~/ 2];
    final Float64List f0 = _smoothF0;
    final List<(int, double)> candidates = <(int, double)>[];
    for (int f = 0; f < frameCount; f++) {
      final double v = f0[f];
      if (v.isNaN) continue;
      final bool leftOk = f == 0 || f0[f - 1].isNaN || v >= f0[f - 1];
      final bool rightOk =
          f == frameCount - 1 || f0[f + 1].isNaN || v > f0[f + 1];
      final double excess = v / median - 1;
      if (leftOk && rightOk && excess >= 0.12) {
        candidates.add((f, excess));
      }
    }
    final List<int> accepted = _greedy(
      candidates,
      SpeechAnalyzer._pitchPeakGap,
    );
    return <ProsodyMark>[
      for (final int f in accepted)
        ProsodyMark(
          kind: ProsodyMarkKind.pitchPeak,
          at: frameCentre(f),
          strength: ((f0[f] / median - 1) / 0.30).clamp(0.0, 1.0),
        ),
    ];
  }

  List<ProsodyMark> stresses(List<VisemeSpan> spans, SpeechTimeline lookup) {
    if (frameCount == 0 || reference <= 0) {
      return const <ProsodyMark>[];
    }
    // 50 ms envelope smoothing, in dB.
    final Float64List env = Float64List(frameCount);
    for (int f = 0; f < frameCount; f++) {
      final double l = frames[math.max(0, f - 1)].rms;
      final double c = frames[f].rms;
      final double r = frames[math.min(frameCount - 1, f + 1)].rms;
      final double v = 0.25 * l + 0.5 * c + 0.25 * r;
      env[f] = v > 0
          ? math.max(-120, 20 * math.log(v / reference) / math.ln10)
          : -120;
    }
    final List<(int, double)> candidates = <(int, double)>[];
    final List<double> prominences = <double>[];
    for (int f = 0; f < frameCount; f++) {
      if (isSilent(f)) continue;
      final double v = env[f];
      final bool leftOk = f == 0 || v >= env[f - 1];
      final bool rightOk = f == frameCount - 1 || v > env[f + 1];
      if (!leftOk || !rightOk) continue;
      double leftMin = v;
      for (int k = f - 1; k >= 0 && env[k] <= v; k--) {
        leftMin = math.min(leftMin, env[k]);
      }
      double rightMin = v;
      for (int k = f + 1; k < frameCount && env[k] <= v; k++) {
        rightMin = math.min(rightMin, env[k]);
      }
      final double prominence = v - math.max(leftMin, rightMin);
      if (prominence < 4) continue;
      final VisemeSpan? span = lookup.spanAt(frameCentre(f));
      final double seconds = span == null
          ? 0.025
          : (span.end - span.start).inMicroseconds / 1e6;
      candidates.add((f, prominence * seconds));
      prominences.add(prominence);
    }
    if (candidates.isEmpty) {
      return const <ProsodyMark>[];
    }
    final Map<int, double> prominenceOf = <int, double>{
      for (int i = 0; i < candidates.length; i++)
        candidates[i].$1: prominences[i],
    };
    final List<(int, double)> ranked = List<(int, double)>.of(candidates)
      ..sort(_byScore);
    final List<(int, double)> top = ranked
        .take((ranked.length + 2) ~/ 3)
        .toList();
    final List<int> accepted = _greedy(top, SpeechAnalyzer._stressGap);
    return <ProsodyMark>[
      for (final int f in accepted)
        ProsodyMark(
          kind: ProsodyMarkKind.stress,
          at: frameCentre(f),
          strength: (prominenceOf[f]! / 12).clamp(0.0, 1.0),
        ),
    ];
  }

  static int _byScore((int, double) a, (int, double) b) {
    final int byScore = b.$2.compareTo(a.$2);
    return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
  }

  /// Best-first selection of frames at least [gap] apart, in time order.
  List<int> _greedy(List<(int, double)> candidates, Duration gap) {
    final List<(int, double)> ranked = List<(int, double)>.of(candidates)
      ..sort(_byScore);
    final List<int> accepted = <int>[];
    for (final (int f, double _) in ranked) {
      final bool farEnough = accepted.every(
        (int k) => (frameCentre(f) - frameCentre(k)).abs() >= gap,
      );
      if (farEnough) {
        accepted.add(f);
      }
    }
    return accepted..sort();
  }

  bool isQuestion() {
    final String? t = text;
    if (t != null) {
      return t.endsWith('?');
    }
    int last = -1;
    for (int f = frameCount - 1; f >= 0; f--) {
      if (frames[f].f0 != null) {
        last = f;
        break;
      }
    }
    if (last < 0) {
      return false;
    }
    final Duration from = frameCentre(last) - SpeechAnalyzer._questionWindow;
    final List<double> window = <double>[
      for (int f = 0; f <= last; f++)
        if (frames[f].f0 != null && frameCentre(f) >= from) frames[f].f0!,
    ];
    if (window.length < 4) {
      return false;
    }
    final double startHz = (window[0] + window[1]) / 2;
    final double endHz =
        (window[window.length - 1] + window[window.length - 2]) / 2;
    return endHz >= startHz * 1.15;
  }

  SpeechTimeline timeline() {
    final bool question = isQuestion();
    if (frameCount == 0) {
      return SpeechTimeline(isQuestion: question);
    }
    final List<VisemeSpan> visemes = spans(classify());
    final SpeechTimeline bare = SpeechTimeline(
      visemes: visemes,
      duration: duration,
    );
    final List<ProsodyMark> marks = <ProsodyMark>[
      ...pauses(visemes),
      ...pitchPeaks(),
      ...stresses(visemes, bare),
    ]..sort((ProsodyMark a, ProsodyMark b) => a.at.compareTo(b.at));
    final VisemeSpan first = visemes.first;
    return bare.copyWith(
      marks: marks,
      leadingSilence: first.viseme == Viseme.sil && visemes.length > 1
          ? first.end
          : Duration.zero,
      isQuestion: question,
    );
  }
}

class _Run {
  _Run(this.viseme, this.start, this.end);

  final Viseme viseme;
  Duration start;
  Duration end;

  Duration get length => end - start;
}

/// 512-point Hann-windowed power spectrum folded into the four bands, after a
/// +6 dB/octave tilt (the classic speech pre-emphasis, done per bin so it is
/// the same at every sample rate). Without it the voice's natural roll-off
/// puts ~99 % of every vowel's energy under 700 Hz and the band shares carry
/// no vowel information.
class _Spectrum {
  _Spectrum(this.sampleRate) {
    const int n = SpeechAnalyzer._fftSize;
    for (int i = 0; i < n; i++) {
      _window[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1));
    }
    for (int k = 0; k < n ~/ 2; k++) {
      _cos[k] = math.cos(2 * math.pi * k / n);
      _sin[k] = math.sin(2 * math.pi * k / n);
    }
    // Resampled bin edges: each bin's centre frequency picks its band.
    final double binHz = sampleRate / n;
    final double nyquist = sampleRate / 2;
    for (int k = 0; k <= n ~/ 2; k++) {
      final double hz = k * binHz;
      int band = -1;
      for (int b = 0; b < 4; b++) {
        final double lo = SpeechAnalyzer._bandEdges[b];
        final double hi = math.min(SpeechAnalyzer._bandEdges[b + 1], nyquist);
        if (hz >= lo && hz < hi) {
          band = b;
        }
      }
      _bandOf[k] = band;
      // Power x f^2 = amplitude x f: +6 dB per octave.
      _tilt[k] = (hz / 1000) * (hz / 1000);
    }
  }

  final int sampleRate;
  final Float64List _window = Float64List(SpeechAnalyzer._fftSize);
  final Float64List _cos = Float64List(SpeechAnalyzer._fftSize ~/ 2);
  final Float64List _sin = Float64List(SpeechAnalyzer._fftSize ~/ 2);
  final Int8List _bandOf = Int8List(SpeechAnalyzer._fftSize ~/ 2 + 1);
  final Float64List _tilt = Float64List(SpeechAnalyzer._fftSize ~/ 2 + 1);
  final Float64List _re = Float64List(SpeechAnalyzer._fftSize);
  final Float64List _im = Float64List(SpeechAnalyzer._fftSize);

  List<double> bandShares(Float32List samples, int centre) {
    const int n = SpeechAnalyzer._fftSize;
    final int from = centre - n ~/ 2;
    for (int i = 0; i < n; i++) {
      final int at = from + i;
      final double x = at >= 0 && at < samples.length ? samples[at] : 0;
      _re[i] = x * _window[i];
      _im[i] = 0;
    }
    _fft(_re, _im);
    final List<double> bands = <double>[0, 0, 0, 0];
    for (int k = 0; k <= n ~/ 2; k++) {
      final int b = _bandOf[k];
      if (b >= 0) {
        bands[b] += (_re[k] * _re[k] + _im[k] * _im[k]) * _tilt[k];
      }
    }
    final double total = bands[0] + bands[1] + bands[2] + bands[3];
    if (total <= 0) {
      return const <double>[0, 0, 0, 0];
    }
    return <double>[for (final double e in bands) e / total];
  }

  /// In-place iterative radix-2 FFT.
  void _fft(Float64List re, Float64List im) {
    final int n = re.length;
    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        final double tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final double ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }
    for (int len = 2; len <= n; len <<= 1) {
      final int half = len >> 1;
      final int step = n ~/ len;
      for (int i = 0; i < n; i += len) {
        for (int k = 0; k < half; k++) {
          final double wr = _cos[k * step];
          final double wi = -_sin[k * step];
          final int a = i + k;
          final int b = a + half;
          final double xr = re[b] * wr - im[b] * wi;
          final double xi = re[b] * wi + im[b] * wr;
          re[b] = re[a] - xr;
          im[b] = im[a] - xi;
          re[a] += xr;
          im[a] += xi;
        }
      }
    }
  }
}

/// f0 by normalised autocorrelation of a decimated copy of the signal, over
/// 70-400 Hz on a 40 ms window.
class _PitchTracker {
  _PitchTracker(Float32List samples, int sampleRate)
    : factor = math.max(1, (sampleRate / SpeechAnalyzer._pitchRate).round()) {
    rate = sampleRate / factor;
    final int n = samples.length ~/ factor;
    signal = Float64List(n);
    for (int i = 0; i < n; i++) {
      double sum = 0;
      for (int k = 0; k < factor; k++) {
        sum += samples[i * factor + k];
      }
      signal[i] = sum / factor;
    }
    window = math.max(8, (rate * 0.040).round());
    minLag = math.max(1, (rate / SpeechAnalyzer._maxF0).floor());
    maxLag = (rate / SpeechAnalyzer._minF0).ceil();
  }

  final int factor;
  late final double rate;
  late final Float64List signal;
  late final int window;
  late final int minLag;
  late final int maxLag;

  double _x(int i) => i >= 0 && i < signal.length ? signal[i] : 0;

  /// (periodicity, f0 or null) for the window centred on input sample
  /// [centre].
  (double, double?) at(int centre) {
    final int start = centre ~/ factor - window ~/ 2;
    double e0 = 0;
    for (int j = 0; j < window; j++) {
      final double v = _x(start + j);
      e0 += v * v;
    }
    if (e0 <= 0) {
      return (0, null);
    }
    final Float64List r = Float64List(maxLag + 2);
    // Energy of the lagged segment, slid incrementally.
    double eLag = 0;
    for (int j = 0; j < window; j++) {
      final double v = _x(start + minLag + j);
      eLag += v * v;
    }
    double best = 0;
    for (int lag = minLag; lag <= maxLag + 1; lag++) {
      if (lag > minLag) {
        final double out = _x(start + lag - 1);
        final double inn = _x(start + lag + window - 1);
        eLag += inn * inn - out * out;
      }
      double dot = 0;
      for (int j = 0; j < window; j++) {
        dot += _x(start + j) * _x(start + lag + j);
      }
      final double denom = math.sqrt(e0 * math.max(eLag, 0));
      r[lag] = denom > 0 ? dot / denom : 0;
      if (lag <= maxLag) {
        best = math.max(best, r[lag]);
      }
    }
    if (best < SpeechAnalyzer._voicedPeriodicity) {
      return (best, null);
    }
    // The shortest-lag local peak close to the best one (avoids picking a
    // multiple of the period).
    for (int lag = minLag + 1; lag <= maxLag; lag++) {
      final double v = r[lag];
      if (v >= 0.9 * best && v >= r[lag - 1] && v >= r[lag + 1]) {
        final double a = r[lag - 1];
        final double c = r[lag + 1];
        final double denom = a - 2 * v + c;
        final double shift = denom.abs() > 1e-12
            ? (0.5 * (a - c) / denom).clamp(-0.5, 0.5)
            : 0;
        return (best, rate / (lag + shift));
      }
    }
    return (best, null);
  }
}
