import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_cue.dart';
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/domain/models/avatar_animation.dart';
import 'package:yofardev_ai/features/avatar/domain/services/avatar_animation_service.dart';
import 'package:yofardev_ai/features/avatar/domain/services/performance_director.dart';
import 'package:yofardev_ai/features/avatar/domain/services/avatar_cue_service.dart';
import 'package:yofardev_ai/features/talking/domain/repositories/talking_repository.dart';
import 'package:yofardev_ai/features/talking/domain/services/tts_playback_service.dart';

class MockTalkingRepository extends Mock implements TalkingRepository {}

void main() {
  late AvatarAnimationService animationService;
  late TtsPlaybackService playbackService;
  late StreamController<List<AvatarCue>> streamingCuesController;
  late DateTime currentTime;
  late List<AvatarAnimation> forwarded;

  /// Lets broadcast-stream events deliver (they arrive in microtasks).
  Future<void> drain() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  late PerformanceDirector director;

  AvatarCueService buildService() => AvatarCueService(
    playbackService: playbackService,
    animationService: animationService,
    streamingCues: streamingCuesController.stream,
    director: director,
  );

  setUp(() {
    animationService = AvatarAnimationService();
    playbackService = TtsPlaybackService(MockTalkingRepository());
    streamingCuesController = StreamController<List<AvatarCue>>.broadcast();
    currentTime = DateTime(2026, 10, 22, 12);
    director = PerformanceDirector(now: () => currentTime);
    addTearDown(director.dispose);
    forwarded = <AvatarAnimation>[];
    final StreamSubscription<AvatarAnimation> sub = animationService.animations
        .listen(forwarded.add);
    addTearDown(sub.cancel);
    addTearDown(animationService.dispose);
    addTearDown(streamingCuesController.close);
  });

  tearDown(() {
    playbackService.dispose();
  });

  group('AvatarCueService TTS playback path', () {
    test('forwards a gesture cue when the audio starts', () async {
      final AvatarCueService service = buildService();
      addTearDown(service.dispose);

      playbackService.fireCues(<AvatarCue>[
        const AvatarCue.gesture(AvatarGesture.wave),
      ]);
      await drain();

      expect(forwarded, <AvatarAnimation>[
        const AvatarAnimation.gesture(AvatarGesture.wave),
      ]);
    });

    test('forwards at most one gesture per chunk', () async {
      final AvatarCueService service = buildService();
      addTearDown(service.dispose);

      playbackService.fireCues(<AvatarCue>[
        const AvatarCue.gesture(AvatarGesture.wave),
        const AvatarCue.gesture(AvatarGesture.clap),
      ]);
      await drain();

      expect(forwarded, hasLength(1));
      expect(forwarded.single, isA<AvatarAnimationGesture>());
    });

    test('applies the 1.5 s cooldown between gestures', () async {
      final AvatarCueService service = buildService();
      addTearDown(service.dispose);

      playbackService.fireCues(<AvatarCue>[
        const AvatarCue.gesture(AvatarGesture.wave),
      ]);
      await drain();
      expect(forwarded, hasLength(1));

      // 1 s later: still cooling down.
      currentTime = currentTime.add(const Duration(seconds: 1));
      playbackService.fireCues(<AvatarCue>[
        const AvatarCue.gesture(AvatarGesture.clap),
      ]);
      await drain();
      expect(forwarded, hasLength(1));

      // A third cue replaces the queued one (queue keeps 1 slot free).
      currentTime = currentTime.add(const Duration(milliseconds: 600));
      playbackService.fireCues(<AvatarCue>[
        const AvatarCue.gesture(AvatarGesture.clap),
      ]);
      await drain();
      // Timing changed with the director queue: the queued gesture only
      // plays once the playing one finishes (onGestureDone) and the
      // cooldown since its start has elapsed.
      currentTime = currentTime.add(const Duration(milliseconds: 1000));
      director.onGestureDone();
      await drain();
      expect(forwarded, hasLength(2));
      expect(forwarded.last, const AvatarAnimation.gesture(AvatarGesture.clap));
    });

    test('scene events are not throttled', () async {
      final AvatarCueService service = buildService();
      addTearDown(service.dispose);

      playbackService.fireCues(<AvatarCue>[
        const AvatarCue.sceneEvent(SceneEvent.tvOn),
        const AvatarCue.sceneEvent(SceneEvent.catWalksBy),
      ]);
      await drain();

      expect(forwarded, hasLength(2));
      expect(forwarded, <AvatarAnimation>[
        const AvatarAnimation.sceneEvent(SceneEvent.tvOn),
        const AvatarAnimation.sceneEvent(SceneEvent.catWalksBy),
      ]);
    });

    test('a scene event fires even right after a gesture', () async {
      final AvatarCueService service = buildService();
      addTearDown(service.dispose);

      playbackService.fireCues(<AvatarCue>[
        const AvatarCue.gesture(AvatarGesture.wave),
        const AvatarCue.sceneEvent(SceneEvent.tvOn),
      ]);
      await drain();

      expect(forwarded, hasLength(2));
    });

    test('cues attached to playing audio are forwarded', () async {
      final AvatarCueService service = buildService();
      addTearDown(service.dispose);

      // Real audio-start path: amplitudes present so the animation starts
      // and CuesReachedEvent fires with the item's cues.
      playbackService.startAmplitudeAnimation(
        '/tmp/fake.wav',
        <int>[3],
        const Duration(seconds: 1),
        cues: const <AvatarCue>[AvatarCue.gesture(AvatarGesture.nod)],
      );
      await drain();

      expect(forwarded, <AvatarAnimation>[
        const AvatarAnimation.gesture(AvatarGesture.nod),
      ]);
    });
  });

  group('AvatarCueService TTS-disabled path', () {
    test(
      'forwards cues from the streaming channel through the same guard',
      () async {
        final AvatarCueService service = buildService();
        addTearDown(service.dispose);

        streamingCuesController.add(<AvatarCue>[
          const AvatarCue.gesture(AvatarGesture.shrug),
        ]);
        await drain();
        streamingCuesController.add(<AvatarCue>[
          const AvatarCue.gesture(AvatarGesture.nod),
        ]);
        await drain();

        expect(forwarded, hasLength(1));
        expect(
          forwarded.single,
          const AvatarAnimation.gesture(AvatarGesture.shrug),
        );
      },
    );
  });

  test(
    'dispose cancels the subscriptions: nothing is forwarded afterwards',
    () async {
      final AvatarCueService service = buildService();
      service.dispose();

      playbackService.fireCues(<AvatarCue>[
        const AvatarCue.gesture(AvatarGesture.wave),
      ]);
      await drain();

      expect(forwarded, isEmpty);
    },
  );

  group('AvatarCueService director inputs', () {
    test('forwards speaking, captions, mood and tool activity', () async {
      final StreamController<AvatarMood> moods =
          StreamController<AvatarMood>.broadcast();
      final StreamController<String?> tools =
          StreamController<String?>.broadcast();
      addTearDown(moods.close);
      addTearDown(tools.close);
      final AvatarCueService service = AvatarCueService(
        playbackService: playbackService,
        animationService: animationService,
        streamingCues: streamingCuesController.stream,
        director: director,
        moods: moods.stream,
        toolActivity: tools.stream,
      );
      addTearDown(service.dispose);

      moods.add(AvatarMood.happy);
      tools.add('weather');
      await drain();
      expect(director.current.activeTool, 'weather');
      expect(director.current.gaze, const GazeTarget.away(0.6));
      expect(director.current.emotion, emotionForMood(AvatarMood.happy));

      tools.add(null);
      playbackService.startAmplitudeAnimation(
        'a.wav',
        <int>[10, 10],
        const Duration(milliseconds: 50),
        caption: 'Is it raining?',
      );
      await drain();
      expect(director.current.speaking, isTrue);
      expect(director.current.gaze, const GazeTarget.user());
      // The caption ran the auto-acting rules: a question -> think.
      expect(director.current.pendingGesture, AvatarGesture.think);

      // The 2-frame, 50 ms animation completes on its own.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await drain();
      expect(director.current.speaking, isFalse);
    });
  });
}
