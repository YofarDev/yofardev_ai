import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_cue.dart';
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/core/models/performance/speech_timeline.dart';
import 'package:yofardev_ai/core/models/performance/viseme.dart';
import 'package:yofardev_ai/features/talking/domain/repositories/talking_repository.dart';
import 'package:yofardev_ai/features/talking/domain/services/playback_clock.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

class _MockTalkingRepository extends Mock implements TalkingRepository {}

/// Stopwatch advanced by the test (deterministic under [fakeAsync]).
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
    if (_running) {
      _elapsed += duration;
    }
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

/// A position source with no player: the clock runs on its stopwatch.
class _NoPositionSource implements PlaybackPositionSource {
  @override
  Future<Duration?> currentPosition() async => null;
}

void main() {
  late _MockTalkingRepository repository;

  setUp(() {
    repository = _MockTalkingRepository();
    when(repository.stop).thenAnswer((_) async {});
  });

  group('SpeechTimelineEvent', () {
    late TtsPlaybackService service;
    late List<PlaybackEvent> events;

    setUp(() {
      service = TtsPlaybackService(repository);
      events = <PlaybackEvent>[];
      service.events.listen(events.add);
    });

    tearDown(() => service.dispose());

    test('the order is Started -> Timeline -> Cues -> Caption', () async {
      service.startAmplitudeAnimation(
        '/a.wav',
        <int>[3],
        const Duration(seconds: 1),
        caption: 'Hi there.',
        cues: const <AvatarCue>[AvatarCue.gesture(AvatarGesture.wave)],
      );
      await Future<void>.delayed(Duration.zero);
      service.cancelAnimation();

      expect(events, hasLength(4));
      expect(events[0], isA<SpeakingStartedEvent>());
      expect(events[1], isA<SpeechTimelineEvent>());
      expect(events[2], isA<CuesReachedEvent>());
      expect(events[3], isA<CaptionEvent>());
    });

    test('a given timeline is passed through unchanged', () async {
      const SpeechTimeline timeline = SpeechTimeline(
        visemes: <VisemeSpan>[
          VisemeSpan(
            viseme: Viseme.pp,
            start: Duration.zero,
            end: Duration(milliseconds: 60),
          ),
        ],
        duration: Duration(milliseconds: 60),
        isQuestion: true,
      );
      service.startAmplitudeAnimation(
        '/a.wav',
        <int>[3],
        const Duration(seconds: 1),
        timeline: timeline,
      );
      await Future<void>.delayed(Duration.zero);
      service.cancelAnimation();

      final SpeechTimelineEvent event = events
          .whereType<SpeechTimelineEvent>()
          .single;
      expect(event.timeline, timeline);
    });

    test(
      'a null timeline becomes an amplitude timeline as long as the audio',
      () async {
        service.startAmplitudeAnimation(
          '/a.wav',
          <int>[0, 20, 20],
          const Duration(seconds: 1),
          caption: 'Really?',
        );
        await Future<void>.delayed(Duration.zero);
        service.cancelAnimation();

        final SpeechTimeline timeline = events
            .whereType<SpeechTimelineEvent>()
            .single
            .timeline;
        expect(timeline.duration, const Duration(seconds: 1));
        expect(timeline.visemes.first.viseme, Viseme.sil);
        expect(timeline.visemes.last.viseme, Viseme.aa);
        expect(timeline.isQuestion, isTrue);
      },
    );

    test('no timeline when the sentence never starts speaking', () async {
      service.startAmplitudeAnimation(
        '/a.wav',
        <int>[],
        const Duration(seconds: 1),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events.whereType<SpeechTimelineEvent>(), isEmpty);
    });
  });

  group('replaceTimeline', () {
    const SpeechTimeline late = SpeechTimeline(
      visemes: <VisemeSpan>[
        VisemeSpan(
          viseme: Viseme.pp,
          start: Duration.zero,
          end: Duration(milliseconds: 60),
        ),
      ],
      duration: Duration(milliseconds: 60),
    );
    late TtsPlaybackService service;
    late List<PlaybackEvent> events;

    setUp(() {
      service = TtsPlaybackService(repository);
      events = <PlaybackEvent>[];
      service.events.listen(events.add);
    });

    tearDown(() => service.dispose());

    Future<void> start(String path) async {
      service.startAmplitudeAnimation(
        path,
        <int>[3, 3, 3],
        const Duration(seconds: 1),
        caption: 'Hi there.',
      );
      await Future<void>.delayed(Duration.zero);
    }

    test(
      'a second timeline event for the playing sentence, marked as a replacement',
      () async {
        await start('/a.wav');
        events.clear();

        expect(service.replaceTimeline('/a.wav', late), isTrue);
        await Future<void>.delayed(Duration.zero);
        service.cancelAnimation();

        // nothing else: no new sentence, no cues, no caption
        expect(events, hasLength(1));
        final SpeechTimelineEvent event = events.single as SpeechTimelineEvent;
        expect(event.timeline, late);
        expect(event.replacesCurrent, isTrue);
      },
    );

    test('the first event of a sentence is not a replacement', () async {
      await start('/a.wav');
      service.cancelAnimation();

      expect(
        events.whereType<SpeechTimelineEvent>().single.replacesCurrent,
        isFalse,
      );
    });

    test('nothing for a sentence that was interrupted or stopped', () async {
      await start('/a.wav');
      await service.interrupt();
      events.clear();
      expect(service.replaceTimeline('/a.wav', late), isFalse);

      await start('/b.wav');
      await service.stop();
      await Future<void>.delayed(Duration.zero);
      events.clear();
      expect(service.replaceTimeline('/b.wav', late), isFalse);
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
    });

    test('nothing for a sentence that already finished', () {
      fakeAsync((FakeAsync async) {
        final _FakeStopwatch stopwatch = _FakeStopwatch();
        final TtsPlaybackService timed = TtsPlaybackService(
          repository,
          tick: const Duration(milliseconds: 10),
          stopwatchFactory: () => stopwatch,
        );
        final List<PlaybackEvent> seen = <PlaybackEvent>[];
        timed.events.listen(seen.add);
        timed.startAmplitudeAnimation('/a.wav', <int>[
          3,
          3,
        ], const Duration(milliseconds: 100));
        stopwatch.advance(const Duration(milliseconds: 200));
        async.elapse(const Duration(milliseconds: 20));
        expect(seen.whereType<AnimationCompletedEvent>(), isNotEmpty);
        seen.clear();

        expect(timed.replaceTimeline('/a.wav', late), isFalse);
        async.flushMicrotasks();
        expect(seen, isEmpty);
        timed.dispose();
      });
    });

    test('nothing for the previous sentence once the next one plays', () async {
      await start('/a.wav');
      await start('/b.wav');
      events.clear();

      expect(service.replaceTimeline('/a.wav', late), isFalse);
      expect(service.replaceTimeline('/b.wav', late), isTrue);
      service.cancelAnimation();
    });
  });

  group('speechPosition', () {
    test('without a clock: null before, advancing during, null after stop', () {
      fakeAsync((FakeAsync async) {
        final _FakeStopwatch stopwatch = _FakeStopwatch();
        final TtsPlaybackService service = TtsPlaybackService(
          repository,
          stopwatchFactory: () => stopwatch,
        );
        expect(service.speechPosition, isNull);

        service.startAmplitudeAnimation(
          '/a.wav',
          List<int>.filled(40, 10),
          const Duration(seconds: 1),
        );
        expect(service.speechPosition, Duration.zero);
        stopwatch.advance(const Duration(milliseconds: 300));
        async.elapse(const Duration(milliseconds: 16));
        expect(service.speechPosition, const Duration(milliseconds: 300));

        unawaited(service.stop());
        async.flushMicrotasks();
        expect(service.speechPosition, isNull);
        service.dispose();
      });
    });

    test('with a clock: advances during, null after completion', () {
      fakeAsync((FakeAsync async) {
        final _FakeStopwatch stopwatch = _FakeStopwatch();
        final PlaybackClock clock = PlaybackClock(
          source: _NoPositionSource(),
          stopwatchFactory: () => stopwatch,
        );
        final TtsPlaybackService service = TtsPlaybackService(
          repository,
          clock: clock,
        );
        final List<PlaybackEvent> events = <PlaybackEvent>[];
        service.events.listen(events.add);
        expect(service.speechPosition, isNull);

        service.startAmplitudeAnimation(
          '/a.wav',
          List<int>.filled(20, 10),
          const Duration(milliseconds: 500),
        );
        stopwatch.advance(const Duration(milliseconds: 200));
        async.elapse(const Duration(milliseconds: 16));
        expect(service.speechPosition, const Duration(milliseconds: 200));

        // Run past the end of the audio.
        for (int i = 0; i < 30; i++) {
          stopwatch.advance(const Duration(milliseconds: 16));
          async.elapse(const Duration(milliseconds: 16));
        }
        expect(events.whereType<AnimationCompletedEvent>(), hasLength(1));
        expect(service.speechPosition, isNull);
        service.dispose();
      });
    });
  });
}
