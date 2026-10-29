import 'dart:math' as math;
import 'dart:typed_data';

import '../../models/performance/speech_timeline.dart';
import '../../models/performance/viseme.dart';
import 'phonemizer.dart';
import 'speech_frames.dart';

/// The result of aligning a sentence's phones to its audio.
class AlignedVisemes {
  const AlignedVisemes({required this.spans, required this.costPerFrame});

  /// One span per token, in token order, plus a `sil` span for every silence
  /// the aligner inserted (at word ends and at both ends of the audio).
  /// Contiguous from zero to the end of the audio, on frame boundaries, and
  /// not merged or smoothed.
  final List<VisemeSpan> spans;

  /// Emission and duration cost above the audio's own best labelling (each
  /// frame its cheapest class), per sounding (non-silent) frame: low when the
  /// phones fit the audio, high when the text does not match it. Measuring
  /// above that floor keeps an unusual voice or a noisy recording from
  /// reading as a mismatch; counting only sounding frames keeps silence
  /// around the sentence from diluting the cost.
  final double costPerFrame;
}

/// Monotonic Viterbi (explicit-duration) alignment of phonemizer tokens to
/// the analysis frames.
///
/// Each token holds a run of whole frames, in order: at least 1 frame (2 for
/// a vowel), at most [_maxVowel] / [_maxConsonant] frames ([_maxStop] for a
/// stop closure: a longer silence is a pause), with a log-normal
/// duration prior around 90 ms (vowels), 80 ms (fricatives) or 60 ms (the
/// rest). A silence may be inserted at both ends and after any word: free
/// after punctuation, which is where a speaker pauses, and with a small
/// opening and per-frame cost elsewhere (there it is usually a closure). Every
/// frame's cost for a token comes from the acoustic features the audio
/// classifier uses (level, voicing, the four band shares, the zero-crossing
/// rate), turned into a per-class score: a vowel wants a loud voiced frame,
/// a sibilant high-band noise, a stop silence or a burst, a nasal a quiet
/// low-band murmur, and so on. The text decides the labels; the audio only
/// decides where each one starts.
class PhonemeAligner {
  const PhonemeAligner();

  static const int _minVowel = 2;
  static const int _minConsonant = 1;
  static const int _maxVowel = 28;
  static const int _maxConsonant = 16;
  static const int _maxStop = 8;

  /// Expected durations in frames (25 ms).
  static const double _expectedVowel = 3.6;
  static const double _expectedFricative = 3.2;
  static const double _expectedOther = 2.4;

  /// Weight of the squared log-ratio duration prior, per token.
  static const double _durationWeight = 1.0;

  /// Cost of opening a silence between two words with no punctuation
  /// between them, and its extra cost per frame (a speaker pauses where the
  /// text has punctuation; elsewhere a silence is a stop's closure).
  static const double _insertSilence = 0.5;
  static const double _unpunctuatedSilence = 0.3;

  /// The best alignment of [tokens] to [frames]; null when there are no
  /// tokens or frames, or when the tokens cannot fit (more minimum frames
  /// than the audio has).
  AlignedVisemes? align(List<PhonemeToken> tokens, SpeechFrames frames) {
    final int t = frames.length;
    if (tokens.isEmpty || t == 0) {
      return null;
    }

    // States: [sil] tok0 tok1 .. tokK(word end) [sil] tokK+1 .. tokN [sil].
    final List<_State> states = <_State>[const _State.silence(free: true)];
    for (int i = 0; i < tokens.length; i++) {
      states.add(_State.token(tokens[i]));
      final bool last = i == tokens.length - 1;
      if (last || tokens[i].wordEnd) {
        states.add(_State.silence(free: last || tokens[i].pauseAfter));
      }
    }

    final _Emissions emissions = _Emissions(frames);
    final int n = states.length;
    final List<Float64List> best = <Float64List>[
      for (int s = 0; s < n; s++)
        Float64List(t + 1)..fillRange(0, t + 1, double.infinity),
    ];
    final List<Int32List> startOf = <Int32List>[
      for (int s = 0; s < n; s++) Int32List(t + 1),
    ];
    final List<Int32List> predOf = <Int32List>[
      for (int s = 0; s < n; s++) Int32List(t + 1),
    ];
    final Float64List entryCost = Float64List(t + 1);
    final Int32List entryPred = Int32List(t + 1);

    for (int s = 0; s < n; s++) {
      // Cheapest way to have finished everything before state s at frame u.
      for (int u = 0; u <= t; u++) {
        double cost = double.infinity;
        int pred = -2;
        void consider(int p) {
          final double c = p < 0 ? (u == 0 ? 0 : double.infinity) : best[p][u];
          if (c < cost) {
            cost = c;
            pred = p;
          }
        }

        consider(s - 1);
        if (s - 1 >= 0 && states[s - 1].isSilence) {
          consider(s - 2);
        }
        entryCost[u] = cost;
        entryPred[u] = pred;
      }

      final _State state = states[s];
      final Float64List row = best[s];
      if (state.isSilence) {
        final Float64List cum = emissions.cumulative(_Cls.sil);
        final double open = state.free ? 0 : _insertSilence;
        final double surcharge = state.free ? 0 : _unpunctuatedSilence;
        for (int end = 1; end <= t; end++) {
          final double frameCost = cum[end] - cum[end - 1] + surcharge;
          final double stay = row[end - 1] + frameCost;
          final double enter = entryCost[end - 1] + open + frameCost;
          if (enter <= stay && enter.isFinite) {
            row[end] = enter;
            startOf[s][end] = end - 1;
            predOf[s][end] = entryPred[end - 1];
          } else if (stay.isFinite) {
            row[end] = stay;
            startOf[s][end] = startOf[s][end - 1];
            predOf[s][end] = predOf[s][end - 1];
          }
        }
        continue;
      }

      final PhonemeToken token = state.token!;
      final _Cls cls = _classOf(token);
      final Float64List cum = emissions.cumulative(cls);
      final int minD = token.vowel ? _minVowel : _minConsonant;
      final int maxD = token.vowel
          ? _maxVowel
          : (_isStop(token.viseme) ? _maxStop : _maxConsonant);
      final double expected = token.vowel
          ? _expectedVowel
          : (_isFricative(token.viseme) ? _expectedFricative : _expectedOther);
      for (int end = minD; end <= t; end++) {
        final int longest = math.min(maxD, end);
        for (int d = minD; d <= longest; d++) {
          final int u = end - d;
          final double enter = entryCost[u];
          if (!enter.isFinite) continue;
          final double logRatio = math.log(d / expected);
          final double c =
              enter + cum[end] - cum[u] + _durationWeight * logRatio * logRatio;
          if (c < row[end]) {
            row[end] = c;
            startOf[s][end] = u;
            predOf[s][end] = entryPred[u];
          }
        }
      }
    }

    // The last token, or the trailing silence after it, ends the audio.
    int state = n - 1;
    if (best[n - 2][t] < best[n - 1][t]) {
      state = n - 2;
    }
    final double total = best[state][t];
    if (!total.isFinite) {
      return null;
    }

    final List<VisemeSpan> spans = <VisemeSpan>[];
    int end = t;
    while (state >= 0) {
      final int u = startOf[state][end];
      final _State st = states[state];
      spans.add(
        VisemeSpan(
          viseme: st.isSilence ? Viseme.sil : st.token!.viseme,
          start: frames.startOf(u),
          end: frames.startOf(end),
        ),
      );
      state = predOf[state][end];
      end = u;
    }
    // Per sounding frame: silence costs nothing either way, so leading or
    // trailing padding must not dilute a mismatch into a pass.
    int sounding = 0;
    for (int f = 0; f < t; f++) {
      if (!frames.isSilent(f)) {
        sounding++;
      }
    }
    return AlignedVisemes(
      spans: spans.reversed.toList(),
      costPerFrame:
          math.max(0, total - emissions.floor()) / math.max(1, sounding),
    );
  }

  static bool _isStop(Viseme v) =>
      v == Viseme.pp || v == Viseme.dd || v == Viseme.kk;

  static bool _isFricative(Viseme v) =>
      v == Viseme.ff || v == Viseme.th || v == Viseme.ss || v == Viseme.ch;

  static _Cls _classOf(PhonemeToken token) {
    if (token.vowel) {
      return switch (token.viseme) {
        Viseme.aa => _Cls.vowelAa,
        Viseme.e || Viseme.ih => _Cls.vowelFront,
        Viseme.oh => _Cls.vowelOh,
        Viseme.ou => _Cls.vowelOu,
        _ => _Cls.vowelR,
      };
    }
    return switch (token.viseme) {
      Viseme.ou => _Cls.glideRound,
      Viseme.ih => _Cls.glideFront,
      Viseme.rr => _Cls.glideR,
      Viseme.nn => _Cls.nasal,
      Viseme.pp => _Cls.lips,
      Viseme.dd || Viseme.kk => _Cls.stop,
      Viseme.ss => _Cls.sibilant,
      Viseme.ff || Viseme.th => _Cls.weakFricative,
      Viseme.ch => _Cls.postalveolar,
      Viseme.aa => _Cls.vowelAa,
      Viseme.e => _Cls.vowelFront,
      Viseme.oh => _Cls.vowelOh,
      Viseme.sil => _Cls.sil,
    };
  }
}

/// Acoustic classes the emission model scores.
enum _Cls {
  sil,
  vowelAa,
  vowelFront,
  vowelOh,
  vowelOu,
  vowelR,
  glideRound,
  glideFront,
  glideR,
  nasal,
  lips,
  stop,
  sibilant,
  weakFricative,
  postalveolar,
}

class _State {
  const _State.silence({required this.free}) : token = null;
  const _State.token(PhonemeToken this.token) : free = false;

  final PhonemeToken? token;

  /// A silence at either end of the audio or after punctuation (no opening
  /// cost, no surcharge).
  final bool free;

  bool get isSilence => token == null;
}

/// Per-frame emission costs (0 = a perfect fit, about 2-4 = impossible),
/// cumulated per class on demand.
class _Emissions {
  _Emissions(this.frames) : _dip = _dips(frames);

  final SpeechFrames frames;

  /// How far each frame sits under its 200 ms neighbourhood peak, 0-1.
  final Float64List _dip;

  final Map<_Cls, Float64List> _cumulative = <_Cls, Float64List>{};

  static Float64List _dips(SpeechFrames frames) {
    final int t = frames.length;
    final Float64List out = Float64List(t);
    for (int f = 0; f < t; f++) {
      double peak = -120;
      for (int k = math.max(0, f - 4); k <= math.min(t - 1, f + 4); k++) {
        peak = math.max(peak, frames.features[k].db);
      }
      out[f] = _unit((peak - frames.features[f].db - 3) / 9);
    }
    return out;
  }

  /// The cost of the best unconstrained labelling (each frame its cheapest
  /// class): the alignment cost is measured above it, so a noisy or unusual
  /// voice does not read as a text mismatch.
  double floor() {
    double sum = 0;
    for (int f = 0; f < frames.length; f++) {
      double best = double.infinity;
      for (final _Cls c in _Cls.values) {
        best = math.min(best, cost(c, f));
      }
      sum += best;
    }
    return sum;
  }

  Float64List cumulative(_Cls cls) => _cumulative.putIfAbsent(cls, () {
    final int t = frames.length;
    final Float64List cum = Float64List(t + 1);
    for (int f = 0; f < t; f++) {
      cum[f + 1] = cum[f] + cost(cls, f);
    }
    return cum;
  });

  static double _unit(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  double cost(_Cls cls, int f) {
    final SpeechFrameFeatures x = frames.features[f];
    final bool silent = frames.isSilent(f);
    final List<double> s = x.bandShares;
    final double hiss = _unit((s[3] - 0.35) / 0.45);
    final double noisy = _unit((x.zcr - 0.15) / 0.3);
    // Voiced, or sonorant without a clean period (creaky voice at phrase
    // ends): few zero crossings, no hiss, clearly audible.
    final double voicing = math.max(
      _unit((x.periodicity - 0.4) / 0.4),
      _unit((0.12 - x.zcr) / 0.06) * (1 - hiss) * _unit((x.db + 30) / 10),
    );
    final double dip = _dip[f];
    final double low = s[0] + s[1];
    final double r2 = low > 0 ? s[1] / low : 0;

    double vowelLike(double quality) => silent
        ? 4
        : 1.2 * _unit((-x.db - 8) / 16) +
              0.5 * dip +
              1.5 * (1 - voicing) +
              2 * hiss +
              1.5 * math.min(1, quality);
    double glide(double quality) => silent
        ? 3.5
        : 0.3 +
              1.5 * _unit((-x.db - 10) / 14) +
              0.5 * dip +
              1.2 * (1 - voicing) +
              2 * hiss +
              1.5 * math.min(1, quality);
    double murmur(double lowShare) => silent
        ? 2.5
        : 0.3 +
              0.8 * (1 - dip) +
              1.0 * (1 - voicing) +
              1.0 * _unit((lowShare - s[0]) / 0.4) +
              2 * hiss;
    // A closure (quiet, no hiss) or its release burst (one hissy frame).
    final double calm = 1 - 0.7 * hiss;
    double stop() => silent
        ? 0.2
        : 2 *
              (1 -
                  math.max(
                    _unit((-x.db - 8) / 14) * calm,
                    math.max(0.6 * hiss, dip * calm),
                  ));

    final double open = _unit((0.35 - r2) / 0.25);
    final double front = _unit((0.12 - s[2]) / 0.12);
    final double oh = _unit((r2 - 0.6) / 0.3) + _unit((s[2] - 0.25) / 0.2);
    final double ou = _unit((r2 - 0.4) / 0.3) + _unit((s[2] - 0.2) / 0.2);

    return switch (cls) {
      _Cls.sil => silent ? 0 : 3 * _unit((x.db + 32) / 12),
      _Cls.vowelAa => vowelLike(open),
      _Cls.vowelFront => vowelLike(front),
      _Cls.vowelOh => vowelLike(oh),
      _Cls.vowelOu => vowelLike(ou),
      _Cls.vowelR => vowelLike(0),
      _Cls.glideRound => glide(ou),
      _Cls.glideFront => glide(front),
      _Cls.glideR => glide(0),
      _Cls.nasal => murmur(0.6),
      _Cls.lips => math.min(stop(), murmur(0.8) - 0.1),
      _Cls.stop => stop(),
      _Cls.sibilant => silent ? 1.8 : 2.2 * (1 - hiss) + 0.8 * (1 - noisy),
      _Cls.weakFricative =>
        silent
            ? 0.8
            : math.min(
                2 * (1 - _unit((s[3] - 0.2) / 0.4)) + 0.4 * (1 - noisy),
                0.6 + 1.2 * (1 - dip),
              ),
      _Cls.postalveolar =>
        silent
            ? 1.8
            : 2 * (1 - _unit((s[2] + s[3] - 0.45) / 0.4)) + 0.6 * (1 - noisy),
    };
  }
}
