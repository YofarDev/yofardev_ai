import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/voice_effect.dart';
import 'package:yofardev_ai/core/services/audio/audio_amplitude_service.dart';
import 'package:yofardev_ai/core/services/audio/audio_player_service.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/core/services/audio/tts_queue_service.dart';
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
  Future<void> enqueue({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
    TtsPriority priority = TtsPriority.normal,
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

class MockTtsPlaybackService extends Mock implements TtsPlaybackService {
  final StreamController<PlaybackEvent> _controller =
      StreamController<PlaybackEvent>.broadcast();

  @override
  Stream<PlaybackEvent> get events => _controller.stream;

  @override
  Future<void> stop() async {}

  @override
  void startAmplitudeAnimation(
    String audioPath,
    List<int> amplitudes,
    Duration audioDuration,
  ) {}

  @override
  void cancelAnimation() {}

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
        () => mockPlayerService.play(any()),
      ).thenAnswer((_) async => const Duration(milliseconds: 2000));
      when(() => mockPlayerService.stop()).thenAnswer((_) async {
        return;
      });
      when(() => mockTtsPlaybackService.stop()).thenAnswer((_) async {});

      cubit = ChatTtsCubit(
        ttsQueueManager: mockTtsManager,
        audioAmplitudeService: mockAmplitudeService,
        audioPlayerService: mockPlayerService,
        interruptionService: interruptionService,
        ttsPlaybackService: mockTtsPlaybackService,
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

    // ── initialize ───────────────────────────────────────────

    group('initialize', () {
      blocTest<ChatTtsCubit, ChatTtsState>(
        'sets isInitialized to true',
        build: () => cubit,
        act: (ChatTtsCubit c) => c.initialize('en'),
        expect: () => <Matcher>[
          predicate<ChatTtsState>((ChatTtsState s) => s.isInitialized == true),
        ],
      );

      blocTest<ChatTtsCubit, ChatTtsState>(
        'sets isInitialized to true even on error',
        build: () => cubit,
        act: (ChatTtsCubit c) => c.initialize('fr'),
        expect: () => <Matcher>[
          predicate<ChatTtsState>((ChatTtsState s) => s.isInitialized == true),
        ],
      );
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

    // ── shuffleWaitingSentences ───────────────────────────────

    group('shuffleWaitingSentences', () {
      test('should shuffle audio paths waiting sentences', () {
        final List<Map<String, dynamic>> originalList = <Map<String, dynamic>>[
          <String, dynamic>{
            'audioPath': 'a',
            'amplitudes': <int>[1],
          },
          <String, dynamic>{
            'audioPath': 'b',
            'amplitudes': <int>[2],
          },
          <String, dynamic>{
            'audioPath': 'c',
            'amplitudes': <int>[3],
          },
        ];

        cubit.emit(
          cubit.state.copyWith(audioPathsWaitingSentences: originalList),
        );

        cubit.shuffleWaitingSentences();

        // Same length
        expect(cubit.state.audioPathsWaitingSentences.length, 3);

        // All audioPaths still present
        final List<String> audioPaths = cubit.state.audioPathsWaitingSentences
            .map<String>(
              (Map<String, dynamic> item) => item['audioPath'] as String,
            )
            .toList();
        expect(audioPaths, containsAll(<String>['a', 'b', 'c']));
      });

      test('should handle empty list', () {
        expect(cubit.state.audioPathsWaitingSentences, isEmpty);

        cubit.shuffleWaitingSentences();

        expect(cubit.state.audioPathsWaitingSentences, isEmpty);
      });
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

        expect(cubit.state.audioPathsWaitingSentences.length, 2);
        expect(
          cubit.state.audioPathsWaitingSentences.last['audioPath'],
          secondAudioPath,
        );
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
