import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/core/services/presence/composer_activity_service.dart';
import 'package:yofardev_ai/features/avatar/domain/models/performance_intent.dart';
import 'package:yofardev_ai/features/avatar/domain/services/performance_director.dart';

void main() {
  group('PerformanceDirector presence', () {
    late DateTime currentTime;

    PerformanceDirector build() {
      currentTime = DateTime(2026, 10, 29, 12);
      return PerformanceDirector(now: () => currentTime);
    }

    void advance(FakeAsync async, int ms) {
      currentTime = currentTime.add(Duration(milliseconds: ms));
      async.elapse(Duration(milliseconds: ms));
    }

    ComposerActivity typed(String char, {double caret = 0.5}) =>
        ComposerActivity(typing: true, caretFraction: caret, lastChar: char);

    group('lookup tools and the tablet', () {
      test('a lookup tool takes the tablet and the gaze away', () {
        final PerformanceDirector director = build();
        director.setActiveTool('getCurrentWeather');
        expect(director.current.prop, AvatarProp.tablet);
        expect(director.current.gaze, const GazeTarget.away(0.6));
        director.dispose();
      });

      test('every lookup tool takes the tablet', () {
        final PerformanceDirector director = build();
        for (final String tool in <String>[
          'searchGoogle',
          'getTextContentFromWebsite',
          'getCurrentWeather',
          'getMostPopularNewsOfTheDay',
        ]) {
          director.setActiveTool(tool);
          expect(director.current.prop, AvatarProp.tablet, reason: tool);
        }
        director.dispose();
      });

      test('another tool keeps the hands free and the glance away', () {
        final PerformanceDirector director = build();
        director.setActiveTool('saveMemory');
        expect(director.current.prop, AvatarProp.none);
        expect(director.current.gaze, const GazeTarget.away(0.6));
        director.dispose();
      });

      test('a cleared tool brings the gaze back at once, the tablet after '
          'the hold-over', () {
        fakeAsync((FakeAsync async) {
          final PerformanceDirector director = build();
          director.intents.listen((_) {});
          director.setActiveTool('searchGoogle');
          director.setActiveTool(null);
          expect(director.current.gaze, const GazeTarget.user());
          expect(director.current.prop, AvatarProp.tablet);
          advance(async, 399);
          expect(director.current.prop, AvatarProp.tablet);
          advance(async, 2);
          expect(director.current.prop, AvatarProp.none);
          director.dispose();
        });
      });

      test('back-to-back tools never emit an intermediate none', () {
        fakeAsync((FakeAsync async) {
          final PerformanceDirector director = build();
          final List<AvatarProp> props = <AvatarProp>[];
          director.intents.listen((PerformanceIntent i) => props.add(i.prop));
          director.setActiveTool('searchGoogle');
          advance(async, 100);
          director.setActiveTool(null);
          advance(async, 300);
          director.setActiveTool('getTextContentFromWebsite');
          advance(async, 1000);
          expect(props, isNotEmpty);
          expect(props, everyElement(AvatarProp.tablet));
          expect(director.current.prop, AvatarProp.tablet);
          // the first tool's hold-over timer is gone: nothing ends it early
          director.setActiveTool(null);
          advance(async, 500);
          expect(director.current.prop, AvatarProp.none);
          expect(props.last, AvatarProp.none);
          director.dispose();
        });
      });

      test('speech starting ends the hold-over at once', () {
        fakeAsync((FakeAsync async) {
          final PerformanceDirector director = build();
          director.intents.listen((_) {});
          director.setActiveTool('searchGoogle');
          director.setActiveTool(null);
          director.setSpeaking(true);
          expect(director.current.prop, AvatarProp.none);
          director.setSpeaking(false);
          expect(director.current.prop, AvatarProp.none);
          advance(async, 1000);
          expect(director.current.prop, AvatarProp.none);
          director.dispose();
        });
      });

      test('an LLM gesture during the hold-over plays at once', () {
        fakeAsync((FakeAsync async) {
          final PerformanceDirector director = build();
          director.intents.listen((_) {});
          director.setActiveTool('searchGoogle');
          director.setActiveTool(null);
          director.requestGesture(AvatarGesture.wave);
          expect(director.current.prop, AvatarProp.none);
          expect(director.current.pendingGesture, AvatarGesture.wave);
          director.dispose();
        });
      });

      test('a gesture requested while the tablet is out is dropped', () {
        fakeAsync((FakeAsync async) {
          final PerformanceDirector director = build();
          director.setActiveTool('searchGoogle');
          director.requestGesture(AvatarGesture.wave);
          expect(director.current.pendingGesture, isNull);
          expect(director.current.gestureSerial, 0);

          // Not queued for later either.
          director.setActiveTool(null);
          advance(async, 5000);
          expect(director.current.pendingGesture, isNull);

          director.requestGesture(AvatarGesture.wave);
          expect(director.current.pendingGesture, AvatarGesture.wave);
          director.dispose();
        });
      });

      test('a queued gesture is dropped when the tablet comes out', () {
        fakeAsync((FakeAsync async) {
          final PerformanceDirector director = build();
          director.requestGesture(AvatarGesture.wave);
          director.requestGesture(AvatarGesture.clap);
          director.setActiveTool('searchGoogle');
          director.onGestureDone();
          advance(async, 3000);
          expect(director.current.pendingGesture, isNull);
          expect(director.current.gestureSerial, 1);
          director.dispose();
        });
      });
    });

    group('composing', () {
      test('composing at caret 0.8 watches the caret and leans in', () {
        final PerformanceDirector director = build();
        director.setComposer(typed('a', caret: 0.8));
        expect(director.current.gaze, const GazeTarget.caret(0.8));
        expect(director.current.lean, 0.6);
        director.dispose();
      });

      test('stopping typing relaxes the lean and the gaze', () {
        final PerformanceDirector director = build();
        director.setComposer(typed('a', caret: 0.8));
        director.setComposer(ComposerActivity.idle);
        expect(director.current.gaze, const GazeTarget.user());
        expect(director.current.lean, 0);
        director.dispose();
      });

      test('a running tool outranks the caret', () {
        final PerformanceDirector director = build();
        director.setComposer(typed('a'));
        director.setActiveTool('searchGoogle');
        expect(director.current.gaze, const GazeTarget.away(0.6));
        director.dispose();
      });

      test('speaking while composing: gaze on the user and lean 0', () {
        final PerformanceDirector director = build();
        director.setComposer(typed('a', caret: 0.8));
        director.setSpeaking(true);
        expect(director.current.gaze, const GazeTarget.user());
        expect(director.current.lean, 0);
        expect(director.current.prop, AvatarProp.none);
        director.setSpeaking(false);
        expect(director.current.lean, 0.6);
        director.dispose();
      });

      test('typing while speaking earns no nod and no reaction', () {
        final PerformanceDirector director = build();
        director.setSpeaking(true);
        director.setComposer(typed('?'));
        expect(director.current.nodSerial, 0);
        expect(director.current.reactionSerial, 0);
        director.dispose();
      });
    });

    group('caret moves and touches', () {
      ComposerActivity caretMove({double caret = 0.2}) =>
          ComposerActivity(typing: true, caretFraction: caret, edited: false);

      test('a caret move after a pause earns no nod, but moves the gaze', () {
        final PerformanceDirector director = build();
        director.setComposer(caretMove(caret: 0.3));
        expect(director.current.nodSerial, 0);
        expect(director.current.gaze, const GazeTarget.caret(0.3));
        director.dispose();
      });

      test('a moved caret on ? or ! earns no reaction', () {
        final PerformanceDirector director = build();
        director.setComposer(
          const ComposerActivity(typing: true, lastChar: '?', edited: false),
        );
        expect(director.current.reactionSerial, 0);
        director.dispose();
      });

      test('caret moves still count as activity', () {
        final PerformanceDirector director = build();
        director.setIdleStage(2);
        director.setComposer(caretMove());
        expect(director.current.idleStage, 0);
        director.dispose();
      });

      test('a caret move between edits does not spend the nod gap', () {
        final PerformanceDirector director = build();
        director.setComposer(typed('a'));
        currentTime = currentTime.add(const Duration(seconds: 3));
        director.setComposer(caretMove());
        currentTime = currentTime.add(const Duration(milliseconds: 100));
        director.setComposer(typed('b'));
        // 3.1 s since the first nod and typing resumed after a pause
        expect(director.current.nodSerial, 2);
        director.dispose();
      });
    });

    group('keystroke snapshots', () {
      test(
        'a keystroke that changes nothing the intent shows emits nothing',
        () async {
          final PerformanceDirector director = build();
          final List<PerformanceIntent> seen = <PerformanceIntent>[];
          director.intents.listen(seen.add);
          director.setComposer(typed('a', caret: 0.4));
          await Future<void>.delayed(Duration.zero);
          final int before = seen.length;
          currentTime = currentTime.add(const Duration(milliseconds: 100));
          director.setComposer(typed('b', caret: 0.4));
          await Future<void>.delayed(Duration.zero);
          expect(seen.length, before);
          director.setComposer(typed('c', caret: 0.5));
          await Future<void>.delayed(Duration.zero);
          expect(seen.length, before + 1);
          director.dispose();
        },
      );

      test('the mood faces are computed once per mood, not per snapshot', () {
        final PerformanceDirector director = build();
        director.setMood(AvatarMood.happy);
        expect(identical(director.current.face, director.current.face), isTrue);
        expect(
          identical(director.current.emotion, director.current.emotion),
          isTrue,
        );
        director.dispose();
      });
    });

    group('backchannel nods', () {
      test('typing that resumes after a pause nods once', () {
        final PerformanceDirector director = build();
        director.setComposer(typed('h'));
        expect(director.current.nodSerial, 1);
        director.dispose();
      });

      test('10 reports in 1 s give at most one nod', () {
        final PerformanceDirector director = build();
        for (int i = 0; i < 10; i++) {
          director.setComposer(typed(i.isEven ? 'a' : ' '));
          currentTime = currentTime.add(const Duration(milliseconds: 100));
        }
        expect(director.current.nodSerial, 1);
        director.dispose();
      });

      test('a held key (2,000 reports) nods at most once per 2.5 s', () {
        final PerformanceDirector director = build();
        final DateTime start = currentTime;
        for (int i = 0; i < 2000; i++) {
          director.setComposer(typed('x'));
          currentTime = currentTime.add(const Duration(milliseconds: 30));
        }
        final double seconds =
            currentTime.difference(start).inMilliseconds / 1000;
        // Typing never paused: only the very first report resumes.
        expect(director.current.nodSerial, 1);
        expect(seconds, 60);
        director.dispose();
      });

      test('word ends nod, but never closer than 2.5 s', () {
        final PerformanceDirector director = build();
        director.setComposer(typed('a'));
        expect(director.current.nodSerial, 1);
        currentTime = currentTime.add(const Duration(milliseconds: 300));
        director.setComposer(typed(' '));
        expect(director.current.nodSerial, 1, reason: 'too soon');
        currentTime = currentTime.add(const Duration(milliseconds: 2300));
        director.setComposer(typed('b'));
        director.setComposer(typed(' '));
        expect(director.current.nodSerial, 2);
        director.dispose();
      });

      test('resuming after a 600 ms pause nods once 2.5 s have passed', () {
        final PerformanceDirector director = build();
        director.setComposer(typed('a'));
        currentTime = currentTime.add(const Duration(seconds: 3));
        director.setComposer(typed('b'));
        expect(director.current.nodSerial, 2);
        currentTime = currentTime.add(const Duration(milliseconds: 100));
        director.setComposer(typed('c'));
        expect(director.current.nodSerial, 2, reason: 'no pause');
        director.dispose();
      });
    });

    group('punctuation reactions', () {
      test('a typed ? is a question reaction', () {
        final PerformanceDirector director = build();
        director.setComposer(typed('?'));
        expect(director.current.reaction, PresenceReaction.question);
        expect(director.current.reactionSerial, 1);
        director.dispose();
      });

      test('a typed ! is an exclaim reaction', () {
        final PerformanceDirector director = build();
        director.setComposer(typed('!'));
        expect(director.current.reaction, PresenceReaction.exclaim);
        expect(director.current.reactionSerial, 1);
        director.dispose();
      });

      test('?!?! in 1 s gives one reaction', () {
        final PerformanceDirector director = build();
        for (final String c in <String>['?', '!', '?', '!']) {
          director.setComposer(typed(c));
          currentTime = currentTime.add(const Duration(milliseconds: 250));
        }
        expect(director.current.reactionSerial, 1);
        director.dispose();
      });

      test('a second mark 1.2 s later reacts again', () {
        final PerformanceDirector director = build();
        director.setComposer(typed('?'));
        currentTime = currentTime.add(const Duration(milliseconds: 1200));
        director.setComposer(typed('!'));
        expect(director.current.reactionSerial, 2);
        expect(director.current.reaction, PresenceReaction.exclaim);
        director.dispose();
      });

      test('ordinary characters do not react', () {
        final PerformanceDirector director = build();
        director.setComposer(typed('a'));
        expect(director.current.reactionSerial, 0);
        expect(director.current.reaction, isNull);
        director.dispose();
      });
    });

    group('idle stages', () {
      test('stage 1 glances away every 6 to 10 s for 1.2 s', () {
        fakeAsync((FakeAsync async) {
          final PerformanceDirector director = build();
          director.intents.listen((_) {});

          director.setIdleStage(1);
          expect(director.current.idleStage, 1);
          expect(director.current.gaze, const GazeTarget.user());

          bool glancing() => director.current.gaze is GazeAway;
          // Steps until the glance state flips to [want]; returns the ms.
          int until(bool want) {
            int ms = 0;
            while (glancing() != want && ms < 20000) {
              advance(async, 100);
              ms += 100;
            }
            return ms;
          }

          final int firstStart = until(true);
          expect(firstStart, inInclusiveRange(6000, 10100));
          final double angle = (director.current.gaze as GazeAway).angle;
          expect(angle.abs(), inInclusiveRange(0.25, 0.45));
          expect(until(false), inInclusiveRange(1200, 1300));
          expect(until(true), inInclusiveRange(6000, 10100));
          director.dispose();
        });
      });

      test('glances are seeded: the same seed repeats them', () {
        List<double> run(int seed) {
          final List<double> angles = <double>[];
          fakeAsync((FakeAsync async) {
            currentTime = DateTime(2026, 10, 29, 12);
            final PerformanceDirector director = PerformanceDirector(
              now: () => currentTime,
              seed: seed,
            );
            director.intents.listen((PerformanceIntent i) {
              if (i.gaze case GazeAway(:final double angle)) {
                angles.add(angle);
              }
            });
            director.setIdleStage(1);
            advance(async, 60000);
            director.dispose();
          });
          return angles;
        }

        expect(run(3), run(3));
        expect(run(3), isNotEmpty);
      });

      test('stage 2 brings the tablet out for 8 s once a minute', () {
        fakeAsync((FakeAsync async) {
          final PerformanceDirector director = build();
          director.intents.listen((_) {});
          director.setIdleStage(2);
          expect(director.current.prop, AvatarProp.tablet);

          advance(async, 7900);
          expect(director.current.prop, AvatarProp.tablet);
          advance(async, 200);
          expect(director.current.prop, AvatarProp.none);

          advance(async, 50000);
          expect(director.current.prop, AvatarProp.none);
          advance(async, 2000);
          expect(director.current.prop, AvatarProp.tablet);
          advance(async, 8000);
          expect(director.current.prop, AvatarProp.none);
          director.dispose();
        });
      });

      test('stage 3 holds the tablet', () {
        fakeAsync((FakeAsync async) {
          final PerformanceDirector director = build();
          director.intents.listen((_) {});
          director.setIdleStage(2);
          advance(async, 9000);
          director.setIdleStage(3);
          expect(director.current.prop, AvatarProp.tablet);
          advance(async, 120000);
          expect(director.current.prop, AvatarProp.tablet);
          director.dispose();
        });
      });

      test('back to stage 0 puts the tablet away and stops the glances', () {
        fakeAsync((FakeAsync async) {
          final PerformanceDirector director = build();
          director.intents.listen((_) {});
          director.setIdleStage(3);
          director.setIdleStage(0);
          expect(director.current.prop, AvatarProp.none);
          director.setIdleStage(1);
          director.setIdleStage(0);
          advance(async, 60000);
          expect(director.current.gaze, const GazeTarget.user());
          expect(async.nonPeriodicTimerCount, 0);
          director.dispose();
        });
      });

      test('an LLM gesture clears the idle tablet and plays', () async {
        final PerformanceDirector director = build();
        int signals = 0;
        director.activity.listen((_) => signals++);
        director.setIdleStage(3);
        director.requestGesture(AvatarGesture.wave);
        expect(director.current.idleStage, 0);
        expect(director.current.prop, AvatarProp.none);
        expect(director.current.pendingGesture, AvatarGesture.wave);
        await Future<void>.delayed(Duration.zero);
        expect(signals, 1, reason: 'the ladder hears it');
        director.dispose();
      });

      test('an auto gesture waits while the idle tablet is out', () {
        final PerformanceDirector director = build();
        director.setIdleStage(3);
        director.requestGesture(AvatarGesture.wave, source: GestureSource.auto);
        expect(director.current.pendingGesture, isNull);
        expect(director.current.idleStage, 3);
        director.dispose();
      });

      test('an LLM gesture is still dropped while a lookup tool holds the '
          'tablet', () {
        final PerformanceDirector director = build();
        director.setActiveTool('searchGoogle');
        director.requestGesture(AvatarGesture.wave);
        expect(director.current.pendingGesture, isNull);
        expect(director.current.prop, AvatarProp.tablet);
        director.dispose();
      });

      test('dispose cancels the idle timers', () {
        fakeAsync((FakeAsync async) {
          final PerformanceDirector director = build();
          director.setIdleStage(1);
          director.dispose();
          expect(async.nonPeriodicTimerCount, 0);
          director.setIdleStage(2);
          director.dispose();
        });
      });
    });

    group('speech and activity win over the idle ladder', () {
      test('speaking resets the stage, the prop and the gaze', () {
        fakeAsync((FakeAsync async) {
          final PerformanceDirector director = build();
          director.intents.listen((_) {});
          director.setIdleStage(3);
          expect(director.current.prop, AvatarProp.tablet);

          director.setSpeaking(true);
          final PerformanceIntent now = director.current;
          expect(now.idleStage, 0);
          expect(now.prop, AvatarProp.none);
          expect(now.gaze, const GazeTarget.user());
          expect(now.lean, 0);
          expect(async.nonPeriodicTimerCount, 0);

          // a late stage from the ladder (it resets on the same signal) is
          // harmless: the next activity clears it again
          director.setSpeaking(false);
          expect(director.current.prop, AvatarProp.none);
          director.dispose();
        });
      });

      test('typing while the tablet is idle-out puts it away', () {
        final PerformanceDirector director = build();
        director.setIdleStage(3);
        director.setComposer(typed('a', caret: 0.7));
        final PerformanceIntent i = director.current;
        expect(i.idleStage, 0);
        expect(i.prop, AvatarProp.none);
        expect(i.gaze, const GazeTarget.caret(0.7));
        expect(i.lean, 0.6);
        director.dispose();
      });

      test('a tool starting overrides the idle tablet with its own', () {
        final PerformanceDirector director = build();
        director.setIdleStage(3);
        director.setActiveTool('saveMemory');
        expect(director.current.idleStage, 0);
        expect(director.current.prop, AvatarProp.none);
        director.setActiveTool('searchGoogle');
        expect(director.current.prop, AvatarProp.tablet);
        director.dispose();
      });

      test('onUserActivity resets the stage and tells the listeners', () async {
        final PerformanceDirector director = build();
        int signals = 0;
        director.activity.listen((_) => signals++);
        director.setIdleStage(2);
        director.onUserActivity();
        expect(director.current.idleStage, 0);
        expect(director.current.prop, AvatarProp.none);
        await Future<void>.delayed(Duration.zero);
        expect(signals, 1);
        director.dispose();
      });

      test(
        'speech, tool starts and composer reports count as activity',
        () async {
          final PerformanceDirector director = build();
          int signals = 0;
          director.activity.listen((_) => signals++);
          director.setSpeaking(true);
          director.setActiveTool('searchGoogle');
          director.setComposer(typed('a'));
          await Future<void>.delayed(Duration.zero);
          expect(signals, 3);
          director.dispose();
        },
      );
    });
  });
}
