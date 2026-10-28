import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/features/avatar/domain/services/viseme_blender.dart';

Duration ms(int v) => Duration(milliseconds: v);

VisemeSpan span(Viseme v, int start, int end, {double weight = 1.0}) =>
    VisemeSpan(viseme: v, start: ms(start), end: ms(end), weight: weight);

SpeechTimeline timeline(List<VisemeSpan> spans) => SpeechTimeline(
  visemes: spans,
  duration: spans.isEmpty ? Duration.zero : spans.last.end,
);

List<double> channels(MouthShape s) => <double>[
  s.jaw,
  s.pucker,
  s.stretch,
  s.press,
  s.lipTuck,
  s.tongueUp,
];

void main() {
  const VisemeBlender blender = VisemeBlender();

  group('VisemeBlender', () {
    test(
      'mid-span of a lone aa gives the aa shape, jaw scaled by loudness',
      () {
        final SpeechTimeline tl = timeline(<VisemeSpan>[
          span(Viseme.aa, 0, 1000, weight: 0.8),
        ]);
        final MouthBlend b = blender.shapeAt(tl, ms(500));
        expect(b.sealed, isFalse);
        expect(b.shape.jaw, closeTo(0.9 * VisemeBlender.jawGain(0.8), 1e-9));
        expect(b.shape.stretch, closeTo(0.15, 1e-9));
        expect(b.shape.pucker, 0);
      },
    );

    test('weight scales the jaw only', () {
      final SpeechTimeline full = timeline(<VisemeSpan>[
        span(Viseme.e, 0, 1000),
      ]);
      final SpeechTimeline half = timeline(<VisemeSpan>[
        span(Viseme.e, 0, 1000, weight: 0.5),
      ]);
      final MouthShape a = blender.shapeAt(full, ms(500)).shape;
      final MouthShape b = blender.shapeAt(half, ms(500)).shape;
      expect(
        b.jaw,
        closeTo(
          a.jaw * VisemeBlender.jawGain(0.5) / VisemeBlender.jawGain(1),
          1e-9,
        ),
      );
      expect(b.pucker, a.pucker);
      expect(b.stretch, a.stretch);
      expect(b.press, a.press);
      expect(b.lipTuck, a.lipTuck);
      expect(b.tongueUp, a.tongueUp);
    });

    test('anticipates a following ou: pucker rises before the boundary', () {
      final SpeechTimeline tl = timeline(<VisemeSpan>[
        span(Viseme.aa, 0, 200),
        span(Viseme.ou, 200, 400),
      ]);
      expect(blender.shapeAt(tl, ms(100)).shape.pucker, 0);
      expect(blender.shapeAt(tl, ms(165)).shape.pucker, greaterThan(0.2));
    });

    test('a closure pulls the jaw shut early: aa to pp', () {
      final SpeechTimeline tl = timeline(<VisemeSpan>[
        span(Viseme.aa, 0, 200),
        span(Viseme.pp, 200, 260),
      ]);
      expect(blender.shapeAt(tl, ms(165)).shape.jaw, lessThan(0.6));
      expect(blender.shapeAt(tl, ms(165)).sealed, isFalse);
    });

    test('a vowel barely moves a closure: pp is sealed whatever follows', () {
      final SpeechTimeline tl = timeline(<VisemeSpan>[
        span(Viseme.aa, 0, 200),
        span(Viseme.pp, 200, 400),
        span(Viseme.ou, 400, 600),
      ]);
      for (int t = 200; t < 400; t += 5) {
        final MouthBlend b = blender.shapeAt(tl, ms(t));
        expect(b.sealed, isTrue, reason: 'at $t ms');
        expect(b.shape.jaw, 0);
        expect(b.shape.press, greaterThanOrEqualTo(0.6));
        expect(b.shape.pucker, lessThanOrEqualTo(0.3));
      }
    });

    test('every t inside a 50 ms pp span is sealed with jaw 0', () {
      final SpeechTimeline tl = timeline(<VisemeSpan>[
        span(Viseme.aa, 0, 200),
        span(Viseme.pp, 200, 250),
        span(Viseme.oh, 250, 450),
      ]);
      for (int us = 200000; us < 250000; us += 1000) {
        final MouthBlend b = blender.shapeAt(tl, Duration(microseconds: us));
        expect(b.sealed, isTrue, reason: 'at $us us');
        expect(b.shape.jaw, 0);
        expect(b.shape.press, greaterThanOrEqualTo(0.6));
      }
    });

    test('a 30 ms pp span (shorter than guaranteed) is sealed throughout', () {
      final SpeechTimeline tl = timeline(<VisemeSpan>[
        span(Viseme.aa, 0, 100),
        span(Viseme.pp, 100, 130),
        span(Viseme.aa, 130, 300),
      ]);
      for (int us = 100000; us < 130000; us += 500) {
        final MouthBlend b = blender.shapeAt(tl, Duration(microseconds: us));
        expect(b.sealed, isTrue, reason: 'at $us us');
        expect(b.shape.jaw, 0);
        expect(b.shape.press, greaterThanOrEqualTo(0.6));
      }
    });

    test('before and after the timeline is rest', () {
      final SpeechTimeline tl = timeline(<VisemeSpan>[
        span(Viseme.aa, 100, 300),
      ]);
      for (final Duration t in <Duration>[
        const Duration(milliseconds: -50),
        Duration.zero,
        ms(99),
        ms(300),
        ms(5000),
      ]) {
        final MouthBlend b = blender.shapeAt(tl, t);
        expect(b.shape, MouthShape.rest, reason: 'at $t');
        expect(b.sealed, isFalse);
      }
      expect(
        blender.shapeAt(const SpeechTimeline(), ms(10)).shape,
        MouthShape.rest,
      );
    });

    test('continuous in t across a 6-span timeline (except into pp)', () {
      final SpeechTimeline tl = timeline(<VisemeSpan>[
        span(Viseme.sil, 0, 100),
        span(Viseme.aa, 100, 260),
        span(Viseme.pp, 260, 330),
        span(Viseme.e, 330, 450),
        span(Viseme.ff, 450, 540),
        span(Viseme.ou, 540, 700),
      ]);
      MouthBlend prev = blender.shapeAt(tl, Duration.zero);
      for (int t = 5; t < 700; t += 5) {
        final MouthBlend cur = blender.shapeAt(tl, ms(t));
        final bool ppEntry = cur.sealed && !prev.sealed;
        if (!ppEntry) {
          final List<double> a = channels(prev.shape);
          final List<double> c = channels(cur.shape);
          for (int i = 0; i < a.length; i++) {
            expect(
              (c[i] - a[i]).abs(),
              lessThanOrEqualTo(0.35),
              reason: 'channel $i jumped at $t ms',
            );
          }
        }
        prev = cur;
      }
    });

    test('MouthBlend has value equality', () {
      const MouthBlend a = MouthBlend(shape: MouthShape(jaw: 0.5));
      const MouthBlend b = MouthBlend(shape: MouthShape(jaw: 0.5));
      const MouthBlend c = MouthBlend(
        shape: MouthShape(jaw: 0.5),
        sealed: true,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
