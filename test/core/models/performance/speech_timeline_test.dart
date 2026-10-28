import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';

const Duration _frame = Duration(milliseconds: 25);

Duration _ms(int ms) => Duration(milliseconds: ms);

void main() {
  group('SpeechTimeline.spanAt', () {
    final SpeechTimeline timeline = SpeechTimeline(
      visemes: <VisemeSpan>[
        VisemeSpan(viseme: Viseme.sil, start: _ms(0), end: _ms(100)),
        VisemeSpan(viseme: Viseme.aa, start: _ms(100), end: _ms(300)),
        VisemeSpan(viseme: Viseme.pp, start: _ms(300), end: _ms(400)),
      ],
      duration: _ms(400),
    );

    test('inside a span', () {
      expect(timeline.spanAt(_ms(50))?.viseme, Viseme.sil);
      expect(timeline.spanAt(_ms(250))?.viseme, Viseme.aa);
    });

    test('a boundary returns the later span', () {
      expect(timeline.spanAt(_ms(100))?.viseme, Viseme.aa);
      expect(timeline.spanAt(_ms(300))?.viseme, Viseme.pp);
      expect(timeline.spanAt(_ms(0))?.viseme, Viseme.sil);
    });

    test('null outside', () {
      expect(timeline.spanAt(_ms(400)), isNull);
      expect(timeline.spanAt(_ms(-1)), isNull);
      expect(const SpeechTimeline().spanAt(_ms(0)), isNull);
    });
  });

  group('SpeechTimeline.fromAmplitudes', () {
    final List<int> amps = <int>[
      0,
      0,
      10,
      30,
      30,
      ...List<int>.filled(10, 0),
      20,
    ];

    test('merges runs at the same mouth level only', () {
      final SpeechTimeline t = SpeechTimeline.fromAmplitudes(amps, _frame);
      expect(t.visemes.map((VisemeSpan s) => s.viseme).toList(), <Viseme>[
        Viseme.sil,
        Viseme.aa,
        Viseme.aa,
        Viseme.sil,
        Viseme.aa,
      ]);
      expect(t.visemes[0].start, _ms(0));
      expect(t.visemes[0].end, _ms(50));
      expect(t.visemes[1].start, _ms(50));
      expect(t.visemes[1].end, _ms(75));
      expect(t.visemes[2].end, _ms(125));
      expect(t.visemes[3].end, _ms(375));
      expect(t.visemes[4].end, _ms(400));
      expect(t.duration, _ms(400));
      expect(t.leadingSilence, _ms(50));
      // the loud run opens the jaw wider than the quiet frame before it
      expect(t.visemes[1].weight, closeTo(10 / 30, 1e-9));
      expect(t.visemes[2].weight, closeTo(1.0, 1e-9));
      expect(t.visemes[4].weight, closeTo(20 / 30, 1e-9));
    });

    test('one pause at 125 ms lasting 250 ms', () {
      final SpeechTimeline t = SpeechTimeline.fromAmplitudes(amps, _frame);
      final List<ProsodyMark> pauses = t.marks
          .where((ProsodyMark m) => m.kind == ProsodyMarkKind.pause)
          .toList();
      expect(pauses, hasLength(1));
      expect(pauses.single.at, _ms(125));
      expect(pauses.single.length, _ms(250));
    });

    test('leading and trailing silence are never pauses', () {
      final SpeechTimeline t = SpeechTimeline.fromAmplitudes(<int>[
        ...List<int>.filled(12, 0),
        30,
        30,
        ...List<int>.filled(12, 0),
      ], _frame);
      expect(
        t.marks.where((ProsodyMark m) => m.kind == ProsodyMarkKind.pause),
        isEmpty,
      );
      expect(t.leadingSilence, _ms(300));
    });

    test('short inner zero runs are not pauses', () {
      final SpeechTimeline t = SpeechTimeline.fromAmplitudes(<int>[
        30,
        ...List<int>.filled(7, 0), // 175 ms
        30,
      ], _frame);
      expect(
        t.marks.where((ProsodyMark m) => m.kind == ProsodyMarkKind.pause),
        isEmpty,
      );
    });

    test('amplitude maps to weight clamped to 0.15-1', () {
      final SpeechTimeline t = SpeechTimeline.fromAmplitudes(<int>[
        1,
        0,
        90,
      ], _frame);
      expect(t.visemes.first.weight, 0.15);
      expect(t.visemes.last.weight, 1);
    });

    test('stress marks keep 600 ms apart and favour the loudest', () {
      final List<int> a = List<int>.filled(40, 0);
      a[4] = 20;
      a[12] = 30; // 300 ms
      a[14] = 30; // 350 ms: too close to the first, dropped
      a[36] = 30; // 900 ms: exactly 600 ms later, kept
      a[38] = 25;
      final SpeechTimeline t = SpeechTimeline.fromAmplitudes(a, _frame);
      final List<Duration> stress = t.marks
          .where((ProsodyMark m) => m.kind == ProsodyMarkKind.stress)
          .map((ProsodyMark m) => m.at)
          .toList();
      expect(stress, <Duration>[_ms(300), _ms(900)]);
    });

    test('isQuestion follows a trailing question mark', () {
      expect(
        SpeechTimeline.fromAmplitudes(
          amps,
          _frame,
          text: 'Really? ',
        ).isQuestion,
        isTrue,
      );
      expect(
        SpeechTimeline.fromAmplitudes(amps, _frame, text: 'Really.').isQuestion,
        isFalse,
      );
      expect(SpeechTimeline.fromAmplitudes(amps, _frame).isQuestion, isFalse);
    });

    test('empty and silent inputs are valid', () {
      final SpeechTimeline empty = SpeechTimeline.fromAmplitudes(
        const <int>[],
        _frame,
      );
      expect(empty.visemes, isEmpty);
      expect(empty.duration, Duration.zero);
      final SpeechTimeline silent = SpeechTimeline.fromAmplitudes(
        List<int>.filled(8, 0),
        _frame,
      );
      expect(silent.visemes.single.viseme, Viseme.sil);
      expect(silent.marks, isEmpty);
      expect(silent.leadingSilence, _ms(200));
    });
  });

  group('SpeechTimeline.energyAt', () {
    test('interpolates between frame centres and is null without energy', () {
      const SpeechTimeline t = SpeechTimeline(
        energy: <double>[0, 1, 0.5],
        energyFrame: Duration(milliseconds: 20),
      );
      expect(t.energyAt(Duration.zero), 0);
      expect(t.energyAt(const Duration(milliseconds: 20)), closeTo(0.5, 1e-9));
      expect(t.energyAt(const Duration(milliseconds: 30)), closeTo(1, 1e-9));
      expect(t.energyAt(const Duration(seconds: 9)), 0.5);
      expect(const SpeechTimeline().energyAt(Duration.zero), isNull);
    });

    test('the amplitude fallback carries the loudness', () {
      final SpeechTimeline t = SpeechTimeline.fromAmplitudes(<int>[
        0,
        30,
        15,
      ], const Duration(milliseconds: 25));
      expect(t.energy, <double>[0, 1, 0.5]);
    });
  });
}
