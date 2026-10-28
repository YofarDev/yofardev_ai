import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/features/avatar/domain/models/face_frame.dart';
import 'package:yofardev_ai/features/avatar/domain/models/performance_intent.dart';
import 'package:yofardev_ai/features/avatar/domain/services/face_performer.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

const Duration _frame = Duration(microseconds: 16667);

Duration _ms(int ms) => Duration(milliseconds: ms);

class _Rig {
  _Rig() {
    performer = FacePerformer(
      intents: intents.stream,
      playback: playback.stream,
      speechPosition: () => position,
    );
  }

  final StreamController<PerformanceIntent> intents =
      StreamController<PerformanceIntent>.broadcast(sync: true);
  final StreamController<PlaybackEvent> playback =
      StreamController<PlaybackEvent>.broadcast(sync: true);
  Duration? position;
  late final FacePerformer performer;

  void mood(AvatarMood m) => intents.add(
    PerformanceIntent(emotion: emotionForMood(m), face: actionUnitsForMood(m)),
  );

  void speak(SpeechTimeline t) {
    position = Duration.zero;
    playback.add(const SpeakingStartedEvent());
    playback.add(SpeechTimelineEvent(t));
  }

  /// Steps [n] frames, advancing the speech position with time while speaking.
  List<FaceFrame> run(int n) {
    final List<FaceFrame> out = <FaceFrame>[];
    for (int i = 0; i < n; i++) {
      final Duration? p = position;
      if (p != null) {
        position = p + _frame;
      }
      out.add(performer.step(_frame));
    }
    return out;
  }

  Future<void> dispose() async {
    await performer.dispose();
    await intents.close();
    await playback.close();
  }
}

SpeechTimeline _timeline(
  List<(Viseme, int, int)> spans, {
  List<ProsodyMark> marks = const <ProsodyMark>[],
  bool question = false,
  int leading = 0,
}) {
  return SpeechTimeline(
    visemes: <VisemeSpan>[
      for (final (Viseme v, int a, int b) in spans)
        VisemeSpan(viseme: v, start: _ms(a), end: _ms(b)),
    ],
    marks: marks,
    duration: _ms(spans.last.$3),
    leadingSilence: _ms(leading),
    isQuestion: question,
  );
}

List<double> _aus(ActionUnits a) => <double>[
  a.browInnerUp,
  a.browOuterUp,
  a.browLower,
  a.lidTighten,
  a.upperLidRaise,
  a.cheekRaise,
  a.noseWrinkle,
  a.lipCornerPull,
  a.lipCornerDepress,
  a.lipStretch,
  a.lipPucker,
  a.lipPress,
  a.jawDrop,
  a.dimpler,
];

void main() {
  late _Rig rig;

  setUp(() => rig = _Rig());
  tearDown(() => rig.dispose());

  group('emotion', () {
    test('a mood reaches its AU preset within 0.6 s', () {
      rig.mood(AvatarMood.happy);
      final FaceFrame f = rig.run(36).last;
      final List<double> got = _aus(f.au);
      final List<double> want = _aus(actionUnitsForMood(AvatarMood.happy));
      for (int i = 0; i < got.length; i++) {
        expect(got[i], closeTo(want[i], 0.02), reason: 'AU $i');
      }
    });

    test('happy to sad never leaves the range of the two presets', () {
      rig.mood(AvatarMood.happy);
      rig.run(90);
      rig.mood(AvatarMood.sad);
      final List<double> a = _aus(actionUnitsForMood(AvatarMood.happy));
      final List<double> b = _aus(actionUnitsForMood(AvatarMood.sad));
      for (final FaceFrame f in rig.run(90)) {
        final List<double> got = _aus(f.au);
        for (int i = 0; i < got.length; i++) {
          final double lo = a[i] < b[i] ? a[i] : b[i];
          final double hi = a[i] < b[i] ? b[i] : a[i];
          expect(got[i], inInclusiveRange(lo - 1e-6, hi + 1e-6));
        }
      }
    });
  });

  group('speech', () {
    test('the first frame inside a p/b/m span is sealed', () {
      rig.speak(
        _timeline(<(Viseme, int, int)>[
          (Viseme.aa, 0, 300),
          (Viseme.pp, 300, 350),
          (Viseme.aa, 350, 700),
        ]),
      );
      final List<FaceFrame> frames = rig.run(30);
      // frame i is stepped at position (i + 1) * 16.7 ms
      final int inside = frames.indexWhere(
        (FaceFrame f) => f.au.lipPress >= 0.6 && f.au.jawDrop == 0,
      );
      expect(inside, isNonNegative);
      expect((inside + 1) * 16.667, lessThanOrEqualTo(300 + 16.7));
      // the mouth is wide open mid-vowel
      expect(frames[10].au.jawDrop, greaterThan(0.6));
    });

    test('a mood change mid-speech keeps the seal and moves the corners', () {
      rig.speak(
        _timeline(<(Viseme, int, int)>[
          (Viseme.aa, 0, 400),
          (Viseme.pp, 400, 460),
          (Viseme.aa, 460, 800),
        ]),
      );
      rig.run(6);
      rig.mood(AvatarMood.happy);
      final List<FaceFrame> frames = rig.run(30);
      final FaceFrame sealed = frames[19]; // position ~433 ms
      expect(sealed.au.jawDrop, 0);
      expect(sealed.au.lipPress, greaterThanOrEqualTo(0.6));
      expect(sealed.au.lipCornerPull, greaterThan(0.3));
    });

    test('stop mid-sentence relaxes the mouth within 300 ms', () {
      rig.speak(
        _timeline(
          <(Viseme, int, int)>[(Viseme.aa, 0, 1000)],
          marks: <ProsodyMark>[
            const ProsodyMark(
              kind: ProsodyMarkKind.pause,
              at: Duration(milliseconds: 600),
              length: Duration(milliseconds: 250),
            ),
          ],
        ),
      );
      rig.run(12);
      rig.playback.add(const SpeakingStoppedEvent());
      rig.position = null;
      final int serial = rig.performer.frame.blinkSerial;
      final FaceFrame f = rig.run(18).last;
      expect(f.au.jawDrop, lessThan(0.02));
      expect(f.au.lipStretch, lessThan(0.02));
      expect(f.blinkSerial, serial);
    });
  });

  group('prosody', () {
    test('brows rise before a pitch peak and peak near it', () {
      rig.speak(
        _timeline(
          <(Viseme, int, int)>[(Viseme.aa, 0, 2000)],
          marks: <ProsodyMark>[
            const ProsodyMark(
              kind: ProsodyMarkKind.pitchPeak,
              at: Duration(milliseconds: 1000),
            ),
          ],
        ),
      );
      final List<FaceFrame> frames = rig.run(90);
      double at(int ms) => frames[(ms / 16.667).round() - 1].au.browOuterUp;
      expect(at(990), greaterThan(at(850) + 0.05));
      int best = 0;
      for (int i = 1; i < frames.length; i++) {
        if (frames[i].au.browOuterUp > frames[best].au.browOuterUp) {
          best = i;
        }
      }
      expect(((best + 1) * 16.667 - 1000).abs(), lessThanOrEqualTo(150 + 1));
    });

    test('two stresses 300 ms apart give one nod', () {
      rig.speak(
        _timeline(
          <(Viseme, int, int)>[(Viseme.aa, 0, 2000)],
          marks: <ProsodyMark>[
            const ProsodyMark(
              kind: ProsodyMarkKind.stress,
              at: Duration(milliseconds: 600),
            ),
            const ProsodyMark(
              kind: ProsodyMarkKind.stress,
              at: Duration(milliseconds: 900),
            ),
          ],
        ),
      );
      final List<double> nod = <double>[
        for (final FaceFrame f in rig.run(90)) f.nodPitch,
      ];
      int minima = 0;
      for (int i = 1; i < nod.length - 1; i++) {
        if (nod[i] < -0.05 && nod[i] <= nod[i - 1] && nod[i] < nod[i + 1]) {
          minima++;
        }
      }
      expect(minima, 1);
    });

    test('a pause gets exactly one blink; autoBlink is off while speaking', () {
      rig.speak(
        _timeline(
          <(Viseme, int, int)>[
            (Viseme.aa, 0, 2000),
            (Viseme.sil, 2000, 2250),
            (Viseme.aa, 2250, 3000),
          ],
          marks: <ProsodyMark>[
            const ProsodyMark(
              kind: ProsodyMarkKind.pause,
              at: Duration(milliseconds: 2000),
              length: Duration(milliseconds: 250),
            ),
          ],
        ),
      );
      final List<FaceFrame> frames = rig.run(150);
      final int before = frames[118].blinkSerial; // ~1983 ms
      final int after = frames[134].blinkSerial; // ~2250 ms
      expect(after - before, 1);
      expect(frames.every((FaceFrame f) => !f.autoBlink), isTrue);
      rig.playback.add(const AnimationCompletedEvent());
      rig.position = null;
      expect(rig.run(12).last.autoBlink, isFalse);
      expect(rig.run(18).last.autoBlink, isTrue);
    });

    test('a question tilts the head at its end', () {
      rig.speak(
        _timeline(<(Viseme, int, int)>[(Viseme.aa, 0, 1500)], question: true),
      );
      final List<FaceFrame> frames = rig.run(88);
      expect(frames[30].roll, lessThan(0.02));
      expect(frames.last.roll, greaterThan(0.2));
      expect(frames.last.nodPitch, greaterThan(0.05));
    });

    test('a breath fills the leading silence', () {
      rig.speak(
        _timeline(<(Viseme, int, int)>[
          (Viseme.sil, 0, 250),
          (Viseme.aa, 250, 1200),
        ], leading: 250),
      );
      final List<FaceFrame> frames = rig.run(60);
      expect(frames[13].breath, greaterThan(0.9)); // ~233 ms
      expect(frames[59].breath, lessThan(0.05)); // ~1 s
    });
  });

  group('round-1 critic fixes', () {
    test('the jaw eases shut over the 100 ms before a seal', () {
      rig.speak(
        _timeline(<(Viseme, int, int)>[
          (Viseme.aa, 0, 600),
          (Viseme.pp, 600, 680),
          (Viseme.aa, 680, 1000),
        ]),
      );
      final List<FaceFrame> frames = rig.run(36);
      // frame i is stepped at position (i + 1) * 16.7 ms; the seal is at 600 ms
      final List<double> jaw = <double>[
        for (int i = 29; i < 35; i++) frames[i].au.jawDrop,
      ];
      for (int i = 1; i < jaw.length; i++) {
        expect(jaw[i], lessThanOrEqualTo(jaw[i - 1] + 1e-9));
        // no single-frame snap from open to shut
        expect(jaw[i - 1] - jaw[i], lessThan(0.35));
      }
      expect(frames[35].au.jawDrop, 0);
    });

    test('a pause inside the sentence is breathed for', () {
      rig.speak(
        _timeline(
          <(Viseme, int, int)>[
            (Viseme.aa, 0, 1500),
            (Viseme.sil, 1500, 1800),
            (Viseme.aa, 1800, 2500),
          ],
          marks: <ProsodyMark>[
            const ProsodyMark(
              kind: ProsodyMarkKind.pause,
              at: Duration(milliseconds: 1500),
              length: Duration(milliseconds: 300),
            ),
          ],
        ),
      );
      final List<FaceFrame> frames = rig.run(120);
      expect(frames[60].breath, lessThan(0.05)); // ~1 s, mid-phrase
      expect(frames[107].breath, greaterThan(0.6)); // ~1.8 s, end of pause
    });

    test('the question tilt holds after the audio ends', () {
      rig.speak(
        _timeline(<(Viseme, int, int)>[(Viseme.aa, 0, 1200)], question: true),
      );
      rig.run(72);
      rig.playback.add(const AnimationCompletedEvent());
      rig.position = null;
      expect(rig.run(36).last.roll, greaterThan(0.25)); // 600 ms after the end
      expect(rig.run(60).last.roll, lessThan(0.1)); // released by ~1.6 s
    });

    test('a sad mood lifts only the inner brows on a pitch peak', () {
      rig.mood(AvatarMood.sad);
      rig.run(60);
      final double outerBefore = rig.performer.frame.au.browOuterUp;
      rig.speak(
        _timeline(
          <(Viseme, int, int)>[(Viseme.aa, 0, 1000)],
          marks: <ProsodyMark>[
            const ProsodyMark(
              kind: ProsodyMarkKind.pitchPeak,
              at: Duration(milliseconds: 500),
            ),
          ],
        ),
      );
      final List<FaceFrame> frames = rig.run(36);
      final FaceFrame top = frames[29]; // ~500 ms
      expect(top.au.browOuterUp, closeTo(outerBefore, 0.02));
      expect(top.au.browInnerUp, greaterThan(frames[5].au.browInnerUp + 0.1));
    });
  });

  test('settles at rest and is unsettled during a pulse', () {
    rig.run(60);
    expect(rig.performer.isSettled, isTrue);
    rig.speak(_timeline(<(Viseme, int, int)>[(Viseme.aa, 0, 500)]));
    rig.run(5);
    expect(rig.performer.isSettled, isFalse);
  });

  test('dispose cancels both subscriptions', () async {
    await rig.performer.dispose();
    expect(rig.intents.hasListener, isFalse);
    expect(rig.playback.hasListener, isFalse);
  });
}
