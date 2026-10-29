import 'dart:math' as math;

import '../../../../core/models/performance/performance.dart';

/// The blended mouth for one instant. [sealed] means the instant lies inside
/// a `pp` span: the lips must be fully closed now. [pop] is the part of
/// `shape.jaw` that is the plosive release pop (0 outside the 90 ms after a
/// closure), so a consumer that smooths the jaw can add it back on time.
/// [opening] is how far the release ramp after a closure has come (0 at the
/// release, 1 once the mouth is open, and 1 anywhere else): while it is under
/// 1 the shape is already eased and must not be smoothed again.
class MouthBlend {
  const MouthBlend({
    required this.shape,
    this.sealed = false,
    this.pop = 0,
    this.opening = 1,
  });

  final MouthShape shape;
  final bool sealed;
  final double pop;
  final double opening;

  @override
  bool operator ==(Object other) =>
      other is MouthBlend &&
      other.shape == shape &&
      other.sealed == sealed &&
      other.pop == pop &&
      other.opening == opening;

  @override
  int get hashCode => Object.hash(shape, sealed, pop, opening);

  @override
  String toString() =>
      'MouthBlend($shape, sealed: $sealed, pop: $pop, opening: $opening)';
}

/// Coarticulation: turns a [SpeechTimeline] and a playback position into one
/// mouth shape. Neighbouring visemes lean into each other (the next one pulls
/// early in the last [anticipation], the previous one leaks back in the first
/// [carryOver]), weighted by [MouthShape.dominance], so a closure wins over a
/// vowel and an open vowel gives way. A `pp` span is a hard lip seal that
/// compresses (press [sealPressStart] → [sealPress] across the span) and
/// releases with a pop: the jaw, the rounding and the spread open over
/// [releaseBurst] with an ease-out (never in one frame), and a [popJaw] bump
/// over [releasePop] carries the jaw past the next shape near the end of the
/// ramp. There is no pop into `sil` or into a span shorter than [popMinSpan].
///
/// The result is continuous in time: both lean windows are clamped to half
/// the span (a vowel's to [vowelLean] of it), so they never overlap, and each leak starts exactly where the
/// previous span's anticipation ended.
///
/// The lips round [preRound] ahead of a rounded vowel (`oh`, `ou`: /o/, /u/,
/// /w/), across any consonant or closure in between (a seal rounds at most
/// 0.3; an `oh` itself only rounds ahead of an `ou`), and the spread gives
/// way twice as fast: none is left halfway through the window, so the
/// consonant before "so" or the y of "you" is already unspread. While
/// rounding the lips are never spread wider than the rounding allows
/// (`stretch <= 1 - pucker`); after a closure the jaw, the rounding and the
/// spread open on the same release ramp (no unrounded frame between a b and
/// an ou); a `th` keeps the tongue up at [thTongue] or more across its span;
/// a vowel's jaw scales by its length ([vowelJawGain]), so a vowel squeezed
/// between two closures opens a little less, and its lean windows leave it
/// a plateau ([vowelLean]). With
/// [SpeechTimeline.roundedSh] (French) a `ch` is [roundedShShape]: rounded,
/// barely spread.
class VisemeBlender {
  const VisemeBlender({
    this.anticipation = const Duration(milliseconds: 70),
    this.carryOver = const Duration(milliseconds: 40),
  });

  final Duration anticipation;
  final Duration carryOver;

  /// The mouth at [t]: rest outside every span; spans separated by a gap do
  /// not lean on each other.
  MouthBlend shapeAt(SpeechTimeline timeline, Duration t) {
    final List<VisemeSpan> spans = timeline.visemes;
    final int index = _indexAt(spans, t);
    if (index < 0) {
      return const MouthBlend(shape: MouthShape.rest);
    }
    final VisemeSpan current = spans[index];
    final double start = current.start.inMicroseconds.toDouble();
    final double end = current.end.inMicroseconds.toDouble();
    final double now = t.inMicroseconds.toDouble();
    if (current.viseme == Viseme.pp) {
      // compression: the lips meet lightly and press harder to the release
      final double k = ((now - start) / (end - start)).clamp(0.0, 1.0);
      return MouthBlend(
        shape: _seal(
          sealPressStart + (sealPress - sealPressStart) * k,
          round: _roundAhead(spans, index + 1, now).pucker,
        ),
        sealed: true,
      );
    }
    final bool roundSh = timeline.roundedSh;
    final MouthShape base = _targetOf(spans, index, roundSh);
    final double half = (end - start) / 2;

    final VisemeSpan? next = index + 1 < spans.length ? spans[index + 1] : null;
    final VisemeSpan? previous = index > 0 ? spans[index - 1] : null;
    final bool hasNext = next != null && next.start <= current.end;
    final bool hasPrevious = previous != null && previous.end >= current.start;

    final bool release = hasPrevious && previous.viseme == Viseme.pp;
    // The pop overshoots into a sound: a closure into silence, or into a
    // span too short to carry it, opens without one (no jaw twitch).
    final bool pops =
        release &&
        current.viseme != Viseme.sil &&
        current.end - current.start >= popMinSpan;

    // A vowel's jaw keeps a plateau of its own: its jaw leans over at most
    // [vowelLean] of it at each end (everything else, and a consonant, over
    // up to half), so a normal-length vowel holds its full opening for a
    // few frames instead of peaking for one.
    MouthShape shape = _lean(
      base,
      spans,
      index,
      previous: hasPrevious ? previous : null,
      next: hasNext ? next : null,
      now: now,
      limit: half,
      release: release,
      roundSh: roundSh,
    );
    if (_isVowel(current.viseme)) {
      shape = shape.copyWith(
        jaw: _lean(
          base,
          spans,
          index,
          previous: hasPrevious ? previous : null,
          next: hasNext ? next : null,
          now: now,
          limit: (end - start) * vowelLean,
          release: release,
          roundSh: roundSh,
        ).jaw,
      );
    }

    // the lips round ahead of a coming rounded vowel; the spread goes first
    double round = 0;
    if (current.viseme != Viseme.ou) {
      final ({double pucker, double unspread}) ahead = _roundAhead(
        spans,
        index + 1,
        now,
        ouOnly: current.viseme == Viseme.oh,
      );
      round = ahead.pucker;
      if (round > 0) {
        shape = shape.copyWith(
          pucker: _max(shape.pucker, round),
          stretch: shape.stretch * (1 - ahead.unspread),
        );
      }
    }
    // lips rounding for an ou cannot also be spread (an sh on its own keeps
    // both)
    final bool rounding = current.viseme == Viseme.ou || round > 0;
    if (rounding && shape.stretch > 1 - shape.pucker) {
      shape = shape.copyWith(stretch: 1 - shape.pucker);
    }
    if (current.viseme == Viseme.th && shape.tongueUp < thTongue) {
      shape = shape.copyWith(tongueUp: thTongue);
    }

    if (release) {
      final double since = now - start;
      // a vowel squeezed between closures opens faster (never in one frame)
      final double burst = _min(
        releaseBurst.inMicroseconds.toDouble(),
        shortBurst * (end - start),
      );
      final double popWindow = _min(
        releasePop.inMicroseconds.toDouble(),
        end - start,
      );
      final double k = releaseRamp(since / burst);
      final double opened = shape.jaw * k;
      // the seal's own rounding as it let go
      final double sealRound = _min(
        _roundAhead(spans, index, start).pucker,
        _sealPucker,
      );
      double pop = 0;
      if (pops && since < popWindow) {
        final double amount = popJaw * math.sin(math.pi * since / popWindow);
        pop = _min(opened + amount, 1) - opened;
      }
      if (since < burst || pop > 0) {
        return MouthBlend(
          shape: shape.copyWith(
            jaw: opened + pop,
            pucker: sealRound + (shape.pucker - sealRound) * k,
            stretch: shape.stretch * k,
          ),
          pop: pop,
          opening: since < burst ? k : 1,
        );
      }
    }
    return MouthBlend(shape: shape);
  }

  /// [base] of [current] leaning on its neighbours at [now] (µs), each lean
  /// window at most [limit] µs: the leak of [previous] decays over the first
  /// carry window (after a closure the pressed lips peel apart this way, but
  /// the jaw, the rounding and the spread do not leak: they burst open on the
  /// release ramp) and [next] is anticipated over the last window.
  MouthShape _lean(
    MouthShape base,
    List<VisemeSpan> spans,
    int index, {
    required VisemeSpan? previous,
    required VisemeSpan? next,
    required double now,
    required double limit,
    required bool release,
    required bool roundSh,
  }) {
    final VisemeSpan current = spans[index];
    final double start = current.start.inMicroseconds.toDouble();
    final double end = current.end.inMicroseconds.toDouble();
    MouthShape shape = base;
    if (previous != null) {
      final double window = _min(carryOver.inMicroseconds.toDouble(), limit);
      if (window > 0 && now < start + window) {
        final double decay = 1 - _smoothstep((now - start) / window);
        final double lean = _leanBack(previous, current) * decay;
        final MouthShape before = shape;
        shape = shape.lerp(_leakOf(spans, index - 1, roundSh), lean);
        if (release) {
          shape = shape.copyWith(
            jaw: before.jaw,
            pucker: before.pucker,
            stretch: before.stretch,
          );
        }
      }
    }
    if (next != null) {
      final double window = _min(anticipation.inMicroseconds.toDouble(), limit);
      if (window > 0 && now > end - window) {
        final double rise = _smoothstep((now - (end - window)) / window);
        final double dominance = MouthShape.dominance(current.viseme);
        final double pull =
            MouthShape.dominance(next.viseme) /
            _max(dominance, MouthShape.dominance(next.viseme));
        shape = shape.lerp(_targetOf(spans, index + 1, roundSh), rise * pull);
      }
    }
    return shape;
  }

  /// The rounding at [now] for the first rounded vowel (`oh` or `ou`; only
  /// `ou` when [ouOnly]) that starts within [preRound] after it, searching
  /// from span [from]: its pucker eases from 0 at the window's start to the
  /// vowel's full pucker at its onset, and `unspread` (the share of the
  /// spread already given up) reaches 1 halfway through the window.
  static ({double pucker, double unspread}) _roundAhead(
    List<VisemeSpan> spans,
    int from,
    double now, {
    bool ouOnly = false,
  }) {
    final double window = preRound.inMicroseconds.toDouble();
    for (int i = from; i < spans.length; i++) {
      final double ahead = spans[i].start.inMicroseconds - now;
      if (ahead > window) {
        break;
      }
      final Viseme v = spans[i].viseme;
      final bool rounded = v == Viseme.ou || (!ouOnly && v == Viseme.oh);
      if (rounded && ahead >= 0) {
        final double x = 1 - ahead / window;
        return (
          pucker: MouthShape.forViseme(v).pucker * _smoothstep(x),
          unspread: _smoothstep(2 * x),
        );
      }
    }
    return (pucker: 0, unspread: 0);
  }

  /// How much of [previous] is still in the mouth when [current] starts.
  /// A seal stays fully closed to the boundary; otherwise it is what is left
  /// after [previous] anticipated [current].
  double _leanBack(VisemeSpan previous, VisemeSpan current) {
    if (previous.viseme == Viseme.pp) {
      return 1;
    }
    final double pulled =
        MouthShape.dominance(current.viseme) /
        _max(
          MouthShape.dominance(previous.viseme),
          MouthShape.dominance(current.viseme),
        );
    return 1 - pulled;
  }

  /// The span's target shape; the jaw (and only the jaw) scales by weight.
  /// A closure is approached at its lightest press (where it starts); a `ch`
  /// is [roundedShShape] when [roundSh].
  static MouthShape _shapeOf(VisemeSpan span, bool roundSh) {
    if (span.viseme == Viseme.pp) {
      return _seal(sealPressStart);
    }
    final MouthShape raw = roundSh && span.viseme == Viseme.ch
        ? roundedShShape
        : MouthShape.forViseme(span.viseme);
    final double length = _isVowel(span.viseme)
        ? vowelJawGain(span.end - span.start)
        : 1;
    return raw.copyWith(
      jaw: (raw.jaw * jawGain(span.weight) * length).clamp(0.0, 1.0),
    );
  }

  static bool _isVowel(Viseme v) =>
      v == Viseme.aa ||
      v == Viseme.e ||
      v == Viseme.ih ||
      v == Viseme.oh ||
      v == Viseme.ou;

  /// What [previous] leaves in the mouth as the next span starts: a closure
  /// leaves its fully compressed lips.
  static MouthShape _leakOf(List<VisemeSpan> spans, int index, bool roundSh) =>
      spans[index].viseme == Viseme.pp
      ? _seal(sealPress)
      : _targetOf(spans, index, roundSh);

  /// The span's target shape in its context ([_shapeOf] with the jaw as a
  /// slow articulator): inside a phrase the jaw never falls under
  /// [phraseJawFloor] (a short `sil` between two sounds included), except
  /// for a `pp` seal and an `ff` tuck; and a consonant keeps at least
  /// [consonantJawShare] of the jaw of its neighbouring vowels (the mean
  /// of the nearest one before and after it in the phrase, the one there is
  /// when only one side has a vowel). A `pp` and an `ff` close the jaw as
  /// their lips need.
  static MouthShape _targetOf(List<VisemeSpan> spans, int index, bool roundSh) {
    final VisemeSpan span = spans[index];
    final MouthShape raw = _shapeOf(span, roundSh);
    final Viseme v = span.viseme;
    if (v == Viseme.pp || v == Viseme.ff) {
      return raw;
    }
    if (v == Viseme.sil) {
      return _insidePhrase(spans, index)
          ? raw.copyWith(jaw: phraseJawFloor)
          : raw;
    }
    double jaw = raw.jaw;
    if (!_isVowel(v)) {
      final double? before = _vowelJaw(spans, index, -1, roundSh);
      final double? after = _vowelJaw(spans, index, 1, roundSh);
      final double? vowel = before == null
          ? after
          : (after == null ? before : (before + after) / 2);
      if (vowel != null) {
        jaw = _max(jaw, consonantJawShare * vowel);
      }
    }
    return raw.copyWith(jaw: _max(jaw, phraseJawFloor).clamp(0.0, 1.0));
  }

  /// The jaw of the nearest vowel from [index] in direction [step] (±1)
  /// within the phrase: the search stops at a `pp` (the lips close there), at
  /// a `sil` of [phraseBreak] or more and at a gap that long, and passes
  /// shorter silences.
  static double? _vowelJaw(
    List<VisemeSpan> spans,
    int index,
    int step,
    bool roundSh,
  ) {
    for (int i = index + step; i >= 0 && i < spans.length; i += step) {
      final VisemeSpan s = spans[i];
      final VisemeSpan toward = spans[i - step];
      final Duration gap = step > 0
          ? s.start - toward.end
          : toward.start - s.end;
      if (gap >= phraseBreak || s.viseme == Viseme.pp) {
        return null;
      }
      if (s.viseme == Viseme.sil) {
        if (s.end - s.start >= phraseBreak) {
          return null;
        }
        continue;
      }
      if (_isVowel(s.viseme)) {
        return _shapeOf(s, roundSh).jaw;
      }
    }
    return null;
  }

  /// A `sil` shorter than [phraseBreak] with a sounding span on each side:
  /// the voice goes on through it.
  static bool _insidePhrase(List<VisemeSpan> spans, int index) {
    final VisemeSpan s = spans[index];
    if (s.end - s.start >= phraseBreak ||
        index == 0 ||
        index + 1 >= spans.length) {
      return false;
    }
    return spans[index - 1].viseme != Viseme.sil &&
        spans[index + 1].viseme != Viseme.sil;
  }

  /// A silence this long ends a phrase: the jaw may close in it.
  static const Duration phraseBreak = Duration(milliseconds: 120);

  /// The lowest jaw anywhere inside a phrase (outside `pp` and `ff`).
  static const double phraseJawFloor = 0.12;

  /// The share of the neighbouring vowels' jaw a consonant keeps.
  static const double consonantJawShare = 0.65;

  /// A French sh/zh (/ʃ/, /ʒ/, [SpeechTimeline.roundedSh]): the lips round
  /// and push forward, barely spread.
  static const MouthShape roundedShShape = MouthShape(
    jaw: 0.15,
    pucker: 0.7,
    stretch: 0.1,
  );

  /// A closed, pressed mouth: jaw 0, the table's pucker (or the [round]ing
  /// toward a coming ou) capped at 0.3.
  static MouthShape _seal(double press, {double round = 0}) {
    final MouthShape raw = MouthShape.forViseme(Viseme.pp);
    return MouthShape(
      press: raw.press < press ? press : raw.press,
      pucker: _min(_max(raw.pucker, round), _sealPucker),
    );
  }

  /// The most a closure rounds (a rounded b before an ou).
  static const double _sealPucker = 0.3;

  /// The lips start rounding this long before an ou (/u/, /w/).
  static const Duration preRound = Duration(milliseconds: 110);

  /// The least tongue a th shows anywhere in its span (the tip past the
  /// teeth).
  static const double thTongue = 0.8;

  /// The most of a vowel each of its two lean windows takes: a 50 % middle
  /// is the vowel alone.
  static const double vowelLean = 0.15;

  /// Jaw scale for a vowel of [length]: 0.7 of its table jaw at 40 ms or
  /// less, eased to full at 100 ms (a short vowel opens a little less; a
  /// normal one opens all the way).
  static double vowelJawGain(Duration length) {
    final double x = (length.inMicroseconds / 1000 - 40) / 60;
    return 0.7 + 0.3 * _smoothstep(x);
  }

  /// Lip press as a p/b/m closure starts: the lips have just met.
  static const double sealPressStart = 0.6;

  /// Lip press at the end of a closure (compressed): a visibly pressed seal,
  /// not a rest line.
  static const double sealPress = 0.9;

  /// After a closure the mouth reaches the next shape over this window, on
  /// [releaseRamp]: about three frames at 60 fps, two at 30; into a span
  /// shorter than 100 ms over [shortBurst] of it (30 ms into a 50 ms vowel).
  static const Duration releaseBurst = Duration(milliseconds: 60);
  static const double shortBurst = 0.6;

  /// The release ramp at [x] (0-1 of [releaseBurst]): an ease-out,
  /// `1 - (1 - x)^2`, fastest as the lips part, settling into the shape.
  static double releaseRamp(double x) {
    final double r = 1 - x.clamp(0.0, 1.0);
    return 1 - r * r;
  }

  /// The release pop lasts this long after a closure (or the next span, if
  /// shorter): a sine bump that peaks halfway.
  static const Duration releasePop = Duration(milliseconds: 90);

  /// Spans shorter than this get no pop.
  static const Duration popMinSpan = Duration(milliseconds: 50);

  /// Peak jaw of the release pop, on top of the opening ramp.
  static const double popJaw = 0.08;

  /// Jaw scale for a span of loudness [weight] (0-1): 0.6 of its table
  /// value for the softest span to 0.9 for the loudest (a soft vowel still
  /// articulates: the loudness only shades it).
  static double jawGain(double weight) => 0.6 + 0.3 * weight.clamp(0.0, 1.0);

  /// Index of the span covering [t] (start inclusive, end exclusive), or -1.
  static int _indexAt(List<VisemeSpan> spans, Duration t) {
    int lo = 0;
    int hi = spans.length - 1;
    while (lo <= hi) {
      final int mid = (lo + hi) >> 1;
      final VisemeSpan span = spans[mid];
      if (t < span.start) {
        hi = mid - 1;
      } else if (t >= span.end) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }
    return -1;
  }

  static double _smoothstep(double x) {
    final double c = x.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  static double _min(double a, double b) => a < b ? a : b;
  static double _max(double a, double b) => a > b ? a : b;
}
