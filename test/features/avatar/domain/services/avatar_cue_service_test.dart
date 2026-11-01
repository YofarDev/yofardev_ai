import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_cue.dart';
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/core/models/avatar_mood.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/services/power/power_saver_source.dart';
import 'package:yofardev_ai/core/services/presence/composer_activity_service.dart';
import 'package:yofardev_ai/features/avatar/domain/models/avatar_animation.dart';
import 'package:yofardev_ai/features/avatar/domain/services/avatar_animation_service.dart';
import 'package:yofardev_ai/features/avatar/domain/services/idle_ladder.dart';
import 'package:yofardev_ai/features/avatar/domain/services/performance_director.dart';
import 'package:yofardev_ai/features/avatar/domain/services/avatar_cue_service.dart';
import 'package:yofardev_ai/features/talking/domain/repositories/talking_repository.dart';
import 'package:yofardev_ai/features/talking/domain/services/tts_playback_service.dart';

class MockTalkingRepository extends Mock implements TalkingRepository {}

class _NoPowerSaver implements PowerSaverSource {
  @override
  Future<bool> get isOn async => false;

  @override
  Stream<bool> get changes => const Stream<bool>.empty();
}

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

  group('AvatarCueService LLM gesture beats auto gesture', () {
    test('a sentence with a question and a wave cue plays the wave', () async {
      final AvatarCueService service = buildService();
      addTearDown(service.dispose);

      playbackService.startAmplitudeAnimation(
        '/tmp/fake.wav',
        <int>[3],
        const Duration(seconds: 1),
        cues: const <AvatarCue>[AvatarCue.gesture(AvatarGesture.wave)],
        caption: 'Is it raining?',
      );
      await drain();
      playbackService.cancelAnimation();

      expect(forwarded, <AvatarAnimation>[
        const AvatarAnimation.gesture(AvatarGesture.wave),
      ]);
    });

    test(
      'a later sentence without a gesture cue still gets auto rules',
      () async {
        final AvatarCueService service = buildService();
        addTearDown(service.dispose);

        playbackService.startAmplitudeAnimation(
          '/tmp/a.wav',
          <int>[3],
          const Duration(seconds: 1),
          cues: const <AvatarCue>[AvatarCue.gesture(AvatarGesture.wave)],
          caption: 'Hello.',
        );
        await drain();
        currentTime = currentTime.add(const Duration(minutes: 1));
        director.onGestureDone();
        playbackService.startAmplitudeAnimation(
          '/tmp/b.wav',
          <int>[3],
          const Duration(seconds: 1),
          caption: 'Is it raining?',
        );
        await drain();
        playbackService.cancelAnimation();

        expect(forwarded, <AvatarAnimation>[
          const AvatarAnimation.gesture(AvatarGesture.wave),
          const AvatarAnimation.gesture(AvatarGesture.think),
        ]);
      },
    );
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

  group('AvatarCueService persona', () {
    test(
      'the chat persona sets the director profile and the ladder scale',
      () async {
        final StreamController<ChatPersona> personas =
            StreamController<ChatPersona>.broadcast();
        addTearDown(personas.close);
        final IdleLadder ladder = IdleLadder(
          now: () => currentTime,
          power: _NoPowerSaver(),
          reduceMotion: () => false,
        );
        addTearDown(ladder.dispose);
        final AvatarCueService service = AvatarCueService(
          playbackService: playbackService,
          animationService: animationService,
          streamingCues: streamingCuesController.stream,
          director: director,
          personas: personas.stream,
          idleLadder: ladder,
        );
        addTearDown(service.dispose);

        expect(director.profile, BodyLanguageProfile.normal);
        expect(ladder.thresholdScale, 1);
        personas.add(ChatPersona.philosopher);
        await drain();
        final BodyLanguageProfile philosopher = BodyLanguageProfile.of(
          ChatPersona.philosopher,
        );
        expect(director.profile, philosopher);
        expect(director.current.body, philosopher);
        expect(ladder.thresholdScale, philosopher.idle.ladderScale);

        personas.add(ChatPersona.normal);
        await drain();
        expect(director.profile, BodyLanguageProfile.normal);
        expect(ladder.thresholdScale, 1);
      },
    );

    test(
      'a persona change mid-sentence moves the ladder pace at the sentence end',
      () async {
        final StreamController<ChatPersona> personas =
            StreamController<ChatPersona>.broadcast();
        addTearDown(personas.close);
        final IdleLadder ladder = IdleLadder(
          now: () => currentTime,
          power: _NoPowerSaver(),
          reduceMotion: () => false,
        );
        addTearDown(ladder.dispose);
        final AvatarCueService service = AvatarCueService(
          playbackService: playbackService,
          animationService: animationService,
          streamingCues: streamingCuesController.stream,
          director: director,
          personas: personas.stream,
          idleLadder: ladder,
        );
        addTearDown(service.dispose);
        // a long sentence (2 s), so a loaded test machine never ends it
        // before the persona arrives
        playbackService.startAmplitudeAnimation(
          'a.wav',
          List<int>.filled(40, 10),
          const Duration(milliseconds: 50),
          caption: 'Hello there.',
        );
        await drain();
        expect(director.current.speaking, isTrue);
        personas.add(ChatPersona.coach);
        await drain();
        // the director holds the profile until the sentence ends: so does the ladder
        expect(director.profile, BodyLanguageProfile.normal);
        expect(ladder.thresholdScale, 1);
        for (int i = 0; i < 100 && director.current.speaking; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await drain();
        }
        expect(director.current.speaking, isFalse);
        final BodyLanguageProfile coach = BodyLanguageProfile.of(
          ChatPersona.coach,
        );
        expect(director.profile, coach);
        expect(ladder.thresholdScale, coach.idle.ladderScale);
      },
    );

    test(
      'an LLM-cued sentence counts toward the sentence index, unswapped',
      () async {
        final StreamController<ChatPersona> personas =
            StreamController<ChatPersona>.broadcast();
        addTearDown(personas.close);
        final AvatarCueService service = AvatarCueService(
          playbackService: playbackService,
          animationService: animationService,
          streamingCues: streamingCuesController.stream,
          director: director,
          personas: personas.stream,
        );
        addTearDown(service.dispose);
        personas.add(ChatPersona.coach);
        await drain();
        expect(director.sentenceIndex, 0);
        playbackService.startAmplitudeAnimation(
          'a.wav',
          <int>[10, 10],
          const Duration(milliseconds: 50),
          caption: 'Go!',
          cues: const <AvatarCue>[AvatarCue.gesture(AvatarGesture.wave)],
        );
        await drain();
        expect(director.sentenceIndex, 1);
        // the LLM's wave plays, unswapped
        expect(director.current.pendingGesture, AvatarGesture.wave);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      },
    );
  });

  group('AvatarCueService presence', () {
    test('composer reports reach the director', () async {
      final ComposerActivityService composer = ComposerActivityService();
      addTearDown(composer.dispose);
      final AvatarCueService service = AvatarCueService(
        playbackService: playbackService,
        animationService: animationService,
        streamingCues: streamingCuesController.stream,
        director: director,
        composer: composer.activity,
      );
      addTearDown(service.dispose);

      composer.report(
        const ComposerActivity(typing: true, caretFraction: 0.8, lastChar: 'a'),
      );
      await drain();
      expect(director.current.gaze, const GazeTarget.caret(0.8));
      expect(director.current.lean, 0.6);

      composer.clear();
      await drain();
      expect(director.current.lean, 0);
    });

    test('the ladder follows the director: stages in, activity out', () async {
      final IdleLadder ladder = IdleLadder(
        now: () => currentTime,
        power: _NoPowerSaver(),
        reduceMotion: () => false,
      );
      addTearDown(ladder.dispose);
      final ComposerActivityService composer = ComposerActivityService();
      addTearDown(composer.dispose);
      final AvatarCueService service = AvatarCueService(
        playbackService: playbackService,
        animationService: animationService,
        streamingCues: streamingCuesController.stream,
        director: director,
        composer: composer.activity,
        idleLadder: ladder,
      );
      addTearDown(service.dispose);

      currentTime = currentTime.add(const Duration(minutes: 11));
      ladder.tick();
      await drain();
      expect(ladder.stage, 3);
      expect(director.current.idleStage, 3);
      expect(director.current.prop, AvatarProp.tablet);

      // a tap on the avatar (the cubit calls this) resets both
      director.onUserActivity();
      await drain();
      expect(ladder.stage, 0);
      expect(director.current.idleStage, 0);
      expect(director.current.prop, AvatarProp.none);

      // typing resets the ladder too
      currentTime = currentTime.add(const Duration(minutes: 3));
      ladder.tick();
      await drain();
      expect(director.current.idleStage, 2);
      composer.report(const ComposerActivity(typing: true, lastChar: 'a'));
      await drain();
      expect(ladder.stage, 0);
      expect(director.current.idleStage, 0);
    });

    test('a composer touch (mic, orb, chip) resets the ladder', () async {
      final IdleLadder ladder = IdleLadder(
        now: () => currentTime,
        power: _NoPowerSaver(),
        reduceMotion: () => false,
      );
      addTearDown(ladder.dispose);
      final ComposerActivityService composer = ComposerActivityService();
      addTearDown(composer.dispose);
      final AvatarCueService service = AvatarCueService(
        playbackService: playbackService,
        animationService: animationService,
        streamingCues: streamingCuesController.stream,
        director: director,
        composer: composer.activity,
        idleLadder: ladder,
      );
      addTearDown(service.dispose);

      currentTime = currentTime.add(const Duration(minutes: 3));
      ladder.tick();
      await drain();
      expect(ladder.stage, 2);

      composer.touch();
      await drain();
      expect(ladder.stage, 0);
      expect(director.current.idleStage, 0);
      // a touch is presence, not typing: no lean, no gaze on the caret
      expect(director.current.lean, 0);
      expect(director.current.gaze, const GazeTarget.user());
    });

    test('speech starting resets a ladder that has the tablet out', () async {
      final IdleLadder ladder = IdleLadder(
        now: () => currentTime,
        power: _NoPowerSaver(),
        reduceMotion: () => false,
      );
      addTearDown(ladder.dispose);
      final AvatarCueService service = AvatarCueService(
        playbackService: playbackService,
        animationService: animationService,
        streamingCues: streamingCuesController.stream,
        director: director,
        idleLadder: ladder,
      );
      addTearDown(service.dispose);

      currentTime = currentTime.add(const Duration(minutes: 11));
      ladder.tick();
      await drain();
      expect(director.current.prop, AvatarProp.tablet);

      playbackService.startAmplitudeAnimation(
        'a.wav',
        <int>[10, 10],
        const Duration(milliseconds: 50),
        caption: 'Hello.',
      );
      await drain();
      expect(director.current.speaking, isTrue);
      expect(director.current.prop, AvatarProp.none);
      expect(director.current.idleStage, 0);
      expect(ladder.stage, 0);
      expect(director.current.gaze, const GazeTarget.user());
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
  });
}
