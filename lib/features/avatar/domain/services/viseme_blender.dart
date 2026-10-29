import 'dart:math' as math;

import '../../../../core/models/performance/performance.dart';

/// The blended mouth for one instant. [sealed] means the instant lies inside
/// a `pp` span: the lips must be fully closed now. [pop] is the part of
/// `shape.jaw` that is the plosive release pop (0 outside the 50 ms after a
/// closure), so a consumer that smooths the jaw can add it back on time.
class MouthBlend {
  const MouthBlend({required this.shape, this.sealed = false, this.pop = 0});

  final MouthShape shape;
  final bool sealed;
  final double pop;

  @override
  bool operator ==(Object other) =>
      other is MouthBlend &&
      other.shape == shape &&
      other.sealed == sealed &&
      other.pop == pop;

  @override
  int get hashCode => Object.hash(shape, sealed, pop);

  @override
  String toString() => 'MouthBlend($shape, sealed: $sealed, pop: $pop)';
}

/// Coarticulation: turns a [SpeechTimeline] and a playback position into one
/// mouth shape. Neighbouring visemes lean into each other (the next one pulls
/// early in the last [anticipation], the previous one leaks back in the first
/// [carryOver]), weighted by [MouthShape.dominance], so a closure wins over a
/// vowel and an open vowel gives way. A `pp` span is a hard lip seal that
/// compresses (press [sealPressStart] → [sealPress] across the span) and
/// releases with a pop: the jaw bursts open within [releaseBurst] and
/// overshoots the next shape by [popJaw], eased out over [releasePop].
///
/// The result is continuous in time: both lean windows are clamped to half
/// the span, so they never overlap, and each leak starts exactly where the
/// previous span's anticipation ended.
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
        shape: _seal(sealPressStart + (sealPress - sealPressStart) * k),
        sealed: true,
      );
    }
    final MouthShape base = _shapeOf(current);
    final double half = (end - start) / 2;
    final double dominance = MouthShape.dominance(current.viseme);

    final VisemeSpan? next = index + 1 < spans.length ? spans[index + 1] : null;
    final VisemeSpan? previous = index > 0 ? spans[index - 1] : null;
    final bool hasNext = next != null && next.start <= current.end;
    final bool hasPrevious = previous != null && previous.end >= current.start;

    final bool release = hasPrevious && previous.viseme == Viseme.pp;

    MouthShape shape = base;

    // Leak of the previous span, decaying over the first carry window. After
    // a closure the pressed lips peel apart this way, but the jaw does not
    // leak: it bursts open (below).
    if (hasPrevious) {
      final double window = _min(carryOver.inMicroseconds.toDouble(), half);
      if (window > 0 && now < start + window) {
        final double decay = 1 - _smoothstep((now - start) / window);
        final double lean = _leanBack(previous, current) * decay;
        final double jaw = shape.jaw;
        shape = shape.lerp(_leakOf(previous), lean);
        if (release) {
          shape = shape.copyWith(jaw: jaw);
        }
      }
    }

    // Anticipation of the next span, rising over the last window.
    if (hasNext) {
      final double window = _min(anticipation.inMicroseconds.toDouble(), half);
      if (window > 0 && now > end - window) {
        final double rise = _smoothstep((now - (end - window)) / window);
        final double pull =
            MouthShape.dominance(next.viseme) /
            _max(dominance, MouthShape.dominance(next.viseme));
        shape = shape.lerp(_shapeOf(next), rise * pull);
      }
    }

    if (release) {
      final double since = now - start;
      final double burst = releaseBurst.inMicroseconds.toDouble();
      final double popWindow = releasePop.inMicroseconds.toDouble();
      final double opened = shape.jaw * _smoothstep(since / burst);
      double pop = 0;
      if (since < popWindow) {
        final double amount =
            popJaw * 0.5 * (1 + math.cos(math.pi * since / popWindow));
        pop = _min(opened + amount, 1) - opened;
      }
      if (since < burst || pop > 0) {
        return MouthBlend(
          shape: shape.copyWith(jaw: opened + pop),
          pop: pop,
        );
      }
    }
    return MouthBlend(shape: shape);
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
  /// A closure is approached at its lightest press (where it starts).
  static MouthShape _shapeOf(VisemeSpan span) {
    if (span.viseme == Viseme.pp) {
      return _seal(sealPressStart);
    }
    final MouthShape raw = MouthShape.forViseme(span.viseme);
    return raw.copyWith(jaw: (raw.jaw * jawGain(span.weight)).clamp(0.0, 1.0));
  }

  /// What [previous] leaves in the mouth as the next span starts: a closure
  /// leaves its fully compressed lips.
  static MouthShape _leakOf(VisemeSpan previous) =>
      previous.viseme == Viseme.pp ? _seal(sealPress) : _shapeOf(previous);

  /// A closed, pressed mouth: jaw 0, the table's pucker capped at 0.3.
  static MouthShape _seal(double press) {
    final MouthShape raw = MouthShape.forViseme(Viseme.pp);
    return MouthShape(
      press: raw.press < press ? press : raw.press,
      pucker: raw.pucker > 0.3 ? 0.3 : raw.pucker,
    );
  }

  /// Lip press as a p/b/m closure starts: the lips have just met.
  static const double sealPressStart = 0.6;

  /// Lip press at the end of a closure (compressed): a visibly pressed seal,
  /// not a rest line.
  static const double sealPress = 0.9;

  /// After a closure the jaw reaches the next shape within this window.
  static const Duration releaseBurst = Duration(milliseconds: 20);

  /// The release pop lasts this long after a closure.
  static const Duration releasePop = Duration(milliseconds: 50);

  /// Jaw overshoot of the release pop over the next shape, at its start.
  static const double popJaw = 0.08;

  /// Jaw scale for a span of loudness [weight] (0-1): even a soft vowel
  /// opens about half way, a loud one a third past its table value
  /// (articulation reads at phone size).
  static double jawGain(double weight) => 0.45 + 0.75 * weight.clamp(0.0, 1.0);

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
