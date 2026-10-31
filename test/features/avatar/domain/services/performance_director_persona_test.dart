import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/features/avatar/domain/models/performance_intent.dart';
import 'package:yofardev_ai/features/avatar/domain/services/performance_director.dart';

void main() {
  group('PerformanceDirector persona body language', () {
    late DateTime currentTime;

    PerformanceDirector build({int seed = 11}) {
      currentTime = DateTime(2026, 10, 31, 12);
      return PerformanceDirector(now: () => currentTime, seed: seed);
    }

    void advance(FakeAsync async, int ms) {
      currentTime = currentTime.add(Duration(milliseconds: ms));
      async.elapse(Duration(milliseconds: ms));
    }

    BodyLanguageProfile of(ChatPersona p) => BodyLanguageProfile.of(p);

    /// Plays [sentences] as the cue service would (speaking on, the caption,
    /// a gesture done after 800 ms, speaking off, a 1.2 s gap) and returns
    /// the gestures started.
    List<AvatarGesture> play(
      FakeAsync async,
      PerformanceDirector director,
      List<String> sentences,
    ) {
      final List<AvatarGesture> started = <AvatarGesture>[];
      int lastSerial = director.current.gestureSerial;
      director.intents.listen((PerformanceIntent i) {
        if (i.pendingGesture != null && i.gestureSerial > lastSerial) {
          lastSerial = i.gestureSerial;
          started.add(i.pendingGesture!);
        }
      });
      for (final String s in sentences) {
        director.setSpeaking(true);
        director.onSentence(s);
        advance(async, 800);
        director.onGestureDone();
        director.setSpeaking(false);
        advance(async, 1200);
      }
      return started;
    }

    test('the default profile is normal and the intent carries it', () {
      final PerformanceDirector director = build();
      expect(director.profile, BodyLanguageProfile.normal);
      expect(director.current.body, BodyLanguageProfile.normal);
      director.dispose();
    });

    test('setProfile(normal) changes nothing in the gestures played', () {
      const List<String> script = <String>[
        'Yes, absolutely.',
        'What do you think?',
        'That is amazing!',
        'First this, second that, third the rest.',
        'No.',
      ];
      List<AvatarGesture> run(bool setNormal) {
        late List<AvatarGesture> out;
        fakeAsync((FakeAsync async) {
          final PerformanceDirector director = build();
          if (setNormal) {
            director.setProfile(BodyLanguageProfile.normal);
          }
          out = play(async, director, script);
          director.dispose();
        });
        return out;
      }

      expect(run(true), run(false));
      expect(run(false), <AvatarGesture>[
        AvatarGesture.nod,
        AvatarGesture.think,
        AvatarGesture.count,
        AvatarGesture.headshake,
      ]);
    });

    test('the coach: beats get thumbs up and claps, yeses a thumbs up', () {
      fakeAsync((FakeAsync async) {
        final PerformanceDirector director = build();
        director.setProfile(of(ChatPersona.coach));
        final List<AvatarGesture> started = play(async, director, <String>[
          'You can do it!',
          'Keep going!',
          'Yes, exactly.',
        ]);
        expect(started, <AvatarGesture>[
          AvatarGesture.thumbsUp,
          AvatarGesture.clap,
          AvatarGesture.thumbsUp,
        ]);
        director.dispose();
      });
    });

    test('the doomer shrugs and thins its gestures (rate 0.6)', () {
      fakeAsync((FakeAsync async) {
        final PerformanceDirector director = build();
        director.setProfile(of(ChatPersona.doomer));
        final List<AvatarGesture> started = play(async, director, <String>[
          'Yes, I suppose.',
          'Why even try?',
          'Great, just great!',
          'No.',
          'Yes.',
        ]);
        // five candidates at weight 0.6: the first, third and fifth fire
        // (a running credit, no RNG); the yeses and the beat are shrugs
        expect(started, <AvatarGesture>[
          AvatarGesture.shrug,
          AvatarGesture.shrug,
          AvatarGesture.shrug,
        ]);
        director.dispose();
      });
    });

    test('the philosopher thinks where normal would nod', () {
      fakeAsync((FakeAsync async) {
        final PerformanceDirector director = build();
        director.setProfile(of(ChatPersona.philosopher));
        final List<AvatarGesture> started = play(async, director, <String>[
          'Yes, in a sense.',
          'How curious!',
        ]);
        expect(started, everyElement(AvatarGesture.think));
        expect(started, isNotEmpty);
        director.dispose();
      });
    });

    test('LLM gestures are never swapped nor thinned', () {
      fakeAsync((FakeAsync async) {
        final PerformanceDirector director = build();
        director.setProfile(of(ChatPersona.doomer));
        director.intents.listen((_) {});
        final List<AvatarGesture> started = <AvatarGesture>[];
        for (int i = 0; i < 5; i++) {
          director.requestGesture(AvatarGesture.nod);
          started.add(director.current.pendingGesture!);
          director.onGestureDone();
          advance(async, 3000);
        }
        expect(started, List<AvatarGesture>.filled(5, AvatarGesture.nod));
        director.dispose();
      });
    });

    test('the cooldown is gestureCooldown / gestureRate', () {
      fakeAsync((FakeAsync async) {
        final PerformanceDirector director = build();
        director.setProfile(of(ChatPersona.coach)); // rate 1.6: 938 ms
        director.intents.listen((_) {});
        director.requestGesture(AvatarGesture.wave);
        director.requestGesture(AvatarGesture.clap);
        director.onGestureDone();
        advance(async, 900);
        expect(director.current.pendingGesture, isNull);
        advance(async, 50);
        expect(director.current.pendingGesture, AvatarGesture.clap);
        director.dispose();
      });
      fakeAsync((FakeAsync async) {
        final PerformanceDirector director = build();
        director.setProfile(of(ChatPersona.doomer)); // rate 0.6: 2500 ms
        director.intents.listen((_) {});
        director.requestGesture(AvatarGesture.wave);
        director.requestGesture(AvatarGesture.clap);
        director.onGestureDone();
        advance(async, 2400);
        expect(director.current.pendingGesture, isNull);
        advance(async, 150);
        expect(director.current.pendingGesture, AvatarGesture.clap);
        director.dispose();
      });
    });

    group('a persona change applies at the next sentence', () {
      test('while speaking it waits for the sentence to end', () {
        fakeAsync((FakeAsync async) {
          final PerformanceDirector director = build();
          director.intents.listen((_) {});
          director.setSpeaking(true);
          director.setProfile(of(ChatPersona.doomer));
          expect(director.current.body, BodyLanguageProfile.normal);
          expect(director.profile, BodyLanguageProfile.normal);
          // the rest of this sentence keeps the normal rules
          director.onSentence('Yes, fine.');
          expect(director.current.pendingGesture, AvatarGesture.nod);
          advance(async, 400);
          director.setSpeaking(false);
          expect(director.current.body, of(ChatPersona.doomer));
          director.dispose();
        });
      });

      test('while silent it applies at once', () {
        final PerformanceDirector director = build();
        director.setProfile(of(ChatPersona.coach));
        expect(director.current.body, of(ChatPersona.coach));
        director.dispose();
      });

      test('the same profile twice emits nothing', () {
        fakeAsync((FakeAsync async) {
          final PerformanceDirector director = build();
          final List<PerformanceIntent> intents = <PerformanceIntent>[];
          director.intents.listen(intents.add);
          director.setProfile(of(ChatPersona.geek));
          async.flushMicrotasks();
          final int n = intents.length;
          director.setProfile(of(ChatPersona.geek));
          async.flushMicrotasks();
          expect(intents.length, n);
          director.dispose();
        });
      });
    });

    group('idle style', () {
      test('the philosopher reads the newspaper at idle stages 2 and 3', () {
        fakeAsync((FakeAsync async) {
          final PerformanceDirector director = build();
          director.intents.listen((_) {});
          director.setProfile(of(ChatPersona.philosopher));
          director.setIdleStage(2);
          expect(director.current.prop, AvatarProp.newspaper);
          director.setIdleStage(3);
          expect(director.current.prop, AvatarProp.newspaper);
          director.dispose();
        });
      });

      test('normal and the coach keep the tablet', () {
        for (final ChatPersona p in <ChatPersona>[
          ChatPersona.normal,
          ChatPersona.coach,
        ]) {
          fakeAsync((FakeAsync async) {
            final PerformanceDirector director = build();
            director.intents.listen((_) {});
            director.setProfile(of(p));
            director.setIdleStage(3);
            expect(director.current.prop, AvatarProp.tablet);
            director.dispose();
          });
        }
      });

      test('the glance period scales with the profile (same seed)', () {
        int firstGlance(BodyLanguageProfile profile) {
          int ms = 0;
          fakeAsync((FakeAsync async) {
            final PerformanceDirector director = build(seed: 5);
            director.intents.listen((_) {});
            director.setProfile(profile);
            director.setIdleStage(1);
            while (director.current.gaze is! GazeAway && ms < 30000) {
              advance(async, 10);
              ms += 10;
            }
            director.dispose();
          });
          return ms;
        }

        final int normal = firstGlance(BodyLanguageProfile.normal);
        final int slow = firstGlance(
          const BodyLanguageProfile(idle: IdleStyle(glancePeriodScale: 1.4)),
        );
        final int fast = firstGlance(
          const BodyLanguageProfile(idle: IdleStyle(glancePeriodScale: 0.7)),
        );
        expect(slow, closeTo(normal * 1.4, 20));
        expect(fast, closeTo(normal * 0.7, 20));
      });
    });
  });
}
