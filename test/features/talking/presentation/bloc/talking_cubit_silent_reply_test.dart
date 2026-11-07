import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/chat_status.dart';
import 'package:yofardev_ai/core/models/talking_phase.dart';
import 'package:yofardev_ai/core/models/voice_effect.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/core/services/audio/voice_effects_service.dart';
import 'package:yofardev_ai/features/sound/sound.dart';
import 'package:yofardev_ai/features/talking/data/repositories/talking_repository_impl.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

/// Each synthesis waits for the test: [answer] completes the oldest one with
/// a path, [fail] makes it throw (Supertonic models missing, web).
class _GatedSynthesizer implements TtsSynthesizer {
  final List<Completer<String>> pending = <Completer<String>>[];

  @override
  Future<String> synthesize({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
  }) {
    final Completer<String> call = Completer<String>();
    pending.add(call);
    return call.future;
  }

  void answer(String path) => pending.removeAt(0).complete(path);

  void fail() =>
      pending.removeAt(0).completeError(StateError('TTS models missing'));

  @override
  Future<void> delete(String path) async {}
}

void main() {
  late AppLifecycleService lifecycle;
  late InterruptionService interruption;
  late _GatedSynthesizer synthesizer;
  late TtsQueueService queue;
  late TtsPlaybackService playback;
  late TalkingCubit talking;
  late List<TalkingPhase> phases;

  /// Longer than the talking cooldown.
  const Duration afterCooldown = Duration(milliseconds: 250);

  setUp(() {
    lifecycle = AppLifecycleService();
    interruption = InterruptionService();
    synthesizer = _GatedSynthesizer();
    queue = TtsQueueService(
      ttsSynthesizer: synthesizer,
      interruptionService: interruption,
      voiceEffectsService: VoiceEffectsService(),
    );
    playback = TtsPlaybackService(TalkingRepositoryImpl());
    talking = TalkingCubit(
      TalkingRepositoryImpl(),
      interruption,
      playback,
      lifecycle,
      queue,
    );
    phases = <TalkingPhase>[];
    talking.stream.listen((TalkingState s) => phases.add(s.phase));
  });

  tearDown(() async {
    await talking.close();
    queue.dispose();
    playback.dispose();
    interruption.dispose();
  });

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  Future<void> enqueue(String text) =>
      queue.enqueue(text: text, language: 'en', voiceEffect: VoiceEffect.none);

  Future<void> startReply() async {
    lifecycle.emitStreamingStateChanged(ChatStatus.typing);
    await flush();
    expect(talking.state.phase, TalkingPhase.generating);
  }

  test('a reply whose speech fails to synthesize ends in idle', () async {
    await startReply();
    unawaited(enqueue('Hello there.'));
    lifecycle.emitStreamingStateChanged(ChatStatus.success);
    await Future<void>.delayed(afterCooldown);
    // Still synthesizing: the reply's speech may yet come.
    expect(talking.state.phase, TalkingPhase.generating);

    synthesizer.fail();
    await Future<void>.delayed(afterCooldown);

    expect(talking.state.phase, TalkingPhase.idle);
  });

  test('synthesis that fails before the stream completes ends in idle once '
      'it does', () async {
    await startReply();
    unawaited(enqueue('Hello there.'));
    synthesizer.fail();
    await Future<void>.delayed(afterCooldown);
    // The stream is still going: more sentences may come.
    expect(talking.state.phase, TalkingPhase.generating);

    lifecycle.emitStreamingStateChanged(ChatStatus.success);
    await Future<void>.delayed(afterCooldown);

    expect(talking.state.phase, TalkingPhase.idle);
  });

  test('an empty (or cue-only) reply ends in idle', () async {
    await startReply();
    lifecycle.emitStreamingStateChanged(ChatStatus.success);
    await Future<void>.delayed(afterCooldown);

    expect(talking.state.phase, TalkingPhase.idle);
  });

  test('a spoken reply goes straight from generating to speaking: the audio '
      'between synthesis and playback keeps it from idling', () async {
    await startReply();
    unawaited(enqueue('Hello there.'));
    lifecycle.emitStreamingStateChanged(ChatStatus.success);
    synthesizer.answer('/tmp/hello.wav');
    // Synthesized, not playing yet (amplitudes being extracted).
    await Future<void>.delayed(afterCooldown);
    expect(talking.state.phase, TalkingPhase.generating);

    // Playback starts, as ChatTtsCubit does it.
    playback.startAmplitudeAnimation(
      '/tmp/hello.wav',
      <int>[10, 10, 10],
      const Duration(milliseconds: 30),
      caption: queue.consumeText('/tmp/hello.wav'),
    );
    await Future<void>.delayed(afterCooldown);

    expect(talking.state.phase, TalkingPhase.speaking);
    expect(phases, isNot(contains(TalkingPhase.idle)));
  });

  test('a new reply cancels a pending silent-reply cooldown', () async {
    await startReply();
    lifecycle.emitStreamingStateChanged(ChatStatus.success);
    await flush();
    // The next prompt goes out within the cooldown.
    lifecycle.emitStreamingStateChanged(ChatStatus.typing);
    await Future<void>.delayed(afterCooldown);

    expect(talking.state.phase, TalkingPhase.generating);
  });

  group('a reply that fails mid-stream', () {
    Future<void> startSpeaking() async {
      await startReply();
      unawaited(enqueue('Hello there.'));
      synthesizer.answer('/tmp/hello.wav');
      await flush();
      playback.startAmplitudeAnimation(
        '/tmp/hello.wav',
        List<int>.generate(50, (int i) => i.isEven ? 0 : 20),
        const Duration(seconds: 1),
        caption: queue.consumeText('/tmp/hello.wav'),
      );
      await flush();
      expect(talking.state.phase, TalkingPhase.speaking);
    }

    test(
      'keeps speaking (and the mouth moving) while its audio plays',
      () async {
        await startSpeaking();

        lifecycle.emitStreamingStateChanged(ChatStatus.error);
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(talking.state.phase, TalkingPhase.speaking);
        final List<MouthState> mouths = <MouthState>[];
        final StreamSubscription<TalkingState> sub = talking.stream.listen(
          (TalkingState s) => mouths.add(s.mouthState),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await sub.cancel();
        expect(mouths, isNotEmpty, reason: 'the lip-sync keeps running');

        // The sentence ends as ChatTtsCubit ends it: idle after the cooldown.
        await playback.stop();
        await Future<void>.delayed(afterCooldown);
        expect(talking.state.phase, TalkingPhase.idle);
      },
    );

    test('keeps generating while a sentence is still synthesizing, then '
        'idles if it fails', () async {
      await startReply();
      unawaited(enqueue('Hello there.'));

      lifecycle.emitStreamingStateChanged(ChatStatus.error);
      await Future<void>.delayed(afterCooldown);
      expect(talking.state.phase, TalkingPhase.generating);

      synthesizer.fail();
      await Future<void>.delayed(afterCooldown);
      expect(talking.state.phase, TalkingPhase.idle);
    });

    test('with nothing to say, stops thinking at once', () async {
      await startReply();

      lifecycle.emitStreamingStateChanged(ChatStatus.error);
      await flush();

      expect(talking.state.phase, TalkingPhase.idle);
    });
  });
}
