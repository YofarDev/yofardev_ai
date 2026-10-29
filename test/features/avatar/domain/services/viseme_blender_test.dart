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
      // the pre-round starts 110 ms ahead
      expect(blender.shapeAt(tl, ms(85)).shape.pucker, 0);
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

    group('plosives (M3)', () {
      final SpeechTimeline tl = timeline(<VisemeSpan>[
        span(Viseme.aa, 0, 200),
        span(Viseme.pp, 200, 320),
        span(Viseme.e, 320, 620),
      ]);

      test('the closure compresses: press ramps 0.6 to 0.9, jaw 0', () {
        double last = 0;
        for (int us = 200000; us < 320000; us += 1000) {
          final MouthBlend b = blender.shapeAt(tl, Duration(microseconds: us));
          expect(b.sealed, isTrue);
          expect(b.shape.jaw, 0);
          expect(b.shape.press, greaterThanOrEqualTo(last));
          last = b.shape.press;
        }
        expect(blender.shapeAt(tl, ms(200)).shape.press, closeTo(0.6, 1e-9));
        expect(last, greaterThanOrEqualTo(0.85));
      });

      test('the release pops the jaw past the next shape, then settles', () {
        final double settled = blender.shapeAt(tl, ms(470)).shape.jaw;
        expect(settled, closeTo(0.5 * VisemeBlender.jawGain(1), 1e-9));
        // 45 ms in: the ramp at 94 %, the pop at its peak
        final MouthBlend pop = blender.shapeAt(tl, ms(365));
        expect(pop.shape.jaw, greaterThan(settled));
        expect(pop.pop, closeTo(VisemeBlender.popJaw, 1e-9));
        expect(pop.sealed, isFalse);
        expect(blender.shapeAt(tl, ms(411)).pop, 0);
        // the lips are still pressed as they part, and let go within 40 ms
        expect(blender.shapeAt(tl, ms(320)).shape.press, closeTo(0.9, 1e-9));
        expect(blender.shapeAt(tl, ms(361)).shape.press, 0);
      });

      test('a release opens on an eased 60 ms ramp, never in one frame', () {
        expect(VisemeBlender.releaseRamp(0), 0);
        expect(VisemeBlender.releaseRamp(0.5), 0.75);
        expect(VisemeBlender.releaseRamp(1), 1);
        // the first 60 fps frame after the release opens under half way
        expect(VisemeBlender.releaseRamp(16.667 / 60), lessThan(0.5));
        final double target = 0.5 * VisemeBlender.jawGain(1);
        for (int us = 320000; us < 380000; us += 2500) {
          final MouthBlend b = blender.shapeAt(tl, Duration(microseconds: us));
          final double k = VisemeBlender.releaseRamp((us - 320000) / 60000);
          expect(b.opening, closeTo(k, 1e-9), reason: '$us us');
          expect(b.shape.jaw - b.pop, closeTo(target * k, 1e-9));
          expect(b.shape.stretch, closeTo(0.55 * k, 1e-9), reason: '$us us');
        }
        // the pop is a bump: nothing at the release, all of it at 45 ms
        expect(blender.shapeAt(tl, ms(320)).pop, 0);
        expect(blender.shapeAt(tl, ms(320)).shape.jaw, 0);
        expect(blender.shapeAt(tl, ms(380)).opening, 1);
        expect(blender.shapeAt(tl, ms(200)).opening, 1);
      });

      test('a closure into silence opens without a pop', () {
        final SpeechTimeline end = timeline(<VisemeSpan>[
          span(Viseme.aa, 0, 200),
          span(Viseme.pp, 200, 320),
          span(Viseme.sil, 320, 620),
        ]);
        for (int t = 320; t < 420; t += 2) {
          final MouthBlend b = blender.shapeAt(end, ms(t));
          expect(b.pop, 0, reason: '$t ms');
          expect(b.shape.jaw, 0, reason: '$t ms');
          expect(b.sealed, isFalse, reason: '$t ms');
        }
      });

      test('a closure into a span under 50 ms opens without a pop', () {
        // p, a 20 ms vowel, p again ("pep" said fast)
        final SpeechTimeline fast = timeline(<VisemeSpan>[
          span(Viseme.pp, 0, 60),
          span(Viseme.e, 60, 80),
          span(Viseme.pp, 80, 140),
          span(Viseme.aa, 140, 440),
        ]);
        for (int t = 60; t < 80; t++) {
          expect(blender.shapeAt(fast, ms(t)).pop, 0, reason: '$t ms');
        }
        // the release into the long vowel still pops
        expect(blender.shapeAt(fast, ms(150)).pop, greaterThan(0));
      });

      test('a closure that starts the sentence is sealed from 0', () {
        final SpeechTimeline first = timeline(<VisemeSpan>[
          span(Viseme.pp, 0, 80),
          span(Viseme.aa, 80, 380),
        ]);
        for (int t = 0; t < 80; t += 5) {
          final MouthBlend b = blender.shapeAt(first, ms(t));
          expect(b.sealed, isTrue, reason: '$t ms');
          expect(b.shape.jaw, 0, reason: '$t ms');
        }
        expect(blender.shapeAt(first, ms(0)).shape.press, closeTo(0.6, 1e-9));
        expect(blender.shapeAt(first, ms(95)).pop, greaterThan(0));
      });

      test('two closures back to back stay sealed through the boundary', () {
        final SpeechTimeline twice = timeline(<VisemeSpan>[
          span(Viseme.aa, 0, 200),
          span(Viseme.pp, 200, 260),
          span(Viseme.pp, 260, 280),
          span(Viseme.aa, 280, 580),
        ]);
        for (int t = 200; t < 280; t += 2) {
          final MouthBlend b = blender.shapeAt(twice, ms(t));
          expect(b.sealed, isTrue, reason: '$t ms');
          expect(b.shape.jaw, 0, reason: '$t ms');
          expect(b.pop, 0, reason: '$t ms');
        }
        expect(blender.shapeAt(twice, ms(290)).pop, greaterThan(0));
      });

      test('no pop without a closure before the span', () {
        final SpeechTimeline plain = timeline(<VisemeSpan>[
          span(Viseme.aa, 0, 200),
          span(Viseme.e, 200, 500),
        ]);
        for (int t = 200; t < 300; t += 5) {
          expect(blender.shapeAt(plain, ms(t)).pop, 0);
        }
      });
    });

    test('f/v and s differ in the lower lip mid-span', () {
      final SpeechTimeline tl = timeline(<VisemeSpan>[
        span(Viseme.ff, 0, 200),
        span(Viseme.ss, 200, 400),
      ]);
      final double ff = blender.shapeAt(tl, ms(100)).shape.lipTuck;
      final double ss = blender.shapeAt(tl, ms(300)).shape.lipTuck;
      expect(ff - ss, greaterThanOrEqualTo(0.9));
    });

    group('critic round 7', () {
      test('lips pre-round 110 ms before an ou: no grin into "you"', () {
        final SpeechTimeline tl = timeline(<VisemeSpan>[
          span(Viseme.ih, 0, 200),
          span(Viseme.ou, 200, 400),
        ]);
        expect(blender.shapeAt(tl, ms(89)).shape.pucker, 0);
        // halfway through the 110 ms pre-round: half rounded, half as wide
        final MouthShape mid = blender.shapeAt(tl, ms(145)).shape;
        expect(mid.pucker, closeTo(0.5, 1e-9));
        expect(mid.stretch, lessThanOrEqualTo(0.5 * 0.45 + 1e-9));
        // never wider than the rounding allows (an sh keeps both: below)
        for (int t = 90; t < 400; t += 5) {
          final MouthShape m = blender.shapeAt(tl, ms(t)).shape;
          expect(m.stretch, lessThanOrEqualTo(1 - m.pucker + 1e-9));
        }
      });

      test('the lips round and unspread ahead of an oh ("so")', () {
        final SpeechTimeline tl = timeline(<VisemeSpan>[
          span(Viseme.ss, 0, 120),
          span(Viseme.oh, 120, 200),
        ]);
        // 110 ms ahead: the s is still fully spread
        expect(blender.shapeAt(tl, ms(10)).shape.stretch, closeTo(0.55, 1e-9));
        expect(blender.shapeAt(tl, ms(10)).shape.pucker, 0);
        // halfway: no spread left, half the oh's rounding
        final MouthShape mid = blender.shapeAt(tl, ms(65)).shape;
        expect(mid.stretch, 0);
        expect(mid.pucker, closeTo(0.3, 1e-9));
        // at the onset the oh is fully rounded
        expect(blender.shapeAt(tl, ms(119)).shape.pucker, greaterThan(0.59));
        expect(blender.shapeAt(tl, ms(119)).shape.stretch, 0);
      });

      test('an oh rounds ahead only for an ou (the oh-ou glide)', () {
        final SpeechTimeline tl = timeline(<VisemeSpan>[
          span(Viseme.oh, 0, 300),
          span(Viseme.oh, 300, 600),
        ]);
        expect(blender.shapeAt(tl, ms(250)).shape.pucker, closeTo(0.6, 1e-9));
      });

      test('a French sh is rounded and barely spread', () {
        const SpeechTimeline tl = SpeechTimeline(
          visemes: <VisemeSpan>[
            VisemeSpan(
              viseme: Viseme.ch,
              start: Duration.zero,
              end: Duration(milliseconds: 400),
            ),
          ],
          duration: Duration(milliseconds: 400),
          roundedSh: true,
        );
        final MouthShape m = blender.shapeAt(tl, ms(200)).shape;
        expect(m.pucker, closeTo(0.7, 1e-9));
        expect(m.stretch, closeTo(0.1, 1e-9));
        expect(m, VisemeBlender.roundedShShape.copyWith(jaw: m.jaw));
      });

      test('sh keeps its spread with its rounding when no ou is near', () {
        final SpeechTimeline tl = timeline(<VisemeSpan>[
          span(Viseme.ch, 0, 400),
        ]);
        final MouthShape m = blender.shapeAt(tl, ms(200)).shape;
        expect(m.pucker, closeTo(0.7, 1e-9));
        expect(m.stretch, closeTo(0.38, 1e-9));
      });

      test('the pre-round reaches through a consonant', () {
        final SpeechTimeline tl = timeline(<VisemeSpan>[
          span(Viseme.ih, 0, 200),
          span(Viseme.dd, 200, 260),
          span(Viseme.ou, 260, 460),
        ]);
        // 60 ms before the ou: smoothstep(50 / 110) of full rounding
        const double x = 50 / 110;
        expect(
          blender.shapeAt(tl, ms(200)).shape.pucker,
          closeTo(x * x * (3 - 2 * x), 1e-9),
        );
      });

      test('a tight ou mid-span: full pucker, no stretch', () {
        final SpeechTimeline tl = timeline(<VisemeSpan>[
          span(Viseme.e, 0, 200),
          span(Viseme.ou, 200, 600),
        ]);
        final MouthShape m = blender.shapeAt(tl, ms(400)).shape;
        expect(m.pucker, 1);
        expect(m.stretch, 0);
        expect(m.jaw, closeTo(0.15 * VisemeBlender.jawGain(1), 1e-9));
      });

      test('a release into ou opens jaw and rounding on one ramp', () {
        final SpeechTimeline tl = timeline(<VisemeSpan>[
          span(Viseme.aa, 0, 100),
          span(Viseme.pp, 100, 200),
          span(Viseme.ou, 200, 400),
        ]);
        // the closure is already rounded as far as a seal allows
        expect(blender.shapeAt(tl, ms(199)).shape.pucker, closeTo(0.3, 1e-9));
        final double jawTarget = 0.15 * VisemeBlender.jawGain(1);
        for (int us = 200000; us < 220000; us += 1000) {
          final MouthBlend b = blender.shapeAt(tl, Duration(microseconds: us));
          final double jaw = (b.shape.jaw - b.pop) / jawTarget;
          final double round = (b.shape.pucker - 0.3) / 0.7;
          expect(round, closeTo(jaw, 1e-9), reason: '$us us');
          expect(b.shape.stretch, 0, reason: '$us us');
        }
      });

      test('th keeps the tongue up through the whole span', () {
        final SpeechTimeline tl = timeline(<VisemeSpan>[
          span(Viseme.ss, 0, 100),
          span(Viseme.th, 100, 160),
          span(Viseme.e, 160, 300),
        ]);
        for (int t = 100; t < 160; t++) {
          expect(
            blender.shapeAt(tl, ms(t)).shape.tongueUp,
            greaterThanOrEqualTo(0.6),
            reason: '$t ms',
          );
        }
      });

      test('a vowel opens by its length: 50 % at 40 ms, full from 160 ms', () {
        expect(VisemeBlender.vowelJawGain(ms(40)), 0.5);
        expect(VisemeBlender.vowelJawGain(ms(100)), closeTo(0.75, 1e-9));
        expect(VisemeBlender.vowelJawGain(ms(160)), 1);
        expect(VisemeBlender.vowelJawGain(ms(400)), 1);
        final SpeechTimeline tl = timeline(<VisemeSpan>[
          span(Viseme.pp, 0, 100),
          span(Viseme.aa, 100, 150),
          span(Viseme.pp, 150, 250),
        ]);
        double peak = 0;
        for (int t = 100; t < 150; t++) {
          final double jaw = blender.shapeAt(tl, ms(t)).shape.jaw;
          peak = jaw > peak ? jaw : peak;
        }
        // a 50 ms vowel between closures: half its table jaw, plus the pop
        final double half =
            0.9 * VisemeBlender.jawGain(1) * VisemeBlender.vowelJawGain(ms(50));
        expect(peak, lessThanOrEqualTo(half + VisemeBlender.popJaw + 1e-9));
        expect(half, lessThan(0.56));
        // consonants keep their table jaw
        final SpeechTimeline kk = timeline(<VisemeSpan>[
          span(Viseme.kk, 0, 50),
        ]);
        expect(
          blender.shapeAt(kk, ms(25)).shape.jaw,
          closeTo(
            MouthShape.forViseme(Viseme.kk).jaw * VisemeBlender.jawGain(1),
            1e-9,
          ),
        );
      });
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
      expect(a, isNot(const MouthBlend(shape: MouthShape(jaw: 0.5), pop: 0.1)));
    });
  });
}
