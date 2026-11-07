import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_cue.dart';
import 'package:yofardev_ai/core/models/performance/speech_timeline.dart';
import 'package:yofardev_ai/core/models/performance/viseme.dart';
import 'package:yofardev_ai/core/models/voice_effect.dart';
import 'package:yofardev_ai/core/services/audio/audio_amplitude_service.dart';
import 'package:yofardev_ai/core/services/audio/audio_player_service.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/features/sound/domain/services/tts_queue_service.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_tts_cubit.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_tts_state.dart';
import 'package:yofardev_ai/features/sound/domain/tts_queue_item.dart';
import 'package:yofardev_ai/features/talking/domain/services/tts_playback_service.dart';

// ──────────────────────────────────────────────────────────────
// Mocks
// ──────────────────────────────────────────────────────────────

class MockTtsQueueService extends Mock implements TtsQueueService {
  final StreamController<String> _audioController =
      StreamController<String>.broadcast();

  @override
  Stream<String> get audioStream => _audioController.stream;

  void emitAudioPath(String audioPath) => _audioController.add(audioPath);

  @override
  bool get isProcessing => false;

  @override
  List<TtsQueueItem> get queue => <TtsQueueItem>[];

  bool get hasItems => false;

  bool get isPlaying => false;

  @override
  Future<void> deleteAudio(String audioPath) =>
      super.noSuchMethod(Invocation.method(#deleteAudio, <String>[audioPath]))
          as Future<void>;

  /// Stubbable; unstubbed it answers like the real queue when no voice
  /// effect wrote a copy: the played path itself.
  @override
  String peekAnalysisPath(String audioPath) =>
      super.noSuchMethod(
            Invocation.method(#peekAnalysisPath, <String>[audioPath]),
          )
          as String? ??
      audioPath;

  @override
  Future<void> enqueue({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
    TtsPriority priority = TtsPriority.normal,
    List<AvatarCue> cues = const <AvatarCue>[],
  }) async {}

  @override
  void clear() {}

  @override
  void dispose() {
    _audioController.close();
  }

  @override
  void setPaused(bool paused) {}
}

class MockAudioAmplitudeService extends Mock implements AudioAmplitudeService {}

class MockAudioPlayerService extends Mock implements AudioPlayerService {
  final StreamController<void> _playbackController =
      StreamController<void>.broadcast();

  @override
  Stream<void> get onPlaybackComplete => _playbackController.stream;

  void emitPlaybackComplete() => _playbackController.add(null);

  @override
  void dispose() {
    _playbackController.close();
  }
}

class MockInterruptionService extends Mock implements InterruptionService {}

class MockTtsPlaybackService extends Mock implements TtsPlaybackService {
  final StreamController<PlaybackEvent> _controller =
      StreamController<PlaybackEvent>.broadcast();

  @override
  Stream<PlaybackEvent> get events => _controller.stream;

  @override
  void startAmplitudeAnimation(
    String audioPath,
    List<int> amplitudes,
    Duration audioDuration, {
    List<AvatarCue> cues = const <AvatarCue>[],
    String? caption,
    SpeechTimeline? timeline,
  }) {
    captions.add(caption);
    timelines.add(timeline);
  }

  /// Captions passed to [startAmplitudeAnimation], in call order.
  final List<String?> captions = <String?>[];

  /// Speech timelines passed to [startAmplitudeAnimation], in call order.
  final List<SpeechTimeline?> timelines = <SpeechTimeline?>[];

  /// Late timelines handed to [replaceTimeline], as (audio path, timeline).
  final List<(String, SpeechTimeline)> replaced = <(String, SpeechTimeline)>[];

  @override
  bool replaceTimeline(String audioPath, SpeechTimeline timeline) {
    replaced.add((audioPath, timeline));
    return true;
  }

  /// Order of the stop-related calls received (see the interruption test).
  final List<String> calls = <String>[];

  @override
  void cancelAnimation() {
    calls.add('cancelAnimation');
  }

  @override
  void dispose() {
    _controller.close();
  }
}

// ──────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue('/test/path.wav');
  });

  group('ChatTtsCubit', () {
    late ChatTtsCubit cubit;
    late MockTtsQueueService mockTtsManager;
    late MockAudioAmplitudeService mockAmplitudeService;
    late MockAudioPlayerService mockPlayerService;
    late MockTtsPlaybackService mockTtsPlaybackService;
    late InterruptionService interruptionService;

    setUp(() {
      mockTtsManager = MockTtsQueueService();
      mockAmplitudeService = MockAudioAmplitudeService();
      mockPlayerService = MockAudioPlayerService();
      mockTtsPlaybackService = MockTtsPlaybackService();
      interruptionService = InterruptionService();

      when(
        () => mockAmplitudeService.extractAmplitudes(any()),
      ).thenAnswer((_) async => <int>[10, 20, 30, 40, 50]);
      when(
        () => mockAmplitudeService.analyzeSpeech(
          any(),
          text: any(named: 'text'),
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockTtsManager.deleteAudio(any()),
      ).thenAnswer((Invocation _) async {});
      when(
        () => mockPlayerService.play(any()),
      ).thenAnswer((_) async => const Duration(milliseconds: 2000));
      when(() => mockPlayerService.stop()).thenAnswer((_) async {
        return;
      });
      when(
        () => mockPlayerService.preload(any()),
      ).thenAnswer((Invocation _) async {});
      when(() => mockTtsPlaybackService.stop()).thenAnswer((_) async {});
      when(() => mockTtsPlaybackService.interrupt()).thenAnswer((_) async {});
      when(
        () => mockTtsManager.cueOnlyStream,
      ).thenAnswer((_) => const Stream<List<AvatarCue>>.empty());
      when(
        () => mockTtsManager.consumeCues(any()),
      ).thenReturn(const <AvatarCue>[]);

      cubit = ChatTtsCubit(
        ttsQueueManager: mockTtsManager,
        audioAmplitudeService: mockAmplitudeService,
        audioPlayerService: mockPlayerService,
        interruptionService: interruptionService,
        ttsPlaybackService: mockTtsPlaybackService,
        speechPreroll: Duration.zero,
      );
    });

    tearDown(() {
      cubit.close();
      interruptionService.dispose();
      mockTtsPlaybackService.dispose();
    });

    // ── State tests ──────────────────────────────────────────

    test('initial state should have default values', () {
      expect(cubit.state.isInitialized, isFalse);
      expect(cubit.state.audioPathsWaitingSentences, isEmpty);
    });

    // ── clearAudioPaths ──────────────────────────────────────

    group('clearAudioPaths', () {
      blocTest<ChatTtsCubit, ChatTtsState>(
        'clears audioPathsWaitingSentences',
        build: () => cubit,
        seed: () => const ChatTtsState(
          audioPathsWaitingSentences: <Map<String, dynamic>>[
            <String, dynamic>{'audioPath': 'path1', 'amplitudes': <int>[]},
          ],
        ),
        act: (ChatTtsCubit c) => c.clearAudioPaths(),
        expect: () => <ChatTtsState>[
          const ChatTtsState(
            audioPathsWaitingSentences: <Map<String, dynamic>>[],
          ),
        ],
      );
    });

    // ── removeWaitingSentence ─────────────────────────────────

    group('removeWaitingSentence', () {
      blocTest<ChatTtsCubit, ChatTtsState>(
        'removes sentence by audioPath',
        build: () => cubit,
        seed: () => const ChatTtsState(
          audioPathsWaitingSentences: <Map<String, dynamic>>[
            <String, dynamic>{
              'audioPath': 'path1',
              'amplitudes': <int>[1, 2, 3],
            },
            <String, dynamic>{
              'audioPath': 'path2',
              'amplitudes': <int>[4, 5, 6],
            },
            <String, dynamic>{
              'audioPath': 'path3',
              'amplitudes': <int>[7, 8, 9],
            },
          ],
        ),
        act: (ChatTtsCubit c) => c.removeWaitingSentence('path2'),
        expect: () => <Matcher>[
          predicate<ChatTtsState>((ChatTtsState s) {
            return s.audioPathsWaitingSentences.length == 2 &&
                !s.audioPathsWaitingSentences.any(
                  (Map<String, dynamic> item) => item['audioPath'] == 'path2',
                ) &&
                s.audioPathsWaitingSentences.any(
                  (Map<String, dynamic> item) => item['audioPath'] == 'path1',
                );
          }),
        ],
      );

      blocTest<ChatTtsCubit, ChatTtsState>(
        'does nothing when audioPath not found',
        build: () => cubit,
        seed: () => const ChatTtsState(
          audioPathsWaitingSentences: <Map<String, dynamic>>[
            <String, dynamic>{'audioPath': 'path1', 'amplitudes': <int>[]},
          ],
        ),
        act: (ChatTtsCubit c) => c.removeWaitingSentence('nonexistent'),
        expect: () => <dynamic>[],
      );
    });

    // ── TTS audio stream handling ────────────────────────────

    group('TTS audio stream handling', () {
      test('should add audio path with amplitudes when stream emits', () async {
        const String testAudioPath = '/path/to/audio.wav';

        mockTtsManager.emitAudioPath(testAudioPath);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(cubit.state.audioPathsWaitingSentences.length, 1);
        expect(
          cubit.state.audioPathsWaitingSentences.first['audioPath'],
          testAudioPath,
        );
        expect(
          cubit.state.audioPathsWaitingSentences.first['amplitudes'],
          <int>[10, 20, 30, 40, 50],
        );
      });

      test('should handle errors in amplitude extraction gracefully', () async {
        const String testAudioPath = '/path/to/bad/audio.wav';

        when(
          () => mockAmplitudeService.extractAmplitudes(testAudioPath),
        ).thenThrow(Exception('Audio file not found'));

        mockTtsManager.emitAudioPath(testAudioPath);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(cubit.state.audioPathsWaitingSentences, isEmpty);
        // The caption text parked for this sentence is dropped.
        verify(() => mockTtsManager.consumeText(testAudioPath)).called(1);
      });

      test('should play ready audio paths sequentially', () async {
        const String firstAudioPath = '/path/to/audio-1.wav';
        const String secondAudioPath = '/path/to/audio-2.wav';

        mockTtsManager.emitAudioPath(firstAudioPath);
        mockTtsManager.emitAudioPath(secondAudioPath);
        await Future<void>.delayed(const Duration(milliseconds: 80));

        // Second item waits while first is playing.
        expect(cubit.state.audioPathsWaitingSentences.length, 1);
        expect(
          cubit.state.audioPathsWaitingSentences.first['audioPath'],
          firstAudioPath,
        );

        mockPlayerService.emitPlaybackComplete();
        await Future<void>.delayed(const Duration(milliseconds: 80));

        // The first sentence's entry is freed once played; the second is
        // now the one being played.
        expect(cubit.state.audioPathsWaitingSentences.length, 1);
        expect(
          cubit.state.audioPathsWaitingSentences.last['audioPath'],
          secondAudioPath,
        );
      });

      test('preloads the next file while the current one plays', () async {
        const String firstAudioPath = '/tmp/tts/a.wav';
        const String secondAudioPath = '/tmp/tts/b.wav';

        when(
          () => mockPlayerService.preload(any()),
        ).thenAnswer((Invocation _) async {});

        mockTtsManager.emitAudioPath(firstAudioPath);
        await Future<void>.delayed(const Duration(milliseconds: 80));
        mockTtsManager.emitAudioPath(secondAudioPath);
        await Future<void>.delayed(const Duration(milliseconds: 80));

        verify(() => mockPlayerService.preload(secondAudioPath)).called(1);
      });

      test(
        'should restart playback when a new audio path arrives after the queue goes idle',
        () async {
          const String firstAudioPath = '/path/to/audio-1.wav';
          const String secondAudioPath = '/path/to/audio-2.wav';

          mockTtsManager.emitAudioPath(firstAudioPath);
          await Future<void>.delayed(const Duration(milliseconds: 80));

          mockPlayerService.emitPlaybackComplete();
          await Future<void>.delayed(const Duration(milliseconds: 80));

          mockTtsManager.emitAudioPath(secondAudioPath);
          await Future<void>.delayed(const Duration(milliseconds: 80));

          verifyInOrder(<dynamic Function()>[
            () => mockPlayerService.play(firstAudioPath),
            () => mockPlayerService.play(secondAudioPath),
          ]);
        },
      );
    });

    // ── Played sentence freeing (memory leak) ────────────────

    test(
      'removes the played sentence from audioPathsWaitingSentences',
      () async {
        final MockTtsQueueService queue = MockTtsQueueService();
        final MockAudioAmplitudeService amplitudeService =
            MockAudioAmplitudeService();
        final MockAudioPlayerService player = MockAudioPlayerService();
        final MockTtsPlaybackService playback = MockTtsPlaybackService();
        final MockInterruptionService interruption = MockInterruptionService();
        when(
          () => interruption.interruptionStream,
        ).thenAnswer((_) => const Stream<void>.empty());

        when(
          () => amplitudeService.extractAmplitudes(any()),
        ).thenAnswer((Invocation _) async => <int>[10, 20, 30]);
        when(
          () => player.play(any()),
        ).thenAnswer((Invocation _) async => const Duration(seconds: 1));
        when(() => queue.consumeCues(any())).thenReturn(const <AvatarCue>[]);
        when(() => playback.stop()).thenAnswer((Invocation _) async {});
        when(() => playback.interrupt()).thenAnswer((Invocation _) async {});
        when(
          () => queue.deleteAudio(any()),
        ).thenAnswer((Invocation _) async {});
        when(
          () => queue.cueOnlyStream,
        ).thenAnswer((_) => const Stream<List<AvatarCue>>.empty());

        final ChatTtsCubit cubit = ChatTtsCubit(
          ttsQueueManager: queue,
          audioAmplitudeService: amplitudeService,
          audioPlayerService: player,
          interruptionService: interruption,
          ttsPlaybackService: playback,
          speechPreroll: Duration.zero,
        );

        queue.emitAudioPath('/tmp/tts/1.wav');
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.audioPathsWaitingSentences.length, 1);

        player.emitPlaybackComplete();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.audioPathsWaitingSentences, isEmpty);

        await cubit.close();
        queue.dispose();
        player.dispose();
        playback.dispose();
      },
    );

    test('deletes the played WAV via the TTS queue service', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('tts');
      final File wav = File('${tmp.path}/1000.wav');
      await wav.writeAsBytes(<int>[1, 2, 3]);

      final MockTtsQueueService queue = MockTtsQueueService();
      final MockAudioAmplitudeService amplitudeService =
          MockAudioAmplitudeService();
      final MockAudioPlayerService player = MockAudioPlayerService();
      final MockTtsPlaybackService playback = MockTtsPlaybackService();
      final MockInterruptionService interruption = MockInterruptionService();
      when(
        () => interruption.interruptionStream,
      ).thenAnswer((_) => const Stream<void>.empty());
      when(
        () => queue.cueOnlyStream,
      ).thenAnswer((_) => const Stream<List<AvatarCue>>.empty());

      when(
        () => amplitudeService.extractAmplitudes(any()),
      ).thenAnswer((Invocation _) async => <int>[10]);
      when(
        () => player.play(any()),
      ).thenAnswer((Invocation _) async => const Duration(seconds: 1));
      when(() => queue.consumeCues(any())).thenReturn(const <AvatarCue>[]);
      when(() => playback.stop()).thenAnswer((Invocation _) async {});
      when(() => playback.interrupt()).thenAnswer((Invocation _) async {});
      when(() => queue.deleteAudio(any())).thenAnswer((Invocation _) async {});

      final ChatTtsCubit cubit = ChatTtsCubit(
        ttsQueueManager: queue,
        audioAmplitudeService: amplitudeService,
        audioPlayerService: player,
        interruptionService: interruption,
        ttsPlaybackService: playback,
        speechPreroll: Duration.zero,
      );

      queue.emitAudioPath(wav.path);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      player.emitPlaybackComplete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(() => queue.deleteAudio(wav.path)).called(1);
      await cubit.close();
      queue.dispose();
      player.dispose();
      playback.dispose();
      await tmp.delete(recursive: true);
    });

    test('passes the sentence text as the caption when it plays', () async {
      final MockTtsQueueService queue = MockTtsQueueService();
      final MockAudioAmplitudeService amplitudeService =
          MockAudioAmplitudeService();
      final MockAudioPlayerService player = MockAudioPlayerService();
      final MockTtsPlaybackService playback = MockTtsPlaybackService();
      final MockInterruptionService interruption = MockInterruptionService();
      when(
        () => interruption.interruptionStream,
      ).thenAnswer((_) => const Stream<void>.empty());
      when(
        () => queue.cueOnlyStream,
      ).thenAnswer((_) => const Stream<List<AvatarCue>>.empty());
      when(
        () => amplitudeService.extractAmplitudes(any()),
      ).thenAnswer((Invocation _) async => <int>[10]);
      when(
        () => player.play(any()),
      ).thenAnswer((Invocation _) async => const Duration(seconds: 1));
      when(() => queue.consumeCues(any())).thenReturn(const <AvatarCue>[]);
      when(() => queue.consumeText('/tmp/tts/1.wav')).thenReturn('Hi there.');
      when(() => playback.stop()).thenAnswer((Invocation _) async {});
      when(() => playback.interrupt()).thenAnswer((Invocation _) async {});
      when(() => queue.deleteAudio(any())).thenAnswer((Invocation _) async {});

      final ChatTtsCubit cubit = ChatTtsCubit(
        ttsQueueManager: queue,
        audioAmplitudeService: amplitudeService,
        audioPlayerService: player,
        interruptionService: interruption,
        ttsPlaybackService: playback,
        speechPreroll: Duration.zero,
      );

      queue.emitAudioPath('/tmp/tts/1.wav');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(playback.captions, <String?>['Hi there.']);

      await cubit.close();
      queue.dispose();
      player.dispose();
      playback.dispose();
    });

    // ── Speech timeline prefetch ─────────────────────────────

    group('speech timeline', () {
      const String path = '/tmp/tts/speech.wav';
      const SpeechTimeline analysed = SpeechTimeline(
        visemes: <VisemeSpan>[
          VisemeSpan(
            viseme: Viseme.pp,
            start: Duration.zero,
            end: Duration(milliseconds: 60),
          ),
        ],
        duration: Duration(milliseconds: 60),
      );

      test(
        'analyses the parked sentence text on arrival and passes the result',
        () async {
          when(() => mockTtsManager.peekText(path)).thenReturn('Big boat.');
          when(() => mockTtsManager.peekLanguage(path)).thenReturn('fr');
          when(
            () => mockAmplitudeService.analyzeSpeech(
              path,
              text: any(named: 'text'),
              language: any(named: 'language'),
            ),
          ).thenAnswer((_) async => analysed);

          mockTtsManager.emitAudioPath(path);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          verify(
            () => mockAmplitudeService.analyzeSpeech(
              path,
              text: 'Big boat.',
              language: 'fr',
            ),
          ).called(1);
          expect(mockTtsPlaybackService.timelines, <SpeechTimeline?>[analysed]);
        },
      );

      test('an unknown language is analysed as English', () async {
        when(() => mockTtsManager.peekText(path)).thenReturn('Big boat.');
        when(() => mockTtsManager.peekLanguage(path)).thenReturn(null);

        mockTtsManager.emitAudioPath(path);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        verify(
          () => mockAmplitudeService.analyzeSpeech(
            path,
            text: 'Big boat.',
            language: 'en',
          ),
        ).called(1);
      });

      test('a voice-effect sentence is analysed from its dry WAV, '
          'its amplitudes and playback from the processed file', () async {
        const String dry = '/tmp/tts/speech_dry.wav';
        when(() => mockTtsManager.peekAnalysisPath(path)).thenReturn(dry);
        when(() => mockTtsManager.peekText(path)).thenReturn('Big boat.');
        when(() => mockTtsManager.peekLanguage(path)).thenReturn('en');
        when(
          () => mockAmplitudeService.analyzeSpeech(
            dry,
            text: any(named: 'text'),
            language: any(named: 'language'),
          ),
        ).thenAnswer((_) async => analysed);

        mockTtsManager.emitAudioPath(path);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        verify(
          () => mockAmplitudeService.analyzeSpeech(
            dry,
            text: 'Big boat.',
            language: 'en',
          ),
        ).called(1);
        verifyNever(
          () => mockAmplitudeService.analyzeSpeech(
            path,
            text: any(named: 'text'),
            language: any(named: 'language'),
          ),
        );
        verify(() => mockAmplitudeService.extractAmplitudes(path)).called(1);
        verifyNever(() => mockAmplitudeService.extractAmplitudes(dry));
        verify(() => mockPlayerService.play(path)).called(1);
        // The analysis still goes to the sentence played from [path].
        expect(mockTtsPlaybackService.timelines, <SpeechTimeline?>[analysed]);
      });

      test(
        'a slow analysis delays playback at most ${ChatTtsCubit.timelineWait.inMilliseconds} ms, then plays with no timeline',
        () async {
          final Completer<SpeechTimeline?> never = Completer<SpeechTimeline?>();
          when(
            () => mockAmplitudeService.analyzeSpeech(
              path,
              text: any(named: 'text'),
              language: any(named: 'language'),
            ),
          ).thenAnswer((_) => never.future);

          final Stopwatch watch = Stopwatch()..start();
          mockTtsManager.emitAudioPath(path);
          while (mockTtsPlaybackService.timelines.isEmpty &&
              watch.elapsed < const Duration(seconds: 2)) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          watch.stop();

          verify(() => mockPlayerService.play(path)).called(1);
          expect(mockTtsPlaybackService.timelines, <SpeechTimeline?>[null]);
          // The wait plus a generous scheduling margin.
          expect(
            watch.elapsed,
            lessThan(
              ChatTtsCubit.timelineWait + const Duration(milliseconds: 150),
            ),
          );
        },
      );

      test(
        'the analysis may use the breath before speaking: one ready during the pre-roll is used',
        () async {
          // M6: the in-app capture showed the first sentence (no previous
          // sentence to overlap with) always fell back to amplitudes,
          // because the wait's clock started with the 350 ms breath.
          await cubit.close();
          cubit = ChatTtsCubit(
            ttsQueueManager: mockTtsManager,
            audioAmplitudeService: mockAmplitudeService,
            audioPlayerService: mockPlayerService,
            interruptionService: interruptionService,
            ttsPlaybackService: mockTtsPlaybackService,
            speechPreroll: const Duration(milliseconds: 300),
          );
          when(
            () => mockAmplitudeService.analyzeSpeech(
              path,
              text: any(named: 'text'),
              language: any(named: 'language'),
            ),
          ).thenAnswer((_) async {
            // past timelineWait alone, inside breath + timelineWait
            await Future<void>.delayed(const Duration(milliseconds: 330));
            return analysed;
          });

          mockTtsManager.emitAudioPath(path);
          final Stopwatch watch = Stopwatch()..start();
          while (mockTtsPlaybackService.timelines.isEmpty &&
              watch.elapsed < const Duration(seconds: 2)) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          expect(mockTtsPlaybackService.timelines, <SpeechTimeline?>[analysed]);
        },
      );

      group('an analysis landing after the audio started', () {
        // The wait budget is 150 ms with no pre-roll: 300 ms is late.
        void lateAnalysis(Duration after) {
          when(
            () => mockAmplitudeService.analyzeSpeech(
              path,
              text: any(named: 'text'),
              language: any(named: 'language'),
            ),
          ).thenAnswer((_) async {
            await Future<void>.delayed(after);
            return analysed;
          });
        }

        Future<void> untilPlaying() async {
          final Stopwatch watch = Stopwatch()..start();
          while (mockTtsPlaybackService.timelines.isEmpty &&
              watch.elapsed < const Duration(seconds: 2)) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        }

        test(
          'is handed to the playback service for the sentence that plays',
          () async {
            lateAnalysis(const Duration(milliseconds: 300));

            mockTtsManager.emitAudioPath(path);
            await untilPlaying();
            // the sentence starts on the amplitude fallback...
            expect(mockTtsPlaybackService.timelines, <SpeechTimeline?>[null]);
            expect(mockTtsPlaybackService.replaced, isEmpty);

            // ...and takes the analysis over once it lands
            await Future<void>.delayed(const Duration(milliseconds: 250));
            expect(mockTtsPlaybackService.replaced, <(String, SpeechTimeline)>[
              (path, analysed),
            ]);
            expect(
              mockTtsPlaybackService.timelines,
              hasLength(1),
              reason: 'the sentence is not started a second time',
            );
          },
        );

        test('is dropped when the sentence already ended', () async {
          lateAnalysis(const Duration(milliseconds: 300));

          mockTtsManager.emitAudioPath(path);
          await untilPlaying();
          mockPlayerService.emitPlaybackComplete();
          await Future<void>.delayed(const Duration(milliseconds: 350));

          expect(mockTtsPlaybackService.replaced, isEmpty);
        });

        test('is dropped when the speech was interrupted', () async {
          lateAnalysis(const Duration(milliseconds: 300));

          mockTtsManager.emitAudioPath(path);
          await untilPlaying();
          await interruptionService.interrupt();
          await Future<void>.delayed(const Duration(milliseconds: 350));

          expect(mockTtsPlaybackService.replaced, isEmpty);
        });

        test(
          'an on-time analysis is the only timeline: no replacement',
          () async {
            lateAnalysis(const Duration(milliseconds: 20));

            mockTtsManager.emitAudioPath(path);
            await untilPlaying();
            await Future<void>.delayed(const Duration(milliseconds: 350));

            expect(mockTtsPlaybackService.timelines, <SpeechTimeline?>[
              analysed,
            ]);
            expect(mockTtsPlaybackService.replaced, isEmpty);
          },
        );

        test('a failed late analysis changes nothing', () async {
          when(
            () => mockAmplitudeService.analyzeSpeech(
              path,
              text: any(named: 'text'),
              language: any(named: 'language'),
            ),
          ).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            throw StateError('boom');
          });

          mockTtsManager.emitAudioPath(path);
          await untilPlaying();
          await Future<void>.delayed(const Duration(milliseconds: 350));

          expect(mockTtsPlaybackService.replaced, isEmpty);
        });
      });

      test('a failed analysis plays with no timeline', () async {
        when(
          () => mockAmplitudeService.analyzeSpeech(
            path,
            text: any(named: 'text'),
            language: any(named: 'language'),
          ),
        ).thenThrow(StateError('boom'));

        mockTtsManager.emitAudioPath(path);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        verify(() => mockPlayerService.play(path)).called(1);
        expect(mockTtsPlaybackService.timelines, <SpeechTimeline?>[null]);
      });
    });

    test(
      'an interruption stops the mouth animation before the player',
      () async {
        when(() => mockPlayerService.stop()).thenAnswer((_) async {
          mockTtsPlaybackService.calls.add('player.stop');
        });
        when(() => mockTtsPlaybackService.interrupt()).thenAnswer((_) async {
          mockTtsPlaybackService.calls.add('playback.interrupt');
        });

        await interruptionService.interrupt();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(mockTtsPlaybackService.calls, <String>[
          'cancelAnimation',
          'player.stop',
          'playback.interrupt',
        ]);
      },
    );

    test('clears waiting sentences on interruption', () async {
      final MockTtsQueueService queue = MockTtsQueueService();
      final MockAudioAmplitudeService amplitudeService =
          MockAudioAmplitudeService();
      final MockAudioPlayerService player = MockAudioPlayerService();
      final MockTtsPlaybackService playback = MockTtsPlaybackService();
      final StreamController<void> interruptions =
          StreamController<void>.broadcast();
      final MockInterruptionService interruption = MockInterruptionService();
      when(
        () => interruption.interruptionStream,
      ).thenAnswer((Invocation _) => interruptions.stream);
      when(() => player.stop()).thenAnswer((Invocation _) async {});
      when(() => playback.stop()).thenAnswer((Invocation _) async {});
      when(() => playback.interrupt()).thenAnswer((Invocation _) async {});
      when(() => queue.deleteAudio(any())).thenAnswer((Invocation _) async {});
      when(
        () => queue.cueOnlyStream,
      ).thenAnswer((_) => const Stream<List<AvatarCue>>.empty());

      final ChatTtsCubit cubit = ChatTtsCubit(
        ttsQueueManager: queue,
        audioAmplitudeService: amplitudeService,
        audioPlayerService: player,
        interruptionService: interruption,
        ttsPlaybackService: playback,
        speechPreroll: Duration.zero,
      );

      // Seed one state entry directly through the playback path.
      when(
        () => amplitudeService.extractAmplitudes(any()),
      ).thenAnswer((Invocation _) async => <int>[5]);
      when(
        () => player.play(any()),
      ).thenAnswer((Invocation _) async => const Duration(seconds: 1));
      when(() => queue.consumeCues(any())).thenReturn(const <AvatarCue>[]);
      queue.emitAudioPath('/tmp/tts/2.wav');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.audioPathsWaitingSentences.length, 1);

      interruptions.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.audioPathsWaitingSentences, isEmpty);

      await cubit.close();
      queue.dispose();
      player.dispose();
      playback.dispose();
      await interruptions.close();
    });

    group('speech pre-roll', () {
      late MockTtsQueueService queue;
      late MockAudioAmplitudeService amplitudeService;
      late MockAudioPlayerService player;
      late MockTtsPlaybackService playback;
      late StreamController<void> interruptions;
      late ChatTtsCubit cubit;

      setUp(() {
        queue = MockTtsQueueService();
        amplitudeService = MockAudioAmplitudeService();
        player = MockAudioPlayerService();
        playback = MockTtsPlaybackService();
        interruptions = StreamController<void>.broadcast();
        final MockInterruptionService interruption = MockInterruptionService();
        when(
          () => interruption.interruptionStream,
        ).thenAnswer((Invocation _) => interruptions.stream);
        when(() => player.stop()).thenAnswer((Invocation _) async {});
        when(() => playback.stop()).thenAnswer((Invocation _) async {});
        when(() => playback.interrupt()).thenAnswer((Invocation _) async {});
        when(
          () => queue.deleteAudio(any()),
        ).thenAnswer((Invocation _) async {});
        when(
          () => queue.cueOnlyStream,
        ).thenAnswer((_) => const Stream<List<AvatarCue>>.empty());
        when(
          () => amplitudeService.extractAmplitudes(any()),
        ).thenAnswer((Invocation _) async => <int>[5]);
        when(
          () => player.play(any()),
        ).thenAnswer((Invocation _) async => const Duration(seconds: 1));
        when(() => queue.consumeCues(any())).thenReturn(const <AvatarCue>[]);
        cubit = ChatTtsCubit(
          ttsQueueManager: queue,
          audioAmplitudeService: amplitudeService,
          audioPlayerService: player,
          interruptionService: interruption,
          ttsPlaybackService: playback,
          speechPreroll: const Duration(milliseconds: 60),
        );
      });

      tearDown(() async {
        await cubit.close();
        queue.dispose();
        player.dispose();
        playback.dispose();
        await interruptions.close();
      });

      test(
        'announces the sentence, then plays it after the pre-roll',
        () async {
          queue.emitAudioPath('/tmp/tts/3.wav');
          await Future<void>.delayed(const Duration(milliseconds: 20));
          verify(
            () => playback.announceSpeech(const Duration(milliseconds: 60)),
          ).called(1);
          verifyNever(() => player.play(any()));
          await Future<void>.delayed(const Duration(milliseconds: 80));
          verify(() => player.play('/tmp/tts/3.wav')).called(1);
        },
      );

      test('the default pre-roll is 350 ms', () {
        expect(
          ChatTtsCubit.defaultSpeechPreroll,
          const Duration(milliseconds: 350),
        );
      });

      test('announces the onset viseme once the analysis is ready', () async {
        when(
          () => amplitudeService.analyzeSpeech(
            any(),
            text: any(named: 'text'),
            language: any(named: 'language'),
          ),
        ).thenAnswer(
          (Invocation _) async => const SpeechTimeline(
            visemes: <VisemeSpan>[
              VisemeSpan(
                viseme: Viseme.sil,
                start: Duration.zero,
                end: Duration(milliseconds: 40),
              ),
              VisemeSpan(
                viseme: Viseme.pp,
                start: Duration(milliseconds: 40),
                end: Duration(milliseconds: 100),
              ),
            ],
            duration: Duration(milliseconds: 100),
          ),
        );
        // the analysis is done before the sentence plays (the usual case:
        // it ran during the previous sentence)
        when(() => amplitudeService.extractAmplitudes(any())).thenAnswer((
          Invocation _,
        ) async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return <int>[5];
        });
        queue.emitAudioPath('/tmp/tts/5.wav');
        await Future<void>.delayed(const Duration(milliseconds: 30));
        verify(
          () => playback.announceSpeech(
            const Duration(milliseconds: 60),
            onset: Viseme.pp,
          ),
        ).called(1);
      });

      test('an interrupt during the pre-roll drops the sentence', () async {
        queue.emitAudioPath('/tmp/tts/4.wav');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        interruptions.add(null);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        verifyNever(() => player.play(any()));
        verify(() => queue.deleteAudio('/tmp/tts/4.wav')).called(1);
      });
    });

    // ── ChatTtsState ─────────────────────────────────────────

    group('ChatTtsState', () {
      test('should create with default values', () {
        const ChatTtsState state = ChatTtsState();

        expect(state.audioPathsWaitingSentences, isEmpty);
        expect(state.isInitialized, isFalse);
      });

      test('should copy with new values', () {
        const ChatTtsState state = ChatTtsState();

        final ChatTtsState newState = state.copyWith(
          isInitialized: true,
          audioPathsWaitingSentences: <Map<String, dynamic>>[
            <String, dynamic>{'audioPath': 'test'},
          ],
        );

        expect(newState.isInitialized, isTrue);
        expect(newState.audioPathsWaitingSentences.length, 1);
        expect(newState.audioPathsWaitingSentences.first['audioPath'], 'test');
      });

      test('should support value equality', () {
        const ChatTtsState state1 = ChatTtsState(
          isInitialized: true,
          audioPathsWaitingSentences: <Map<String, dynamic>>[
            <String, dynamic>{'audioPath': 'test'},
          ],
        );

        const ChatTtsState state2 = ChatTtsState(
          isInitialized: true,
          audioPathsWaitingSentences: <Map<String, dynamic>>[
            <String, dynamic>{'audioPath': 'test'},
          ],
        );

        expect(state1, equals(state2));
      });

      test('should handle list mutations correctly', () {
        const ChatTtsState state = ChatTtsState();

        final List<Map<String, dynamic>> newList = <Map<String, dynamic>>[
          <String, dynamic>{'audioPath': 'a'},
          <String, dynamic>{'audioPath': 'b'},
        ];

        final ChatTtsState newState = state.copyWith(
          audioPathsWaitingSentences: newList,
        );

        expect(newState.audioPathsWaitingSentences.length, 2);
        expect(state.audioPathsWaitingSentences, isEmpty);
      });
    });
  });
}
