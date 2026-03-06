import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/features/talking/domain/repositories/talking_repository.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_cubit.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_state.dart';

class MockTalkingRepository extends Mock implements TalkingRepository {}

void main() {
  group('TalkingCubit', () {
    late TalkingCubit cubit;
    late MockTalkingRepository mockRepository;

    setUp(() {
      mockRepository = MockTalkingRepository();
      cubit = TalkingCubit(mockRepository);
    });

    tearDown(() => cubit.close());

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
      test('should emit waiting state then call repository', () async {
        when(
          () => mockRepository.playWaitingSentence('Test sentence'),
        ).thenAnswer((_) async {});

        await cubit.playWaitingSentence('Test sentence');

        expect(cubit.state, isA<WaitingState>());
        expect(cubit.state.shouldShowTalking, isFalse);
        expect(cubit.state.isPlaying, isTrue);
        expect(cubit.state.isTalking, isTrue);
        expect(cubit.state.status, TalkingStatus.success);

        verify(
          () => mockRepository.playWaitingSentence('Test sentence'),
        ).called(1);
      });

      test('should emit error state on repository failure', () async {
        when(
          () => mockRepository.playWaitingSentence(any()),
        ).thenThrow(Exception('TTS failed'));

        await cubit.playWaitingSentence('Test');

        expect(cubit.state, isA<ErrorState>());
        expect(
          cubit.state.maybeWhen(
            error: (String msg, MouthState mouthState) => msg,
            orElse: () => '',
          ),
          contains('TTS failed'),
        );
      });
    });

    group('generateSpeech', () {
      test('should emit generating, then speaking on success', () async {
        when(
          () => mockRepository.generateSpeech('Hello'),
        ).thenAnswer((_) async {});

        final Future<void> speechFuture = cubit.generateSpeech('Hello');

        expect(cubit.state, isA<GeneratingState>());
        expect(cubit.state.shouldShowTalking, isTrue);

        await speechFuture;

        expect(cubit.state, isA<SpeakingState>());
        expect(cubit.state.shouldShowTalking, isTrue);
        expect(cubit.state.isPlaying, isTrue);

        verify(() => mockRepository.generateSpeech('Hello')).called(1);
      });

      test('should emit error state on repository failure', () async {
        when(
          () => mockRepository.generateSpeech('Error test'),
        ).thenThrow(Exception('TTS generation failed'));

        await cubit.generateSpeech('Error test');

        expect(cubit.state, isA<ErrorState>());
        expect(
          cubit.state.maybeWhen(
            error: (String msg, MouthState mouthState) => msg,
            orElse: () => '',
          ),
          contains('TTS generation failed'),
        );
        expect(cubit.state.status, TalkingStatus.error);
      });

      test('should map generating to loading status', () async {
        when(
          () => mockRepository.generateSpeech('Test'),
        ).thenAnswer((_) async {});

        final Future<void> speechFuture = cubit.generateSpeech('Test');

        expect(cubit.state.status, TalkingStatus.loading);

        await speechFuture;
      });
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
      test('should call repository.stop() and emit idle', () async {
        when(() => mockRepository.stop()).thenAnswer((_) async {});

        cubit.setSpeakingState();
        expect(cubit.state, isA<SpeakingState>());

        await cubit.stop();

        verify(() => mockRepository.stop()).called(1);
        expect(cubit.state, isA<IdleState>());
        expect(cubit.state.isPlaying, isFalse);
        expect(cubit.state.shouldShowTalking, isFalse);
      });

      test('should propagate repository errors', () async {
        when(() => mockRepository.stop()).thenThrow(Exception('Stop failed'));

        // stop() doesn't have try/catch, so errors propagate
        expect(() => cubit.stop(), throwsA(isA<Exception>()));
      });
    });

    group('setLoadingStatus (deprecated)', () {
      test('should emit generating when true', () {
        cubit.setLoadingStatus(true);

        expect(cubit.state, isA<GeneratingState>());
        expect(cubit.state.shouldShowTalking, isTrue);
        expect(cubit.state.status, TalkingStatus.loading);
      });

      test('should emit idle when false', () {
        cubit.setSpeakingState();
        expect(cubit.state, isA<SpeakingState>());

        cubit.setLoadingStatus(false);

        expect(cubit.state, isA<IdleState>());
      });
    });

    group('stopTalking (deprecated) - FIXED', () {
      test('FIXED: now properly awaits stop()', () async {
        when(() => mockRepository.stop()).thenAnswer((_) async {});

        cubit.setSpeakingState();
        expect(cubit.state, isA<SpeakingState>());

        // Now properly awaits the stop operation
        await cubit.stopTalking();

        // Stop was called and completed
        verify(() => mockRepository.stop()).called(1);

        // State is now idle (no more race condition!)
        expect(cubit.state, isA<IdleState>());
      });

      test('FIXED: awaits stop but parameters still ignored', () async {
        when(() => mockRepository.stop()).thenAnswer((_) async {});

        // Note: Parameters are still deprecated and ignored
        // But at least the stop operation is now properly awaited
        await cubit.stopTalking(
          removeFile: true,
          soundEffectsEnabled: true,
          updateStatus: false,
        );

        verify(() => mockRepository.stop()).called(1);
        // TODO: Parameters are ignored - could be removed in future refactor
      });
    });

    group('State extensions', () {
      test('shouldShowTalking returns true for generating', () async {
        when(
          () => mockRepository.generateSpeech('Test'),
        ).thenAnswer((_) async {});

        final Future<void> speechFuture = cubit.generateSpeech('Test');
        expect(cubit.state.shouldShowTalking, isTrue);
        await speechFuture;
      });

      test('shouldShowTalking returns true for speaking', () {
        cubit.setSpeakingState();
        expect(cubit.state.shouldShowTalking, isTrue);
      });

      test('shouldShowTalking returns false for idle', () {
        expect(cubit.state.shouldShowTalking, isFalse);
      });

      test('shouldShowTalking returns false for waiting', () async {
        when(
          () => mockRepository.playWaitingSentence('Test'),
        ).thenAnswer((_) async {});

        await cubit.playWaitingSentence('Test');
        expect(cubit.state.shouldShowTalking, isFalse);
      });

      test('isPlaying returns true for waiting', () async {
        when(
          () => mockRepository.playWaitingSentence('Test'),
        ).thenAnswer((_) async {});

        await cubit.playWaitingSentence('Test');
        expect(cubit.state.isPlaying, isTrue);
      });

      test('isPlaying returns true for speaking', () {
        cubit.setSpeakingState();
        expect(cubit.state.isPlaying, isTrue);
      });

      test('isPlaying returns false for idle and generating', () async {
        expect(cubit.state.isPlaying, isFalse);

        when(
          () => mockRepository.generateSpeech('Test'),
        ).thenAnswer((_) async {});

        final Future<void> speechFuture = cubit.generateSpeech('Test');
        expect(cubit.state.isPlaying, isFalse);
        await speechFuture;

        expect(cubit.state.isPlaying, isTrue);
      });

      test('answer returns empty amplitudes for all states', () {
        cubit.setSpeakingState();
        expect(cubit.state.answer.amplitudes, isEmpty);

        cubit.setLoadingStatus(true);
        expect(cubit.state.answer.amplitudes, isEmpty);

        cubit.init();
        expect(cubit.state.answer.amplitudes, isEmpty);
      });
    });

    group('State transitions', () {
      test('idle -> waiting -> idle', () async {
        expect(cubit.state, isA<IdleState>());

        when(
          () => mockRepository.playWaitingSentence('Test'),
        ).thenAnswer((_) async {});

        await cubit.playWaitingSentence('Test');
        expect(cubit.state, isA<WaitingState>());

        when(() => mockRepository.stop()).thenAnswer((_) async {});
        await cubit.stop();
        expect(cubit.state, isA<IdleState>());
      });

      test('idle -> generating -> speaking -> idle', () async {
        expect(cubit.state, isA<IdleState>());

        when(
          () => mockRepository.generateSpeech('Test'),
        ).thenAnswer((_) async {});

        final Future<void> speechFuture = cubit.generateSpeech('Test');
        expect(cubit.state, isA<GeneratingState>());

        await speechFuture;
        expect(cubit.state, isA<SpeakingState>());

        when(() => mockRepository.stop()).thenAnswer((_) async {});
        await cubit.stop();
        expect(cubit.state, isA<IdleState>());
      });

      test('error -> idle after stop', () async {
        when(
          () => mockRepository.generateSpeech('Test'),
        ).thenThrow(Exception('Error'));

        await cubit.generateSpeech('Test');
        expect(cubit.state, isA<ErrorState>());

        when(() => mockRepository.stop()).thenAnswer((_) async {});
        await cubit.stop();
        expect(cubit.state, isA<IdleState>());
      });
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
      test('multiple rapid state changes', () async {
        when(
          () => mockRepository.playWaitingSentence('Test'),
        ).thenAnswer((_) async {});
        when(() => mockRepository.stop()).thenAnswer((_) async {});

        await cubit.playWaitingSentence('Test');
        await cubit.stop();
        cubit.setSpeakingState();
        await cubit.stop();
        cubit.setLoadingStatus(true);
        cubit.setLoadingStatus(false);

        expect(cubit.state, isA<IdleState>());
      });

      test('calling stop when already idle', () async {
        when(() => mockRepository.stop()).thenAnswer((_) async {});

        expect(cubit.state, isA<IdleState>());

        await cubit.stop();

        expect(cubit.state, isA<IdleState>());
        verify(() => mockRepository.stop()).called(1);
      });

      test('generating state does not play audio', () async {
        when(
          () => mockRepository.generateSpeech('Test'),
        ).thenAnswer((_) async {});

        final Future<void> speechFuture = cubit.generateSpeech('Test');

        expect(cubit.state.isPlaying, isFalse);

        await speechFuture;

        expect(cubit.state.isPlaying, isTrue);
      });
    });
  });
}
