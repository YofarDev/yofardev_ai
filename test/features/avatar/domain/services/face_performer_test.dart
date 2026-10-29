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
  _Rig({int seed = 7}) {
    performer = FacePerformer(
      intents: intents.stream,
      playback: playback.stream,
      speechPosition: () => position,
      seed: seed,
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
      rig.playback.add(const SpeakingStoppedEvent(interrupted: true));
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

  group('stop semantics and review fixes', () {
    SpeechTimeline question() =>
        _timeline(<(Viseme, int, int)>[(Viseme.aa, 0, 1200)], question: true);

    test('a natural stop after completion keeps the question tilt', () {
      rig.speak(question());
      rig.run(72);
      // the app: the animation completes, then the cubit stops the sentence
      rig.playback.add(const AnimationCompletedEvent());
      rig.playback.add(const SpeakingStoppedEvent());
      rig.position = null;
      expect(rig.run(24).last.roll, greaterThan(0.5));
    });

    test('a natural stop before completion still completes', () {
      rig.speak(question());
      rig.run(72);
      rig.playback.add(const SpeakingStoppedEvent());
      rig.position = null;
      expect(rig.run(24).last.roll, greaterThan(0.5));
    });

    test('an interruption drops the end-of-sentence acting', () {
      rig.speak(question());
      rig.run(72);
      rig.playback.add(const SpeakingStoppedEvent(interrupted: true));
      rig.position = null;
      expect(rig.run(24).last.roll, lessThan(0.4));
      expect(rig.run(30).last.roll, lessThan(0.02));
    });

    test('a position that vanishes mid-sentence relaxes the mouth', () {
      rig.speak(_timeline(<(Viseme, int, int)>[(Viseme.aa, 0, 2000)]));
      expect(rig.run(20).last.au.jawDrop, greaterThan(0.5));
      // the animation was cancelled; the stop event has not arrived yet
      rig.position = null;
      expect(rig.run(18).last.au.jawDrop, lessThan(0.05));
    });

    test('the pre-roll breath is drawn before the voice', () {
      rig.playback.add(const SpeechPrerollEvent(Duration(milliseconds: 200)));
      final List<FaceFrame> frames = rig.run(12); // 200 ms
      expect(frames[5].breath, greaterThan(0.3));
      expect(frames[5].au.jawDrop, greaterThan(0.02)); // lips parted inhaling
      expect(frames.last.breath, greaterThan(0.9));
      expect(frames.last.au.jawDrop, lessThan(0.02)); // closed by the onset
    });

    test('reduce motion keeps the mouth but drops nods, tilt and breath', () {
      rig.performer.reduceMotion = true;
      rig.speak(
        _timeline(
          <(Viseme, int, int)>[(Viseme.aa, 0, 1500)],
          marks: <ProsodyMark>[
            const ProsodyMark(
              kind: ProsodyMarkKind.stress,
              at: Duration(milliseconds: 500),
            ),
          ],
          question: true,
          leading: 200,
        ),
      );
      final List<FaceFrame> frames = rig.run(90);
      expect(frames.every((FaceFrame f) => f.nodPitch == 0), isTrue);
      expect(frames.every((FaceFrame f) => f.roll == 0), isTrue);
      expect(frames.every((FaceFrame f) => f.breath == 0), isTrue);
      expect(frames[40].au.jawDrop, greaterThan(0.5));
    });
  });

  test('the jaw follows the loudness inside a long vowel', () {
    rig.speak(
      _timeline(<(Viseme, int, int)>[(Viseme.aa, 0, 1600)]).copyWith(
        energy: <double>[
          ...List<double>.filled(32, 1),
          ...List<double>.filled(32, 0.2),
        ],
      ),
    );
    final List<FaceFrame> frames = rig.run(90);
    final double loud = frames[40].au.jawDrop; // ~0.68 s
    final double soft = frames[85].au.jawDrop; // ~1.43 s
    expect(loud - soft, greaterThan(0.2));
  });

  test('settles at rest and is unsettled during a pulse', () {
    rig.run(60);
    expect(rig.performer.isSettled, isTrue);
    rig.speak(_timeline(<(Viseme, int, int)>[(Viseme.aa, 0, 500)]));
    rig.run(5);
    expect(rig.performer.isSettled, isFalse);
  });

  group('M3: per-side action units', () {
    test('thinking raises the right outer brow within 0.6 s', () {
      rig.mood(AvatarMood.thinking);
      final FaceFrame f = rig.run(36).last;
      expect(f.right.browOuterUp, closeTo(0.35, 0.02));
      expect(f.right.lipCornerPull, closeTo(0.2, 0.02));
      expect(f.left.browLower, closeTo(0.25, 0.02));
      expect(f.left.browOuterUp, closeTo(0, 0.02));
      // the symmetric preset is untouched
      expect(f.au.browInnerUp, closeTo(0.4, 0.02));
    });

    test('a symmetric mood has no side offsets', () {
      rig.mood(AvatarMood.happy);
      final FaceFrame f = rig.run(60).last;
      expect(f.left, ActionUnitSides.zero);
      expect(f.right, ActionUnitSides.zero);
    });

    test('pitch-peak brow pulses differ left and right', () {
      rig.speak(
        _timeline(
          <(Viseme, int, int)>[(Viseme.aa, 0, 3000)],
          marks: <ProsodyMark>[
            const ProsodyMark(
              kind: ProsodyMarkKind.pitchPeak,
              at: Duration(milliseconds: 600),
            ),
            const ProsodyMark(
              kind: ProsodyMarkKind.pitchPeak,
              at: Duration(milliseconds: 1800),
            ),
          ],
        ),
      );
      final List<FaceFrame> frames = rig.run(150);
      for (final int ms in <int>[650, 1850]) {
        final FaceFrame f = frames[(ms / 16.667).round() - 1];
        expect(f.au.browOuterUp, greaterThan(0.2), reason: '$ms ms');
        expect(
          (f.left.browOuterUp - f.right.browOuterUp).abs(),
          greaterThan(0.03),
          reason: '$ms ms',
        );
        // a split of the pulse, not a second pulse
        expect(f.left.browOuterUp, closeTo(-f.right.browOuterUp, 1e-9));
      }
    });
  });

  group('M3: plosives and f/v', () {
    SpeechTimeline closure() => _timeline(<(Viseme, int, int)>[
      (Viseme.aa, 0, 300),
      (Viseme.pp, 300, 420),
      (Viseme.e, 420, 900),
    ]).copyWith(energy: List<double>.filled(40, 1));

    test('a 120 ms closure compresses and releases with a pop', () {
      rig.speak(closure());
      final List<FaceFrame> frames = rig.run(50);
      // frame i is stepped at position (i + 1) * 16.667 ms
      double at(int i) => (i + 1) * 16.667;
      final List<FaceFrame> inside = <FaceFrame>[
        for (int i = 0; i < frames.length; i++)
          if (at(i) >= 300 && at(i) < 420) frames[i],
      ];
      expect(inside, isNotEmpty);
      expect(inside.every((FaceFrame f) => f.au.jawDrop == 0), isTrue);
      expect(inside.last.au.lipPress, greaterThanOrEqualTo(0.85));
      final double popped = frames[26].au.jawDrop; // ~450 ms: +30 ms
      final double settled = frames[40].au.jawDrop; // ~683 ms: the e itself
      expect(popped, greaterThan(settled));
    });

    test('f/v and s mid-span differ in the lower lip', () {
      rig.speak(
        _timeline(<(Viseme, int, int)>[
          (Viseme.ff, 0, 250),
          (Viseme.ss, 250, 500),
        ]),
      );
      final List<FaceFrame> frames = rig.run(30);
      final double ff = frames[7].lipTuck; // ~133 ms
      final double ss = frames[22].lipTuck; // ~383 ms
      expect(ff - ss, greaterThanOrEqualTo(0.9));
    });
  });

  group('M3: acting variety', () {
    SpeechTimeline stresses() => _timeline(
      <(Viseme, int, int)>[(Viseme.aa, 0, 3000)],
      marks: <ProsodyMark>[
        const ProsodyMark(
          kind: ProsodyMarkKind.stress,
          at: Duration(milliseconds: 500),
        ),
        const ProsodyMark(
          kind: ProsodyMarkKind.stress,
          at: Duration(milliseconds: 1300),
          strength: 0.5,
        ),
        const ProsodyMark(
          kind: ProsodyMarkKind.stress,
          at: Duration(milliseconds: 2100),
        ),
        const ProsodyMark(
          kind: ProsodyMarkKind.pitchPeak,
          at: Duration(milliseconds: 900),
        ),
      ],
    );

    test('three stresses of strength 1, 0.5, 1 nod to different depths', () {
      rig.speak(stresses());
      final List<FaceFrame> frames = rig.run(170);
      double depth(int ms) {
        double low = 0;
        for (int i = 0; i < frames.length; i++) {
          final double t = (i + 1) * 16.667;
          if ((t - ms).abs() < 150 && frames[i].nodPitch < low) {
            low = frames[i].nodPitch;
          }
        }
        return low;
      }

      final double a = depth(500);
      final double b = depth(1300);
      final double c = depth(2100);
      expect(<double>[a, b, c], everyElement(lessThan(-0.2)));
      expect((a - b).abs(), greaterThan(0.03));
      expect((c - b).abs(), greaterThan(0.03));
      expect((a - c).abs(), greaterThan(0.003));
      // the weak stress nods least
      expect(b, greaterThan(a));
      expect(b, greaterThan(c));
    });

    test(
      'the nod release eases out: most of the way back in half the time',
      () {
        rig.speak(
          _timeline(
            <(Viseme, int, int)>[(Viseme.aa, 0, 2000)],
            marks: <ProsodyMark>[
              const ProsodyMark(
                kind: ProsodyMarkKind.stress,
                at: Duration(milliseconds: 1000),
              ),
            ],
          ),
        );
        final List<FaceFrame> frames = rig.run(90);
        final int bottom = (1000 / 16.667).round() - 1;
        final double low = frames[bottom].nodPitch;
        final double half = frames[bottom + 6].nodPitch; // +100 ms of 220 ms
        expect(low, lessThan(-0.3));
        expect(half, greaterThan(low * 0.5));
      },
    );

    test('the brow pulse releases with an ease-out', () {
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
      final List<FaceFrame> frames = rig.run(110);
      double at(int ms) => frames[(ms / 16.667).round() - 1].au.browOuterUp;
      final double top = at(1100);
      // the hold ends at +160 ms; halfway through the 400 ms release an
      // ease-out has given back about two thirds (a smoothstep only half)
      expect(top, greaterThan(0.3));
      expect(at(1360), lessThan(0.42 * top));
      expect(at(1360), greaterThan(0.1 * top));
    });

    test('the same seed gives the same frames; another seed does not', () {
      List<FaceFrame> play(int seed) {
        final _Rig r = _Rig(seed: seed);
        r.mood(AvatarMood.happy);
        r.speak(stresses());
        final List<FaceFrame> out = r.run(170);
        r.dispose();
        return out;
      }

      expect(play(11), play(11));
      expect(play(11), isNot(play(12)));
    });
  });

  group('M3: steady state', () {
    test('a settled performer returns the same frame without allocating', () {
      rig.mood(AvatarMood.thinking);
      rig.run(240);
      final FaceFrame a = rig.performer.step(_frame);
      final FaceFrame b = rig.performer.step(_frame);
      expect(identical(a, b), isTrue);
      expect(a.right.browOuterUp, 0.35);
      expect(a.au.browInnerUp, 0.4);
    });

    test('after a sentence the frames settle back to one instance', () {
      rig.speak(_timeline(<(Viseme, int, int)>[(Viseme.aa, 0, 400)]));
      rig.run(24);
      rig.playback.add(const AnimationCompletedEvent());
      rig.position = null;
      rig.run(300);
      expect(
        identical(rig.performer.step(_frame), rig.performer.frame),
        isTrue,
      );
      expect(rig.performer.isSettled, isTrue);
    });
  });

  test('FaceFrame carries the sides in equality and JSON', () {
    const FaceFrame a = FaceFrame(left: ActionUnitSides(browLower: 0.25));
    const FaceFrame b = FaceFrame(right: ActionUnitSides(browLower: 0.25));
    expect(a, isNot(b));
    expect(a, const FaceFrame(left: ActionUnitSides(browLower: 0.25)));
    expect(
      a.hashCode,
      const FaceFrame(left: ActionUnitSides(browLower: 0.25)).hashCode,
    );
    final Map<String, Object> json = b.toJson();
    expect((json['left']! as Map<String, double>)['browLower'], 0);
    expect((json['right']! as Map<String, double>)['browLower'], 0.25);
    expect((json['right']! as Map<String, double>).length, 7);
  });

  test('dispose cancels both subscriptions', () async {
    await rig.performer.dispose();
    expect(rig.intents.hasListener, isFalse);
    expect(rig.playback.hasListener, isFalse);
  });
}
