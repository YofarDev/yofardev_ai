import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_cue.dart';
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/features/talking/domain/repositories/talking_repository.dart';
import 'package:yofardev_ai/features/talking/domain/services/tts_playback_service.dart';

class _MockTalkingRepository extends Mock implements TalkingRepository {}

void main() {
  late TtsPlaybackService service;
  late List<PlaybackEvent> events;

  setUp(() {
    service = TtsPlaybackService(_MockTalkingRepository());
    events = <PlaybackEvent>[];
    service.events.listen(events.add);
  });

  tearDown(() => service.dispose());

  test(
    'emits the caption right after SpeakingStartedEvent and its timeline',
    () async {
      service.startAmplitudeAnimation(
        '/a.wav',
        <int>[3],
        const Duration(seconds: 1),
        caption: 'Hello there.',
      );
      await Future<void>.delayed(Duration.zero);
      service.cancelAnimation();

      // M2: the sentence's SpeechTimelineEvent sits between the two.
      expect(events[0], isA<SpeakingStartedEvent>());
      expect(events[1], isA<SpeechTimelineEvent>());
      expect(events[2], isA<CaptionEvent>());
      expect((events[2] as CaptionEvent).text, 'Hello there.');
    },
  );

  test('cues are emitted before the caption', () async {
    service.startAmplitudeAnimation(
      '/a.wav',
      <int>[3],
      const Duration(seconds: 1),
      caption: 'Is it raining?',
      cues: const <AvatarCue>[AvatarCue.gesture(AvatarGesture.wave)],
    );
    await Future<void>.delayed(Duration.zero);
    service.cancelAnimation();

    expect(events[0], isA<SpeakingStartedEvent>());
    expect(events[1], isA<SpeechTimelineEvent>());
    expect(events[2], isA<CuesReachedEvent>());
    expect(events[3], isA<CaptionEvent>());
  });

  test('no caption event for an empty or missing caption', () async {
    service.startAmplitudeAnimation(
      '/a.wav',
      <int>[3],
      const Duration(seconds: 1),
      caption: '  ',
    );
    service.startAmplitudeAnimation('/b.wav', <int>[
      3,
    ], const Duration(seconds: 1));
    await Future<void>.delayed(Duration.zero);
    service.cancelAnimation();

    expect(events.whereType<CaptionEvent>(), isEmpty);
  });

  test('no caption when the sentence never starts speaking', () async {
    service.startAmplitudeAnimation(
      '/a.wav',
      <int>[],
      const Duration(seconds: 1),
      caption: 'Hello there.',
    );
    await Future<void>.delayed(Duration.zero);

    expect(events.whereType<CaptionEvent>(), isEmpty);
  });
}
