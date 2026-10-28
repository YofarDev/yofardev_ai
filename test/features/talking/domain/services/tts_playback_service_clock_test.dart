import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/features/talking/domain/repositories/talking_repository.dart';
import 'package:yofardev_ai/features/talking/domain/services/playback_clock.dart';
import 'package:yofardev_ai/features/talking/domain/services/tts_playback_service.dart';

class _MockTalkingRepository extends Mock implements TalkingRepository {}

/// Stopwatch whose elapsed time is driven by the test instead of the real
/// clock, so it is deterministic under [fakeAsync].
class _FakeStopwatch implements Stopwatch {
  Duration _elapsed = Duration.zero;
  bool _running = false;

  @override
  Duration get elapsed => _elapsed;

  @override
  int get elapsedMilliseconds => _elapsed.inMilliseconds;

  @override
  int get elapsedMicroseconds => _elapsed.inMicroseconds;

  @override
  int get elapsedTicks => _elapsed.inMicroseconds;

  @override
  int get frequency => 1000000;

  @override
  bool get isRunning => _running;

  void advance(Duration duration) {
    _elapsed += duration;
  }

  @override
  void start() {
    _running = true;
  }

  @override
  void stop() {
    _running = false;
  }

  @override
  void reset() {
    _elapsed = Duration.zero;
  }
}

class _FakePositionSource implements PlaybackPositionSource {
  Duration position = Duration.zero;
  bool returnNull = false;
  bool returnZero = false;

  @override
  Future<Duration?> currentPosition() async {
    if (returnNull) {
      return null;
    }
    if (returnZero) {
      return Duration.zero;
    }
    return position;
  }
}

/// Harness driving [TtsPlaybackService] with a [PlaybackClock] whose
/// stopwatch and position source are fully controlled by the test.
class _Harness {
  _Harness(this.async) {
    final _MockTalkingRepository repository = _MockTalkingRepository();
    when(repository.stop).thenAnswer((_) async {});
    clock = PlaybackClock(source: source, stopwatchFactory: () => stopwatch);
    service = TtsPlaybackService(repository, clock: clock);
    service.events.listen(events.add);
  }

  final FakeAsync async;
  final _FakeStopwatch stopwatch = _FakeStopwatch();
  final _FakePositionSource source = _FakePositionSource();
  late final PlaybackClock clock;
  late final TtsPlaybackService service;
  final List<PlaybackEvent> events = <PlaybackEvent>[];

  /// Advance of one service tick (16 ms) with a source that tracks the
  /// stopwatch exactly.
  void advanceTick() {
    source.position += TtsPlaybackService.defaultTick;
    stopwatch.advance(TtsPlaybackService.defaultTick);
    async.elapse(TtsPlaybackService.defaultTick);
  }

  /// Applies a pending resync immediately (the internal resync timer would
  /// fire it on the next 100 ms boundary).
  void resyncNow() {
    unawaited(clock.resync());
    async.flushMicrotasks();
  }

  List<int> get mouthStates => events
      .whereType<MouthStateUpdatedEvent>()
      .map((MouthStateUpdatedEvent e) => e.mouthState)
      .toList();
}

int _stateOf(int amplitude) {
  if (amplitude == 0) return 0;
  if (amplitude <= 5) return 1;
  if (amplitude <= 12) return 2;
  if (amplitude <= 18) return 3;
  return 4;
}

void main() {
  test(
    'with a position that tracks time exactly, mouth states follow the amplitudes in order',
    () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async);
        // 5 frames, 200 ms each, all in different mouth states.
        h.service.startAmplitudeAnimation('/a.wav', const <int>[
          1,
          8,
          16,
          30,
          0,
        ], const Duration(milliseconds: 1000));

        // 70 ticks = 1120 ms: past the 1000 ms end of the audio.
        for (int i = 0; i < 70; i++) {
          h.advanceTick();
        }

        expect(h.mouthStates, <int>[1, 2, 3, 4, 0]);
        expect(h.events.whereType<SpeakingStartedEvent>(), hasLength(1));
        h.service.dispose();
      });
    },
  );

  test(
    'after a 300 ms stall, the next tick shows the frame for the real position',
    () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async);
        // 100 frames of 20 ms; states cycle 1,2,3,4,0 every 5 frames.
        final List<int> amplitudes = List<int>.generate(
          100,
          (int i) => const <int>[1, 8, 16, 30, 0][i % 5],
        );
        h.service.startAmplitudeAnimation(
          '/a.wav',
          amplitudes,
          const Duration(milliseconds: 2000),
        );
        for (int i = 0; i < 13; i++) {
          h.advanceTick();
        }
        final int eventsBeforeStall = h.events.length;

        // The UI isolate stalls: the real audio position jumps forward 300 ms
        // while no tick is delivered.
        h.source.position += const Duration(milliseconds: 300);
        h.resyncNow();
        final Duration positionAfterResync = h.clock.position;
        expect(
          positionAfterResync,
          greaterThan(const Duration(milliseconds: 500)),
        );

        // The very next tick must land on the real position's frame: no lost
        // frames replayed, no slow catch-up.
        h.advanceTick();
        final int realIndex = h.clock.position.inMilliseconds ~/ 20;
        expect(realIndex, greaterThanOrEqualTo(25));
        expect(h.mouthStates.last, _stateOf(amplitudes[realIndex]));
        // A single new mouth event, not a burst replaying the stall gap.
        expect(h.events.length - eventsBeforeStall, lessThanOrEqualTo(2));
        h.service.dispose();
      });
    },
  );

  test(
    'a position source that returns null or 0 for the first 300 ms still starts the animation',
    () {
      fakeAsync((FakeAsync async) {
        final _Harness h = _Harness(async);
        h.source.returnNull = true;
        h.service.startAmplitudeAnimation('/a.wav', const <int>[
          1,
          8,
          16,
          30,
          0,
        ], const Duration(milliseconds: 1000));

        for (int i = 0; i < 19; i++) {
          h.advanceTick();
        }
        // Stopwatch-driven estimate: the animation has been progressing.
        expect(h.mouthStates, isNotEmpty);
        expect(h.events.whereType<SpeakingStartedEvent>(), hasLength(1));

        // Now the source starts reporting zero (still in the cold-start grace
        // window): the estimate must be kept.
        h.source.returnNull = false;
        h.source.returnZero = true;
        for (int i = 0; i < 10; i++) {
          h.advanceTick();
        }
        expect(h.mouthStates, isNotEmpty);
        expect(h.events.whereType<AnimationCompletedEvent>(), isEmpty);
        h.service.dispose();
      });
    },
  );

  test('a -76 ms correction never emits an earlier frame index', () {
    fakeAsync((FakeAsync async) {
      final _Harness h = _Harness(async);
      final List<int> amplitudes = List<int>.generate(
        100,
        (int i) => const <int>[1, 8, 16, 30, 0][i % 5],
      );
      h.service.startAmplitudeAnimation(
        '/a.wav',
        amplitudes,
        const Duration(milliseconds: 2000),
      );
      for (int i = 0; i < 13; i++) {
        h.advanceTick();
      }
      final Duration positionBefore = h.clock.position;
      final int indexBefore = positionBefore.inMilliseconds ~/ 20;

      // The player reports a position 76 ms behind the estimate.
      h.source.position -= const Duration(milliseconds: 76);
      h.resyncNow();

      // Absorbed: the estimate holds still.
      expect(h.clock.position, positionBefore);

      h.advanceTick();
      // Still holding: the index cannot go backwards.
      expect(h.clock.position, greaterThanOrEqualTo(positionBefore));
      final int indexAfter = h.clock.position.inMilliseconds ~/ 20;
      expect(indexAfter, greaterThanOrEqualTo(indexBefore));
      expect(h.mouthStates.last, _stateOf(amplitudes[indexAfter]));
      h.service.dispose();
    });
  });

  test('a +200 ms correction jumps forward immediately', () {
    fakeAsync((FakeAsync async) {
      final _Harness h = _Harness(async);
      final List<int> amplitudes = List<int>.generate(
        100,
        (int i) => const <int>[1, 8, 16, 30, 0][i % 5],
      );
      h.service.startAmplitudeAnimation(
        '/a.wav',
        amplitudes,
        const Duration(milliseconds: 2000),
      );
      for (int i = 0; i < 13; i++) {
        h.advanceTick();
      }

      h.source.position += const Duration(milliseconds: 200);
      h.resyncNow();
      expect(
        h.clock.position,
        greaterThanOrEqualTo(
          h.source.position - TtsPlaybackService.defaultTick,
        ),
      );

      h.advanceTick();
      final int index = h.clock.position.inMilliseconds ~/ 20;
      expect(index, greaterThanOrEqualTo(21));
      expect(h.mouthStates.last, _stateOf(amplitudes[index]));
      h.service.dispose();
    });
  });

  test('stop() mid-sentence: no events after it and no active timer', () {
    fakeAsync((FakeAsync async) {
      final _Harness h = _Harness(async);
      final List<int> amplitudes = List<int>.generate(
        100,
        (int i) => const <int>[1, 8, 16, 30, 0][i % 5],
      );
      h.service.startAmplitudeAnimation(
        '/a.wav',
        amplitudes,
        const Duration(milliseconds: 2000),
      );
      for (int i = 0; i < 5; i++) {
        h.advanceTick();
      }

      unawaited(h.service.stop());
      async.flushMicrotasks();
      final int eventsAtStop = h.events.length;
      expect(h.events.last, isA<SpeakingStoppedEvent>());

      // Keep fake time running well past the end of the sentence: a stopped
      // service must not emit anything (timer cancelled, clock stopped).
      for (int i = 0; i < 40; i++) {
        h.advanceTick();
      }
      expect(h.events.length, eventsAtStop);
      expect(h.events.whereType<AnimationCompletedEvent>(), isEmpty);
      expect(async.pendingTimers.where((FakeTimer t) => t.isActive), isEmpty);
      h.service.dispose();
    });
  });

  test('AnimationCompletedEvent fires exactly once', () {
    fakeAsync((FakeAsync async) {
      final _Harness h = _Harness(async);
      h.service.startAmplitudeAnimation('/a.wav', const <int>[
        1,
        8,
        16,
        30,
        0,
      ], const Duration(milliseconds: 1000));
      // Run well past the end of the audio (1000 ms).
      for (int i = 0; i < 70; i++) {
        h.advanceTick();
      }

      expect(h.events.whereType<AnimationCompletedEvent>(), hasLength(1));
      h.service.dispose();
    });
  });

  test(
    'without a clock, the pure stopwatch clock still completes the animation',
    () async {
      final TtsPlaybackService service = TtsPlaybackService(
        _MockTalkingRepository(),
      );
      final List<PlaybackEvent> events = <PlaybackEvent>[];
      service.events.listen(events.add);
      service.startAmplitudeAnimation('/a.wav', const <int>[
        3,
        3,
        3,
        3,
        3,
      ], const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(events.whereType<AnimationCompletedEvent>(), hasLength(1));
      service.dispose();
    },
  );
}
