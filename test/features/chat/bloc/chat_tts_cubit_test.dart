import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/services/audio/audio_amplitude_service.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/core/services/audio/audio_player_service.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_tts_cubit.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_tts_state.dart';
import 'package:yofardev_ai/features/sound/data/tts_queue_manager.dart';
import 'package:yofardev_ai/features/sound/domain/tts_queue_item.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_cubit.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_state.dart';
import 'package:yofardev_ai/core/models/voice_effect.dart';
import 'dart:async';

class MockTtsQueueManager extends Mock implements TtsQueueManager {
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

class MockTalkingCubit extends Mock implements TalkingCubit {
  final List<TalkingState> states = <TalkingState>[];

  @override
  TalkingState get state =>
      states.isEmpty ? const TalkingState.idle() : states.last;

  @override
  void emit(TalkingState state) => states.add(state);

  void clearStates() => states.clear();
}

void main() {
  setUpAll(() {
    registerFallbackValue('/test/path.wav');
  });

  group('ChatTtsCubit', () {
    late ChatTtsCubit cubit;
    late MockTtsQueueManager mockTtsManager;
    late MockAudioAmplitudeService mockAmplitudeService;
    late MockAudioPlayerService mockPlayerService;
    late MockTalkingCubit mockTalkingCubit;
    late InterruptionService interruptionService;

    setUp(() {
      mockTtsManager = MockTtsQueueManager();
      mockAmplitudeService = MockAudioAmplitudeService();
      mockPlayerService = MockAudioPlayerService();
      mockTalkingCubit = MockTalkingCubit();
      interruptionService = InterruptionService();

      // Setup default mock behaviors
      when(
        () => mockAmplitudeService.extractAmplitudes(any()),
      ).thenAnswer((_) async => <int>[10, 20, 30, 40, 50]);
      when(
        () => mockPlayerService.play(any()),
      ).thenAnswer((_) async => const Duration(milliseconds: 2000));
      when(
        () => mockPlayerService.stop(),
      ).thenAnswer((_) async {}); // Add stub for stop()
      when(() => mockTalkingCubit.stop()).thenAnswer((_) async {});

      cubit = ChatTtsCubit(
        ttsQueueManager: mockTtsManager,
        audioAmplitudeService: mockAmplitudeService,
        audioPlayerService: mockPlayerService,
        interruptionService: interruptionService,
        talkingCubit: mockTalkingCubit,
      );
    });

    tearDown(() {
      cubit.close();
      interruptionService.dispose();
    });

    test('initial state should have default values', () {
      expect(cubit.state.isInitialized, isFalse);
      expect(cubit.state.audioPathsWaitingSentences, isEmpty);
    });

    group('initialize', () {
      test('should set isInitialized to true', () async {
        expect(cubit.state.isInitialized, isFalse);

        await cubit.initialize('en');

        expect(cubit.state.isInitialized, isTrue);
      });

      test('should set isInitialized to true even on error', () async {
        expect(cubit.state.isInitialized, isFalse);

        await cubit.initialize('fr');

        expect(cubit.state.isInitialized, isTrue);
      });
    });

    group('clearAudioPaths', () {
      test('should clear audioPathsWaitingSentences', () {
        cubit.emit(
          cubit.state.copyWith(
            audioPathsWaitingSentences: <Map<String, dynamic>>[
              <String, dynamic>{'audioPath': 'path1', 'amplitudes': <int>[]},
              <String, dynamic>{'audioPath': 'path2', 'amplitudes': <int>[]},
            ],
          ),
        );

        expect(cubit.state.audioPathsWaitingSentences.length, 2);

        cubit.clearAudioPaths();

        expect(cubit.state.audioPathsWaitingSentences, isEmpty);
      });
    });

    group('removeWaitingSentence', () {
      test('should remove sentence by audioPath', () {
        cubit.emit(
          cubit.state.copyWith(
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
        );

        cubit.removeWaitingSentence('path2');

        expect(cubit.state.audioPathsWaitingSentences.length, 2);
        expect(
          cubit.state.audioPathsWaitingSentences.any(
            (Map<String, dynamic> item) => item['audioPath'] == 'path2',
          ),
          isFalse,
        );
        expect(
          cubit.state.audioPathsWaitingSentences.any(
            (Map<String, dynamic> item) => item['audioPath'] == 'path1',
          ),
          isTrue,
        );
      });

      test('should do nothing when audioPath not found', () {
        cubit.emit(
          cubit.state.copyWith(
            audioPathsWaitingSentences: <Map<String, dynamic>>[
              <String, dynamic>{'audioPath': 'path1', 'amplitudes': <int>[]},
            ],
          ),
        );

        final int beforeLength = cubit.state.audioPathsWaitingSentences.length;

        cubit.removeWaitingSentence('nonexistent');

        expect(cubit.state.audioPathsWaitingSentences.length, beforeLength);
      });
    });

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
        cubit.shuffleWaitingSentences();

        expect(cubit.state.audioPathsWaitingSentences, isEmpty);
      });
    });

    group('TTS audio stream handling', () {
      test('should add audio path with amplitudes when stream emits', () async {
        const String testAudioPath = '/path/to/audio.wav';

        // The default stubs from setUp() are already configured
        // when(() => mockAmplitudeService.extractAmplitudes(any())).thenAnswer((_) async => <int>[10, 20, 30, 40, 50]);
        // when(() => mockPlayerService.play(any())).thenAnswer((_) async => const Duration(milliseconds: 2000));

        // Emit audio path from mock manager
        mockTtsManager.emitAudioPath(testAudioPath);

        // Wait for async operations
        await Future<dynamic>.delayed(const Duration(milliseconds: 100));

        // Verify state was updated
        expect(cubit.state.audioPathsWaitingSentences.length, 1);
        expect(
          cubit.state.audioPathsWaitingSentences.first['audioPath'],
          testAudioPath,
        );
        expect(
          cubit.state.audioPathsWaitingSentences.first['amplitudes'],
          <int>[10, 20, 30, 40, 50], // Use the default stub values
        );
      });

      test('should handle errors in amplitude extraction gracefully', () async {
        const String testAudioPath = '/path/to/bad/audio.wav';

        when(
          () => mockAmplitudeService.extractAmplitudes(testAudioPath),
        ).thenThrow(Exception('Audio file not found'));

        // Emit audio path
        mockTtsManager.emitAudioPath(testAudioPath);

        // Wait for async operations
        await Future<dynamic>.delayed(const Duration(milliseconds: 100));

        // Should not crash, state should remain consistent
        expect(cubit.state.audioPathsWaitingSentences, isEmpty);
      });

      test('should play ready audio paths sequentially', () async {
        const String firstAudioPath = '/path/to/audio-1.wav';
        const String secondAudioPath = '/path/to/audio-2.wav';

        mockTtsManager.emitAudioPath(firstAudioPath);
        mockTtsManager.emitAudioPath(secondAudioPath);

        await Future<dynamic>.delayed(const Duration(milliseconds: 80));

        // Second item should wait while first audio is still playing.
        expect(cubit.state.audioPathsWaitingSentences.length, 1);
        expect(
          cubit.state.audioPathsWaitingSentences.first['audioPath'],
          firstAudioPath,
        );

        mockPlayerService.emitPlaybackComplete();
        await Future<dynamic>.delayed(const Duration(milliseconds: 80));

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
          await Future<dynamic>.delayed(const Duration(milliseconds: 80));

          mockPlayerService.emitPlaybackComplete();
          await Future<dynamic>.delayed(const Duration(milliseconds: 80));

          mockTtsManager.emitAudioPath(secondAudioPath);
          await Future<dynamic>.delayed(const Duration(milliseconds: 80));

          verifyInOrder(<dynamic Function()>[
            () => mockPlayerService.play(firstAudioPath),
            () => mockPlayerService.play(secondAudioPath),
          ]);
        },
      );
    });

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
        expect(state.audioPathsWaitingSentences, isEmpty); // Original unchanged
      });
    });
  });
}
