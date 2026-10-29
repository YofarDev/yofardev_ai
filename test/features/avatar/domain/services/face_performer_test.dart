import 'dart:async';
import 'dart:math' as math;

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
  /// The idle life is off unless asked for: most tests pin a still face.
  _Rig({int seed = 7, bool idle = false}) {
    performer = FacePerformer(
      intents: intents.stream,
      playback: playback.stream,
      speechPosition: () => position,
      seed: seed,
      idle: idle,
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

    test('the frame that reports settled is exactly on target', () {
      rig.mood(AvatarMood.thinking);
      FaceFrame f = rig.performer.step(_frame);
      int steps = 1;
      while (!rig.performer.isSettled && steps < 600) {
        f = rig.performer.step(_frame);
        steps++;
      }
      expect(rig.performer.isSettled, isTrue);
      // the view stops ticking here: nothing may be left short of the pose
      expect(
        _aus(f.au),
        _aus(actionUnitsForEmotion(emotionForMood(AvatarMood.thinking))),
      );
      final ({ActionUnitSides left, ActionUnitSides right}) sides =
          sidesForEmotion(emotionForMood(AvatarMood.thinking));
      expect(f.left, sides.left);
      expect(f.right, sides.right);
      expect(f.lipTuck, 0);
      expect(f.roll, 0);
      expect(f.breath, 0);
      expect(f.nodPitch, 0);
    });

    test('after a sentence the settled frame is exactly the mood', () {
      rig.mood(AvatarMood.happy);
      rig.speak(_timeline(<(Viseme, int, int)>[(Viseme.aa, 0, 400)]));
      rig.run(24);
      rig.playback.add(const AnimationCompletedEvent());
      rig.position = null;
      FaceFrame f = rig.performer.frame;
      int steps = 0;
      while (!rig.performer.isSettled && steps < 600) {
        f = rig.performer.step(_frame);
        steps++;
      }
      expect(rig.performer.isSettled, isTrue);
      expect(
        _aus(f.au),
        _aus(actionUnitsForEmotion(emotionForMood(AvatarMood.happy))),
      );
    });

    test('side offsets stay within -1..1 at every mood extreme', () {
      final List<EmotionVector> extremes = <EmotionVector>[
        for (final AvatarMood m in AvatarMood.values) emotionForMood(m),
        for (final double v in <double>[-1, 1])
          for (final double a in <double>[-1, 1])
            EmotionVector(valence: v, arousal: a),
      ];
      for (final EmotionVector e in extremes) {
        final _Rig r = _Rig();
        r.intents.add(PerformanceIntent(emotion: e));
        r.speak(
          _timeline(
            <(Viseme, int, int)>[(Viseme.aa, 0, 1500)],
            marks: <ProsodyMark>[
              const ProsodyMark(
                kind: ProsodyMarkKind.pitchPeak,
                at: Duration(milliseconds: 500),
                strength: 1,
              ),
            ],
            question: true,
          ),
        );
        for (final FaceFrame f in r.run(150)) {
          for (final ActionUnitSides s in <ActionUnitSides>[f.left, f.right]) {
            for (final double v in <double>[
              s.browInnerUp,
              s.browOuterUp,
              s.browLower,
              s.lidTighten,
              s.cheekRaise,
              s.lipCornerPull,
              s.lipCornerDepress,
            ]) {
              expect(v, inInclusiveRange(-1.0, 1.0), reason: '$e');
            }
          }
          for (final double v in _aus(f.au)) {
            expect(v, inInclusiveRange(0.0, 1.0), reason: '$e');
          }
        }
        r.dispose();
      }
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

  group('critic round 7', () {
    double ss(double x) {
      final double c = x.clamp(0.0, 1.0);
      return c * c * (3 - 2 * c);
    }

    // frame i of rig.run is stepped at (i + 1) * 16.667 ms
    double at(int i) => (i + 1) * 16.667;

    test('the 350 ms pre-roll: an eased 250 ms inhale, lips parted', () {
      expect(FacePerformer.breathLead, 0.35);
      rig.playback.add(const SpeechPrerollEvent(Duration(milliseconds: 350)));
      final List<FaceFrame> frames = rig.run(21); // 350 ms
      for (int i = 0; i < frames.length; i++) {
        final double since = (i + 1) * 0.016667;
        expect(
          frames[i].breath,
          // 0.72 x the lead, capped at 250 ms
          closeTo(ss(since / 0.25), 1e-3),
          reason: 'frame $i',
        );
      }
      // no gasp: the first 50 ms carry under 15 % of it
      expect(frames[2].breath, lessThan(0.15));
      expect(frames[15].breath, 1); // drawn by ~267 ms, then held
      // parted (jaw 0.08, no press) from 100 ms to the onset
      for (int i = 5; i < frames.length; i++) {
        expect(frames[i].au.jawDrop, closeTo(0.08, 1e-9), reason: '$i');
        expect(frames[i].au.lipPress, 0, reason: '$i');
      }
      // and still parted into the first phoneme
      rig.speak(_timeline(<(Viseme, int, int)>[(Viseme.aa, 0, 600)]));
      for (final FaceFrame f in rig.run(6)) {
        expect(f.au.jawDrop, greaterThan(0.06));
      }
    });

    test('a pre-roll into a p/b/m closes the lips by the onset', () {
      rig.playback.add(
        const SpeechPrerollEvent(Duration(milliseconds: 350), onset: Viseme.pp),
      );
      final List<FaceFrame> frames = rig.run(21);
      expect(frames[14].au.jawDrop, closeTo(0.08, 1e-9)); // ~250 ms
      expect(frames[17].au.jawDrop, closeTo(0.08 * ss(0.5), 1e-3)); // 300
      expect(frames[20].au.jawDrop, 0); // the onset
    });

    test('the full stop eases the mouth shut with a 12 % undershoot', () {
      rig.speak(
        _timeline(<(Viseme, int, int)>[
          (Viseme.e, 0, 600),
          (Viseme.sil, 600, 900),
        ]),
      );
      final List<FaceFrame> frames = rig.run(54);
      // the voice ends at 600 ms: frame 35 is the first at or past it
      const int stop = 35;
      expect(at(stop), greaterThanOrEqualTo(600));
      expect(at(stop - 1), lessThan(600));
      final double jaw0 = frames[stop - 1].au.jawDrop;
      expect(jaw0, greaterThan(0.2));
      double curve(double u) => u < 0.65
          ? 1 - 1.12 * ss(u / 0.65)
          : -0.12 * (1 - ss((u - 0.65) / 0.35));
      double press = 0;
      for (int k = 0; k <= 13; k++) {
        final double u = k * 0.016667 / 0.22;
        final FaceFrame f = frames[stop + k];
        expect(
          f.au.jawDrop,
          closeTo(jaw0 * math.max(0, curve(u)), 1e-3),
          reason: 'k $k',
        );
        press = math.max(press, f.au.lipPress);
      }
      // past rest: the lips meet and press lightly (2 x the 12 %)
      expect(press, closeTo(0.24, 0.01));
      // no snap: it never closes faster than 0.1 per frame
      for (int k = 1; k <= 13; k++) {
        expect(
          frames[stop + k - 1].au.jawDrop - frames[stop + k].au.jawDrop,
          lessThan(0.1),
        );
      }
    });

    test('the full stop drops the head 2 degrees and relaxes the corners', () {
      rig.speak(
        _timeline(<(Viseme, int, int)>[
          (Viseme.aa, 0, 600),
          (Viseme.sil, 600, 800),
        ]),
      );
      rig.run(47);
      rig.playback.add(const AnimationCompletedEvent());
      rig.position = null;
      final List<FaceFrame> after = rig.run(120);
      // the settle started on frame 35 (~600 ms); after[k] is frame 48 + k,
      // so after[18] is ~517 ms into it: the drop is down, the relax full
      final FaceFrame k500 = after[18];
      expect(k500.nodPitch, closeTo(-2 / 15, 1e-6));
      expect(k500.au.lipCornerPull, closeTo(0.06, 1e-3));
      // both gone by 1.7 s
      expect(after.last.nodPitch, 0);
      expect(after.last.au.lipCornerPull, 0);
    });

    test('after the full stop the face keeps living (idle life)', () {
      List<FaceFrame> play({bool reduce = false}) {
        final _Rig r = _Rig(idle: true);
        r.performer.reduceMotion = reduce;
        r.speak(_timeline(<(Viseme, int, int)>[(Viseme.aa, 0, 400)]));
        r.run(24);
        r.playback.add(const AnimationCompletedEvent());
        r.position = null;
        r.run(120); // the idle has faded in
        final List<FaceFrame> out = r.run(300); // 5 s
        expect(r.performer.isSettled, reduce);
        r.dispose();
        return out;
      }

      final List<FaceFrame> idle = play();
      double range(double Function(FaceFrame) f) {
        final List<double> v = idle.map(f).toList()..sort();
        return v.last - v.first;
      }

      expect(range((FaceFrame f) => f.breath), greaterThan(0.1));
      expect(range((FaceFrame f) => f.left.lipCornerPull), greaterThan(0.01));
      expect(range((FaceFrame f) => f.right.lipCornerPull), greaterThan(0.01));
      expect(range((FaceFrame f) => f.roll), greaterThan(0.03));
      expect(range((FaceFrame f) => f.nodPitch), greaterThan(0.015));
      // small: no more than a soft breath and a fraction of a degree
      expect(idle.every((FaceFrame f) => f.breath <= 0.19), isTrue);
      expect(idle.every((FaceFrame f) => f.roll.abs() <= 0.05), isTrue);
      for (int i = 1; i < idle.length; i++) {
        expect(identical(idle[i], idle[i - 1]), isFalse);
      }
      expect(play(), idle); // seeded: deterministic
      final List<FaceFrame> still = play(reduce: true);
      expect(still.every((FaceFrame f) => f.breath == 0), isTrue);
      expect(still.every((FaceFrame f) => f.roll == 0), isTrue);
    });

    group('questions', () {
      SpeechTimeline asked({required bool question, double? slope}) =>
          _timeline(
            <(Viseme, int, int)>[(Viseme.e, 0, 1400), (Viseme.sil, 1400, 1600)],
            marks: <ProsodyMark>[
              const ProsodyMark(
                kind: ProsodyMarkKind.pitchPeak,
                at: Duration(milliseconds: 300),
                slope: 0.5,
              ),
              ProsodyMark(
                kind: ProsodyMarkKind.pitchPeak,
                at: const Duration(milliseconds: 1300),
                slope: slope ?? 0.5,
              ),
            ],
            question: question,
          );

      double peakIn(List<FaceFrame> f, int from, int to) {
        double best = 0;
        for (int i = 0; i < f.length; i++) {
          if (at(i) >= from && at(i) < to) {
            best = math.max(best, f[i].au.browOuterUp);
          }
        }
        return best;
      }

      test('the final rise lifts the brows 1.5x a statement beat', () {
        rig.speak(asked(question: true));
        final List<FaceFrame> q = rig.run(84);
        final double statement = peakIn(q, 0, 900);
        final double rise = peakIn(q, 900, 1400);
        expect(rise / statement, inInclusiveRange(1.4, 1.7));
        // a statement's last beat is just another beat
        final _Rig s = _Rig();
        s.speak(asked(question: false));
        final List<FaceFrame> plain = s.run(84);
        expect(
          peakIn(plain, 900, 1400) / peakIn(plain, 0, 900),
          closeTo(1, 0.05),
        );
        s.dispose();
      });

      test('the rise peaks 80 ms ahead of the rising syllable', () {
        rig.speak(asked(question: true));
        final List<FaceFrame> q = rig.run(84);
        final double top = peakIn(q, 900, 1400);
        final int first = q.indexWhere(
          (FaceFrame f) => f.au.browOuterUp >= top - 1e-9,
        );
        expect(at(first), inInclusiveRange(1300 - 80 - 35, 1300 - 80 + 35));
        expect(q[first].roll, greaterThan(0.4)); // tilting with it
      });

      test('brows and tilt hold through the listening pause', () {
        rig.speak(asked(question: true));
        final List<FaceFrame> q = rig.run(96); // to 1.6 s
        final double top = peakIn(q, 900, 1400);
        rig.playback.add(const AnimationCompletedEvent());
        rig.position = null;
        final List<FaceFrame> pause = rig.run(24); // +400 ms
        for (final FaceFrame f in <FaceFrame>[q.last, ...pause]) {
          expect(f.au.browOuterUp, greaterThan(0.8 * top));
          expect(f.roll, greaterThan(0.7));
        }
        expect(rig.run(54).last.roll, lessThan(0.1)); // released by +1.3 s
      });

      test('the brow rise scales with the pitch slope', () {
        expect(FacePerformer.slopeGain(0), closeTo(0.7, 1e-9));
        expect(FacePerformer.slopeGain(1), closeTo(1.3, 1e-9));
        expect(FacePerformer.slopeGain(null), 1);
        double rise(double slope) {
          final _Rig r = _Rig();
          r.speak(asked(question: true, slope: slope));
          final double top = peakIn(r.run(84), 900, 1400);
          r.dispose();
          return top;
        }

        expect(rise(1) / rise(0), closeTo(1.3 / 0.7, 0.1));
      });

      test('with no final pitch peak the brows peak inside the last vowel', () {
        // "allez-vous ?": the voice ends at 1850 ms
        rig.speak(
          _timeline(<(Viseme, int, int)>[
            (Viseme.e, 0, 1600),
            (Viseme.ff, 1600, 1650),
            (Viseme.ou, 1650, 1850),
            (Viseme.sil, 1850, 2077),
          ], question: true),
        );
        final List<FaceFrame> q = rig.run(124);
        final double top = peakIn(q, 1000, 2077);
        final int first = q.indexWhere(
          (FaceFrame f) => f.au.browOuterUp >= top - 1e-9,
        );
        // 60 % into the ou (1770 ms), 80 ms early
        expect(at(first), inInclusiveRange(1690 - 35, 1690 + 35));
      });
    });

    group('secondary motion', () {
      test('nod depth follows the stress: 0.4 to 1.0 of the deepest', () {
        expect(FacePerformer.nodDepthFor(0), closeTo(0.22, 1e-9));
        expect(FacePerformer.nodDepthFor(0.5), closeTo(0.385, 1e-9));
        expect(FacePerformer.nodDepthFor(1), closeTo(0.55, 1e-9));
        rig.speak(
          _timeline(
            <(Viseme, int, int)>[(Viseme.aa, 0, 2000)],
            marks: <ProsodyMark>[
              const ProsodyMark(
                kind: ProsodyMarkKind.stress,
                at: Duration(milliseconds: 500),
                strength: 0.4,
              ),
              const ProsodyMark(
                kind: ProsodyMarkKind.stress,
                at: Duration(milliseconds: 1300),
              ),
            ],
          ),
        );
        final List<FaceFrame> f = rig.run(110);
        double low(int ms) {
          double v = 0;
          for (int i = 0; i < f.length; i++) {
            if ((at(i) - ms).abs() < 150) {
              v = math.min(v, f[i].nodPitch);
            }
          }
          return v;
        }

        final double weak = low(500);
        final double strong = low(1300);
        expect(strong, inInclusiveRange(-0.55 * 1.08, -0.55 * 0.9));
        expect(weak / strong, inInclusiveRange(0.64 * 0.85, 0.64 * 1.18));
      });

      test('some stresses get small roll accents of alternating side', () {
        rig.speak(
          _timeline(
            <(Viseme, int, int)>[(Viseme.aa, 0, 7000)],
            marks: <ProsodyMark>[
              for (int k = 0; k < 10; k++)
                ProsodyMark(
                  kind: ProsodyMarkKind.stress,
                  at: Duration(milliseconds: 400 + 650 * k),
                  strength: k.isEven ? 0.3 : 0.9,
                ),
            ],
          ),
        );
        final List<double> roll = <double>[
          for (final FaceFrame f in rig.run(420)) f.roll,
        ];
        final List<double> accents = <double>[];
        for (int i = 1; i < roll.length - 1; i++) {
          final double r = roll[i];
          if (r.abs() > 0.04 &&
              r.abs() >= roll[i - 1].abs() &&
              r.abs() > roll[i + 1].abs()) {
            accents.add(r);
          }
        }
        expect(accents.length, inInclusiveRange(2, 9));
        for (int i = 1; i < accents.length; i++) {
          expect(accents[i].sign, -accents[i - 1].sign);
        }
        expect(roll.every((double r) => r.abs() < 0.15), isTrue);
      });

      test('a brow beat dips, rises over 80 ms or more, and has no top', () {
        rig.mood(AvatarMood.thinking);
        rig.run(60);
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
        final List<double> b = <double>[
          for (final FaceFrame f in rig.run(110)) f.au.browInnerUp,
        ];
        final double base = b[20];
        int top = 0;
        for (int i = 0; i < b.length; i++) {
          if (b[i] > b[top]) {
            top = i;
          }
        }
        final double a = b[top] - base;
        expect(a, greaterThan(0.2));
        // anticipation: down before it goes up
        final double dip = b.sublist(36, top).reduce(math.min);
        expect(base - dip, greaterThan(0.1 * a));
        // the rise from 10 % to 90 % takes 80 ms or more
        final int r10 = b.indexWhere((double v) => v > base + 0.1 * a, 40);
        final int r90 = b.indexWhere((double v) => v > base + 0.9 * a, 40);
        expect((r90 - r10) * 16.667, greaterThanOrEqualTo(80));
        // no plateau: 100 ms after the top it has given back 10 % or more
        expect(b[top + 6], lessThan(b[top] - 0.1 * a));
      });
    });

    group('coarticulation', () {
      test('no grin between a b release and an ou', () {
        rig.speak(
          _timeline(<(Viseme, int, int)>[
            (Viseme.aa, 0, 200),
            (Viseme.pp, 200, 300),
            (Viseme.ou, 300, 600),
          ]),
        );
        final List<FaceFrame> f = rig.run(36);
        for (int i = 0; i < f.length; i++) {
          if (at(i) >= 300 && at(i) < 400) {
            expect(f[i].au.lipPucker, greaterThanOrEqualTo(0.3), reason: '$i');
            expect(f[i].au.lipStretch, lessThan(0.05), reason: '$i');
          }
        }
      });

      test('"you" rounds before the ou starts', () {
        rig.speak(
          _timeline(<(Viseme, int, int)>[
            (Viseme.ih, 0, 200),
            (Viseme.ou, 200, 500),
          ]),
        );
        final List<FaceFrame> f = rig.run(30);
        final int onset = (200 / 16.667).ceil() - 1;
        expect(f[onset].au.lipPucker, greaterThan(0.5));
        expect(f[onset].au.lipStretch, lessThan(0.2));
        // a tight /u/ mid-vowel
        expect(f[22].au.lipPucker, closeTo(1, 0.02));
        expect(f[22].au.lipStretch, closeTo(0, 0.02));
        expect(f[22].au.jawDrop, lessThan(0.2));
      });

      test('th keeps the tongue up in running speech', () {
        rig.speak(
          _timeline(<(Viseme, int, int)>[
            (Viseme.e, 0, 300),
            (Viseme.th, 300, 360),
            (Viseme.e, 360, 600),
          ]),
        );
        final List<FaceFrame> f = rig.run(36);
        for (int i = 0; i < f.length; i++) {
          if (at(i) >= 300 && at(i) < 360) {
            expect(f[i].tongueUp, greaterThanOrEqualTo(0.6), reason: '$i');
          }
        }
      });
    });

    test('no one-frame jaw spikes after bilabial releases', () {
      // "probably buy a big": short vowels squeezed between closures
      rig.speak(
        _timeline(<(Viseme, int, int)>[
          (Viseme.e, 0, 300),
          (Viseme.pp, 300, 350),
          (Viseme.aa, 350, 425),
          (Viseme.pp, 425, 575),
          (Viseme.aa, 575, 625),
          (Viseme.pp, 625, 675),
          (Viseme.ih, 675, 1000),
        ]).copyWith(energy: List<double>.filled(40, 1)),
      );
      final List<FaceFrame> f = rig.run(60);
      double peak(int from, int to) {
        double v = 0;
        for (int i = 0; i < f.length; i++) {
          if (at(i) >= from && at(i) < to) {
            v = math.max(v, f[i].au.jawDrop);
          }
        }
        return v;
      }

      // a 75 ms vowel bursts to its 0.375 cap (plus the pop), a 50 ms one
      // barely opens between its closures
      expect(FacePerformer.releaseJawCap(_ms(75)), closeTo(0.375, 1e-9));
      expect(FacePerformer.releaseJawCap(_ms(400)), 1);
      expect(peak(350, 425), lessThan(0.55));
      expect(peak(575, 625), lessThan(0.35));
      // outside the 50 ms after a release the jaw opens at 8 units/s at most
      const List<int> releases = <int>[350, 575, 675];
      for (int i = 1; i < f.length; i++) {
        final bool burst = releases.any(
          (int r) => at(i) >= r && at(i) < r + 70,
        );
        if (!burst) {
          expect(
            f[i].au.jawDrop - f[i - 1].au.jawDrop,
            lessThanOrEqualTo(8 / 60 + 1e-6),
            reason: '${at(i)} ms',
          );
        }
      }
      // closures stay exactly sealed
      for (int i = 0; i < f.length; i++) {
        final double t = at(i);
        final bool inside =
            (t >= 300 && t < 350) ||
            (t >= 425 && t < 575) ||
            (t >= 625 && t < 675);
        if (inside) {
          expect(f[i].au.jawDrop, 0, reason: '$t ms');
          expect(f[i].au.lipPress, greaterThanOrEqualTo(0.6), reason: '$t');
        }
      }
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
