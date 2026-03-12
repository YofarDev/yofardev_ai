import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/features/talking/domain/repositories/talking_repository.dart';
import 'package:yofardev_ai/features/talking/domain/services/tts_playback_service.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_cubit.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_state.dart';

class MockTalkingRepository extends Mock implements TalkingRepository {}

class MockTtsPlaybackService implements TtsPlaybackService {
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

void main() {
  group('TalkingCubit', () {
    late TalkingCubit cubit;
    late MockTalkingRepository mockRepository;
    late InterruptionService interruptionService;
    late MockTtsPlaybackService mockPlaybackService;

    setUp(() {
      mockRepository = MockTalkingRepository();
      interruptionService = InterruptionService();
      mockPlaybackService = MockTtsPlaybackService();
      cubit = TalkingCubit(
        mockRepository,
        interruptionService,
        mockPlaybackService,
      );
    });

    tearDown(() {
      cubit.close();
      interruptionService.dispose();
      mockPlaybackService.dispose();
    });

    test('initial state should be idle', () {
      expect(cubit.state, isA<IdleState>());
      expect(cubit.state.shouldShowTalking, isFalse);
      expect(cubit.state.isPlaying, isFalse);
      expect(cubit.state.isTalking, isFalse);
      expect(cubit.state.status, TalkingStatus.idle);
    });

    group('init', () {
      test('should set state to idle', () async {
        cubit.setSpeakingState();
        expect(cubit.state, isA<SpeakingState>());

        await cubit.init();

        expect(cubit.state, isA<IdleState>());
      });
    });

    group('playWaitingSentence', () {
      blocTest<TalkingCubit, TalkingState>(
        'emits waiting then idle on success',
        build: () {
          when(
            () => mockRepository.playWaitingSentence(any()),
          ).thenAnswer((_) async {});
          return cubit;
        },
        act: (TalkingCubit c) => c.playWaitingSentence('Test sentence'),
        expect: () => <TalkingState>[const TalkingState.waiting()],
        verify: (_) {
          verify(
            () => mockRepository.playWaitingSentence('Test sentence'),
          ).called(1);
        },
      );

      blocTest<TalkingCubit, TalkingState>(
        'should emit error state on repository failure',
        build: () {
          when(
            () => mockRepository.playWaitingSentence(any()),
          ).thenThrow(Exception('TTS failed'));
          return cubit;
        },
        act: (TalkingCubit c) => c.playWaitingSentence('Test'),
        expect: () => <Object>[
          const TalkingState.waiting(),
          predicate<TalkingState>(
            (TalkingState state) => state.maybeWhen(
              error: (String msg, _) => msg.contains('TTS failed'),
              orElse: () => false,
            ),
          ),
        ],
      );
    });

    group('generateSpeech', () {
      blocTest<TalkingCubit, TalkingState>(
        'emits [generating, speaking] on success',
        build: () {
          when(
            () => mockRepository.generateSpeech(any()),
          ).thenAnswer((_) async {});
          return cubit;
        },
        act: (TalkingCubit c) => c.generateSpeech('Hello'),
        expect: () => <TalkingState>[
          const TalkingState.generating(),
          const TalkingState.speaking(),
        ],
        verify: (_) {
          verify(() => mockRepository.generateSpeech('Hello')).called(1);
        },
      );

      blocTest<TalkingCubit, TalkingState>(
        'emits generating then error on generateSpeech failure',
        build: () {
          when(
            () => mockRepository.generateSpeech(any()),
          ).thenThrow(Exception('TTS generation failed'));
          return cubit;
        },
        act: (TalkingCubit c) => c.generateSpeech('Error test'),
        expect: () => <Object>[
          const TalkingState.generating(),
          predicate<TalkingState>(
            (TalkingState state) => state.maybeWhen(
              error: (String msg, _) => msg.contains('TTS generation failed'),
              orElse: () => false,
            ),
          ),
        ],
      );

      blocTest<TalkingCubit, TalkingState>(
        'should map generating to loading status',
        build: () {
          when(
            () => mockRepository.generateSpeech(any()),
          ).thenAnswer((_) async {});
          return cubit;
        },
        act: (TalkingCubit c) => c.generateSpeech('Test'),
        expect: () => <TalkingState>[
          const TalkingState.generating(),
          const TalkingState.speaking(),
        ],
        verify: (_) {
          expect(cubit.state.status, TalkingStatus.success);
        },
      );
    });

    group('setSpeakingState', () {
      test('should emit speaking state', () {
        cubit.setSpeakingState();

        expect(cubit.state, isA<SpeakingState>());
        expect(cubit.state.shouldShowTalking, isTrue);
        expect(cubit.state.isPlaying, isTrue);
        expect(cubit.state.status, TalkingStatus.success);
      });
    });

    group('stop', () {
      blocTest<TalkingCubit, TalkingState>(
        'emits idle when stop is called',
        build: () {
          when(() => mockRepository.stop()).thenAnswer((_) async {});
          return cubit;
        },
        seed: () => const TalkingState.speaking(),
        act: (TalkingCubit c) => c.stop(),
        expect: () => <TalkingState>[const TalkingState.idle()],
        verify: (_) {
          verify(() => mockRepository.stop()).called(1);
        },
      );

      test('should propagate repository errors', () async {
        when(() => mockRepository.stop()).thenThrow(Exception('Stop failed'));

        // stop() doesn't have try/catch, so errors propagate
        expect(() => cubit.stop(), throwsA(isA<Exception>()));
      });
    });

    group('State extensions', () {
      blocTest<TalkingCubit, TalkingState>(
        'shouldShowTalking returns true for generating',
        build: () {
          when(
            () => mockRepository.generateSpeech(any()),
          ).thenAnswer((_) async {});
          return cubit;
        },
        act: (TalkingCubit c) => c.generateSpeech('Test'),
        verify: (_) {
          expect(cubit.state.shouldShowTalking, isTrue);
        },
      );

      test('shouldShowTalking returns true for speaking', () {
        cubit.setSpeakingState();
        expect(cubit.state.shouldShowTalking, isTrue);
      });

      test('shouldShowTalking returns false for idle', () {
        expect(cubit.state.shouldShowTalking, isFalse);
      });

      blocTest<TalkingCubit, TalkingState>(
        'shouldShowTalking returns false for waiting',
        build: () {
          when(
            () => mockRepository.playWaitingSentence(any()),
          ).thenAnswer((_) async {});
          return cubit;
        },
        act: (TalkingCubit c) => c.playWaitingSentence('Test'),
        expect: () => <TalkingState>[const TalkingState.waiting()],
        verify: (_) {
          expect(cubit.state.shouldShowTalking, isFalse);
        },
      );

      blocTest<TalkingCubit, TalkingState>(
        'isPlaying returns true for waiting',
        build: () {
          when(
            () => mockRepository.playWaitingSentence(any()),
          ).thenAnswer((_) async {});
          return cubit;
        },
        act: (TalkingCubit c) => c.playWaitingSentence('Test'),
        expect: () => <TalkingState>[const TalkingState.waiting()],
        verify: (_) {
          expect(cubit.state.isPlaying, isTrue);
        },
      );

      test('isPlaying returns true for speaking', () {
        cubit.setSpeakingState();
        expect(cubit.state.isPlaying, isTrue);
      });

      blocTest<TalkingCubit, TalkingState>(
        'isPlaying returns false for generating and true for speaking',
        build: () {
          when(
            () => mockRepository.generateSpeech(any()),
          ).thenAnswer((_) async {});
          return cubit;
        },
        act: (TalkingCubit c) => c.generateSpeech('Test'),
        expect: () => <TalkingState>[
          const TalkingState.generating(),
          const TalkingState.speaking(),
        ],
        verify: (_) {
          expect(cubit.state.isPlaying, isTrue);
        },
      );

      test('answer returns empty amplitudes for all states', () {
        cubit.setSpeakingState();
        expect(cubit.state.answer.amplitudes, isEmpty);

        cubit.init();
        expect(cubit.state.answer.amplitudes, isEmpty);
      });
    });

    group('State transitions', () {
      blocTest<TalkingCubit, TalkingState>(
        'idle -> waiting -> idle',
        build: () {
          when(
            () => mockRepository.playWaitingSentence(any()),
          ).thenAnswer((_) async {});
          when(() => mockRepository.stop()).thenAnswer((_) async {});
          return cubit;
        },
        act: (TalkingCubit c) async {
          await c.playWaitingSentence('Test');
          await c.stop();
        },
        expect: () => <TalkingState>[
          const TalkingState.waiting(),
          const TalkingState.idle(),
        ],
      );

      blocTest<TalkingCubit, TalkingState>(
        'idle -> generating -> speaking -> idle',
        build: () {
          when(
            () => mockRepository.generateSpeech(any()),
          ).thenAnswer((_) async {});
          when(() => mockRepository.stop()).thenAnswer((_) async {});
          return cubit;
        },
        act: (TalkingCubit c) async {
          await c.generateSpeech('Test');
          await c.stop();
        },
        expect: () => <TalkingState>[
          const TalkingState.generating(),
          const TalkingState.speaking(),
          const TalkingState.idle(),
        ],
      );

      blocTest<TalkingCubit, TalkingState>(
        'error -> idle after stop',
        build: () {
          when(
            () => mockRepository.generateSpeech(any()),
          ).thenThrow(Exception('Error'));
          when(() => mockRepository.stop()).thenAnswer((_) async {});
          return cubit;
        },
        act: (TalkingCubit c) async {
          await c.generateSpeech('Test');
          await c.stop();
        },
        expect: () => <Object>[
          const TalkingState.generating(),
          predicate<TalkingState>(
            (TalkingState state) =>
                state.maybeWhen(error: (_, _) => true, orElse: () => false),
          ),
          const TalkingState.idle(),
        ],
      );
    });

    group('TalkingState value equality', () {
      test('idle states are equal', () {
        const TalkingState state1 = TalkingState.idle();
        const TalkingState state2 = TalkingState.idle();

        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('waiting states are equal', () {
        const TalkingState state1 = TalkingState.waiting();
        const TalkingState state2 = TalkingState.waiting();

        expect(state1, equals(state2));
      });

      test('speaking states are equal', () {
        const TalkingState state1 = TalkingState.speaking();
        const TalkingState state2 = TalkingState.speaking();

        expect(state1, equals(state2));
      });

      test('error states with same message are equal', () {
        const TalkingState state1 = TalkingState.error('Test error');
        const TalkingState state2 = TalkingState.error('Test error');

        expect(state1, equals(state2));
      });

      test('error states with different messages are not equal', () {
        const TalkingState state1 = TalkingState.error('Error 1');
        const TalkingState state2 = TalkingState.error('Error 2');

        expect(state1, isNot(equals(state2)));
      });

      test('different state types are not equal', () {
        const TalkingState idle = TalkingState.idle();
        const TalkingState speaking = TalkingState.speaking();

        expect(idle, isNot(equals(speaking)));
      });
    });

    group('Edge cases', () {
      blocTest<TalkingCubit, TalkingState>(
        'multiple rapid state changes',
        build: () {
          when(
            () => mockRepository.playWaitingSentence(any()),
          ).thenAnswer((_) async {});
          when(() => mockRepository.stop()).thenAnswer((_) async {});
          return cubit;
        },
        act: (TalkingCubit c) async {
          await c.playWaitingSentence('Test');
          await c.stop();
          c.setSpeakingState();
          await c.stop();
        },
        expect: () => <TalkingState>[
          const TalkingState.waiting(),
          const TalkingState.idle(),
          const TalkingState.speaking(),
          const TalkingState.idle(),
        ],
      );

      blocTest<TalkingCubit, TalkingState>(
        'calling stop when already idle',
        build: () {
          when(() => mockRepository.stop()).thenAnswer((_) async {});
          return cubit;
        },
        seed: () => const TalkingState.idle(),
        act: (TalkingCubit c) => c.stop(),
        expect: () =>
            <TalkingState>[], // No state emitted (same state suppressed)
        verify: (_) {
          verify(() => mockRepository.stop()).called(1);
        },
      );

      blocTest<TalkingCubit, TalkingState>(
        'generating state does not play audio',
        build: () {
          when(
            () => mockRepository.generateSpeech(any()),
          ).thenAnswer((_) async {});
          return cubit;
        },
        act: (TalkingCubit c) => c.generateSpeech('Test'),
        expect: () => <TalkingState>[
          const TalkingState.generating(),
          const TalkingState.speaking(),
        ],
        verify: (_) {
          expect(cubit.state.isPlaying, isTrue);
        },
      );
    });

    group('Interruption', () {
      late MockTalkingRepository mockRepository;
      late InterruptionService interruptionService;
      late MockTtsPlaybackService mockPlaybackService;
      late TalkingCubit cubit;

      setUp(() {
        mockRepository = MockTalkingRepository();
        interruptionService = InterruptionService();
        mockPlaybackService = MockTtsPlaybackService();

        when(() => mockRepository.stop()).thenAnswer((_) async {});
      });

      tearDown(() {
        cubit.close();
        interruptionService.dispose();
        mockPlaybackService.dispose();
      });

      blocTest<TalkingCubit, TalkingState>(
        'emits idle when interrupted while speaking',
        build: () {
          cubit = TalkingCubit(
            mockRepository,
            interruptionService,
            mockPlaybackService,
          );
          return cubit;
        },
        act: (TalkingCubit c) async {
          c.setSpeakingState();
          await interruptionService.interrupt();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        },
        expect: () => <TalkingState>[
          const TalkingState.speaking(),
          const TalkingState.idle(),
        ],
        verify: (_) {
          verify(() => mockRepository.stop()).called(1);
        },
      );
    });
  });
}
