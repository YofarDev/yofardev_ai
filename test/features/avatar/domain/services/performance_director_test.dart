import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/features/avatar/domain/models/performance_intent.dart';
import 'package:yofardev_ai/features/avatar/domain/services/performance_director.dart';

void main() {
  group('PerformanceDirector', () {
    late DateTime currentTime;

    PerformanceDirector build(FakeAsync async) {
      currentTime = DateTime(2026, 10, 28, 12);
      return PerformanceDirector(now: () => currentTime);
    }

    /// Elapses [ms] of fake time and moves the injectable clock along.
    void advance(FakeAsync async, PerformanceDirector director, int ms) {
      // Advance the injectable clock first so timers firing during the
      // elapse already see the new wall time.
      currentTime = currentTime.add(Duration(milliseconds: ms));
      async.elapse(Duration(milliseconds: ms));
    }

    test(
      'queue order: requests while playing are queued and played in order',
      () {
        fakeAsync((FakeAsync async) {
          final PerformanceDirector director = build(async);
          final List<PerformanceIntent> intents = <PerformanceIntent>[];
          director.intents.listen(intents.add);

          director.requestGesture(AvatarGesture.wave);
          expect(director.current.pendingGesture, AvatarGesture.wave);
          expect(director.current.gestureSerial, 1);

          director.requestGesture(AvatarGesture.clap);
          director.requestGesture(AvatarGesture.nod);
          // Still playing wave: nothing else started.
          expect(director.current.pendingGesture, AvatarGesture.wave);

          director.onGestureDone();
          // Cooldown since wave's start has not elapsed yet: clap plays after
          // the remaining 1.5 s.
          advance(async, director, 1500);
          expect(director.current.pendingGesture, AvatarGesture.clap);
          expect(director.current.gestureSerial, 2);

          director.onGestureDone();
          advance(async, director, 1500);
          expect(director.current.pendingGesture, AvatarGesture.nod);
          expect(director.current.gestureSerial, 3);

          director.onGestureDone();
          advance(async, director, 1500);
          expect(director.current.pendingGesture, isNull);

          final List<AvatarGesture?> started = intents
              .map((PerformanceIntent i) => i.pendingGesture)
              .where((AvatarGesture? g) => g != null)
              .toList();
          expect(started, <AvatarGesture>[
            AvatarGesture.wave,
            AvatarGesture.clap,
            AvatarGesture.nod,
          ]);
          director.dispose();
        });
      },
    );

    test('LLM gestures outrank auto gestures in the queue', () {
      fakeAsync((FakeAsync async) {
        final PerformanceDirector director = build(async);
        director.intents.listen((_) {});

        director.requestGesture(AvatarGesture.wave, source: GestureSource.llm);
        director.requestGesture(
          AvatarGesture.shrug,
          source: GestureSource.auto,
        );
        director.requestGesture(AvatarGesture.clap, source: GestureSource.llm);

        director.onGestureDone();
        advance(async, director, 1500);
        // The queued LLM gesture wins over the older auto one.
        expect(director.current.pendingGesture, AvatarGesture.clap);

        director.onGestureDone();
        advance(async, director, 1500);
        expect(director.current.pendingGesture, AvatarGesture.shrug);
        director.dispose();
      });
    });

    test('the cooldown delays the next gesture since the last start', () {
      fakeAsync((FakeAsync async) {
        final PerformanceDirector director = build(async);
        director.intents.listen((_) {});

        director.requestGesture(AvatarGesture.wave);
        advance(async, director, 500);
        director.requestGesture(AvatarGesture.clap);
        director.onGestureDone();

        // Still inside the 1.5 s cooldown since wave started.
        advance(async, director, 800);
        expect(director.current.pendingGesture, isNull);

        advance(async, director, 200);
        expect(director.current.pendingGesture, AvatarGesture.clap);
        director.dispose();
      });
    });

    test('the 4 s safety timeout acts as onGestureDone', () {
      fakeAsync((FakeAsync async) {
        final PerformanceDirector director = build(async);
        director.intents.listen((_) {});

        director.requestGesture(AvatarGesture.wave);
        director.requestGesture(AvatarGesture.nod);

        // Nobody calls onGestureDone: the safety timeout clears wave and the
        // queued nod plays (cooldown long since elapsed).
        advance(async, director, 4000);
        expect(director.current.pendingGesture, AvatarGesture.nod);
        expect(director.current.gestureSerial, 2);
        director.dispose();
      });
    });

    test('the serial increments when the same gesture repeats', () {
      fakeAsync((FakeAsync async) {
        final PerformanceDirector director = build(async);
        final List<PerformanceIntent> intents = <PerformanceIntent>[];
        director.intents.listen(intents.add);

        director.requestGesture(AvatarGesture.nod);
        director.onGestureDone();
        advance(async, director, 1500);
        director.requestGesture(AvatarGesture.nod);

        async.flushMicrotasks();
        final List<int> serials = intents
            .where((PerformanceIntent i) => i.pendingGesture != null)
            .map((PerformanceIntent i) => i.gestureSerial)
            .toList();
        expect(serials, <int>[1, 2]);
        director.dispose();
      });
    });

    test('a full queue drops the oldest auto request first', () {
      fakeAsync((FakeAsync async) {
        final PerformanceDirector director = build(async);
        final List<PerformanceIntent> intents = <PerformanceIntent>[];
        director.intents.listen(intents.add);

        director.requestGesture(AvatarGesture.wave, source: GestureSource.llm);
        // Fill the queue with autos; the third (oldest auto) is dropped.
        director.requestGesture(AvatarGesture.clap, source: GestureSource.auto);
        director.requestGesture(
          AvatarGesture.shrug,
          source: GestureSource.auto,
        );
        director.requestGesture(AvatarGesture.nod, source: GestureSource.auto);

        director.onGestureDone();
        advance(async, director, 1500);
        director.onGestureDone();
        advance(async, director, 1500);

        final List<AvatarGesture> played = intents
            .map((PerformanceIntent i) => i.pendingGesture)
            .whereType<AvatarGesture>()
            .toList();
        // clap was dropped; shrug and nod survive.
        expect(played, <AvatarGesture>[
          AvatarGesture.wave,
          AvatarGesture.shrug,
          AvatarGesture.nod,
        ]);
        director.dispose();
      });
    });

    test('an auto request never evicts a queued LLM request', () {
      fakeAsync((FakeAsync async) {
        final PerformanceDirector director = build(async);
        final List<PerformanceIntent> intents = <PerformanceIntent>[];
        director.intents.listen(intents.add);

        director.requestGesture(AvatarGesture.wave, source: GestureSource.llm);
        director.requestGesture(AvatarGesture.clap, source: GestureSource.llm);
        director.requestGesture(AvatarGesture.shrug, source: GestureSource.llm);
        director.requestGesture(AvatarGesture.nod, source: GestureSource.auto);

        director.onGestureDone();
        advance(async, director, 1500);
        director.onGestureDone();
        advance(async, director, 1500);
        director.onGestureDone();
        advance(async, director, 1500);

        final List<AvatarGesture> played = intents
            .map((PerformanceIntent i) => i.pendingGesture)
            .whereType<AvatarGesture>()
            .toSet()
            .toList();
        expect(played, <AvatarGesture>[
          AvatarGesture.wave,
          AvatarGesture.clap,
          AvatarGesture.shrug,
        ]);
        director.dispose();
      });
    });

    test('dispose closes the intents stream', () {
      fakeAsync((FakeAsync async) {
        final PerformanceDirector director = build(async);
        director.intents.listen((_) {});
        expectLater(director.intents, emitsDone);
        director.dispose();
        async.flushMicrotasks();
      });
    });

    test('mood, speaking and tool drive the intent snapshot and gaze', () {
      fakeAsync((FakeAsync async) {
        final PerformanceDirector director = build(async);
        final List<PerformanceIntent> intents = <PerformanceIntent>[];
        director.intents.listen(intents.add);

        director.setMood(AvatarMood.happy);
        expect(director.current.emotion, emotionForMood(AvatarMood.happy));
        expect(director.current.face, actionUnitsForMood(AvatarMood.happy));

        director.setActiveTool('weather');
        // Tool active but not speaking: gaze away.
        expect(director.current.gaze, const GazeTarget.away(0.6));
        expect(director.current.activeTool, 'weather');

        director.setSpeaking(true);
        // Speaking outranks the tool for gaze.
        expect(director.current.gaze, isA<GazeUser>());
        expect(director.current.speaking, isTrue);

        director.setSpeaking(false);
        director.setActiveTool(null);
        director.setMood(null);
        expect(director.current.gaze, isA<GazeUser>());
        expect(director.current.emotion, emotionForMood(AvatarMood.neutral));
        director.dispose();
      });
    });
  });
}
