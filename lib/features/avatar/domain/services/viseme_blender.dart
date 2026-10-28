import '../../../../core/models/performance/performance.dart';

/// The blended mouth for one instant. [sealed] means the instant lies inside
/// a `pp` span: the lips must be fully closed now.
class MouthBlend {
  const MouthBlend({required this.shape, this.sealed = false});

  final MouthShape shape;
  final bool sealed;

  @override
  bool operator ==(Object other) =>
      other is MouthBlend && other.shape == shape && other.sealed == sealed;

  @override
  int get hashCode => Object.hash(shape, sealed);

  @override
  String toString() => 'MouthBlend($shape, sealed: $sealed)';
}

/// Coarticulation: turns a [SpeechTimeline] and a playback position into one
/// mouth shape. Neighbouring visemes lean into each other (the next one pulls
/// early in the last [anticipation], the previous one leaks back in the first
/// [carryOver]), weighted by [MouthShape.dominance], so a closure wins over a
/// vowel and an open vowel gives way. A `pp` span is a hard lip seal.
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
    final MouthShape base = _shapeOf(current);
    if (current.viseme == Viseme.pp) {
      return MouthBlend(shape: base, sealed: true);
    }

    final double start = current.start.inMicroseconds.toDouble();
    final double end = current.end.inMicroseconds.toDouble();
    final double now = t.inMicroseconds.toDouble();
    final double half = (end - start) / 2;
    final double dominance = MouthShape.dominance(current.viseme);

    final VisemeSpan? next = index + 1 < spans.length ? spans[index + 1] : null;
    final VisemeSpan? previous = index > 0 ? spans[index - 1] : null;
    final bool hasNext = next != null && next.start <= current.end;
    final bool hasPrevious = previous != null && previous.end >= current.start;

    MouthShape shape = base;

    // Leak of the previous span, decaying over the first carry window.
    if (hasPrevious) {
      final double window = _min(carryOver.inMicroseconds.toDouble(), half);
      if (window > 0 && now < start + window) {
        final double decay = 1 - _smoothstep((now - start) / window);
        final double lean = _leanBack(previous, current) * decay;
        shape = shape.lerp(_shapeOf(previous), lean);
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
  static MouthShape _shapeOf(VisemeSpan span) {
    final MouthShape raw = MouthShape.forViseme(span.viseme);
    if (span.viseme == Viseme.pp) {
      return MouthShape(
        press: raw.press < 0.6 ? 0.6 : raw.press,
        pucker: raw.pucker > 0.3 ? 0.3 : raw.pucker,
      );
    }
    return raw.copyWith(jaw: raw.jaw * span.weight.clamp(0.0, 1.0));
  }

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
