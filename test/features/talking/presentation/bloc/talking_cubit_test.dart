import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/features/talking/domain/repositories/talking_repository.dart';
import 'package:yofardev_ai/features/talking/domain/services/tts_playback_service.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_cubit.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_state.dart';

class MockTalkingRepository extends Mock implements TalkingRepository {}

class MockTtsPlaybackService implements TtsPlaybackService {
  final TalkingRepository repository;

  MockTtsPlaybackService(this.repository);

  @override
  void setPlaybackStateCallback(void Function(bool p1)? callback) {}

  @override
  void startAmplitudeAnimation(
    String audioPath,
    List<int> amplitudes,
    Duration audioDuration, {
    required void Function(int mouthState) onMouthStateUpdate,
    required void Function() onComplete,
  }) {}

  @override
  Future<void> stop() async {}

  @override
  void cancelAnimation() {}

  @override
  void notifySpeakingStarted() {}

  @override
  void notifySpeakingStopped() {}

  @override
  void dispose() {}
}

void main() {
  group('TalkingCubit', () {
    late TalkingCubit cubit;
    late MockTalkingRepository mockRepository;
    late MockTtsPlaybackService mockPlaybackService;
    late InterruptionService interruptionService;

    setUp(() {
      mockRepository = MockTalkingRepository();
      mockPlaybackService = MockTtsPlaybackService(mockRepository);
      interruptionService = InterruptionService();
      cubit = TalkingCubit(
        mockRepository,
        interruptionService,
        mockPlaybackService,
      );
    });

    tearDown(() {
      cubit.close();
      interruptionService.dispose();
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
      test('should emit waiting state then call repository', () async {
        when(
          () => mockRepository.playWaitingSentence('Test sentence'),
        ).thenAnswer((_) async {
          return;
        });

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
        when(() => mockRepository.generateSpeech('Hello')).thenAnswer((
          _,
        ) async {
          return;
        });

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
        when(() => mockRepository.generateSpeech('Test')).thenAnswer((_) async {
          return;
        });

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
        when(() => mockRepository.stop()).thenAnswer((_) async {
          return;
        });

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

    group('State extensions', () {
      test('shouldShowTalking returns true for generating', () async {
        when(() => mockRepository.generateSpeech('Test')).thenAnswer((_) async {
          return;
        });

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
        when(() => mockRepository.playWaitingSentence('Test')).thenAnswer((
          _,
        ) async {
          return;
        });

        await cubit.playWaitingSentence('Test');
        expect(cubit.state.shouldShowTalking, isFalse);
      });

      test('isPlaying returns true for waiting', () async {
        when(() => mockRepository.playWaitingSentence('Test')).thenAnswer((
          _,
        ) async {
          return;
        });

        await cubit.playWaitingSentence('Test');
        expect(cubit.state.isPlaying, isTrue);
      });

      test('isPlaying returns true for speaking', () {
        cubit.setSpeakingState();
        expect(cubit.state.isPlaying, isTrue);
      });

      test('isPlaying returns false for idle and generating', () async {
        expect(cubit.state.isPlaying, isFalse);

        when(() => mockRepository.generateSpeech('Test')).thenAnswer((_) async {
          return;
        });

        final Future<void> speechFuture = cubit.generateSpeech('Test');
        expect(cubit.state.isPlaying, isFalse);
        await speechFuture;

        expect(cubit.state.isPlaying, isTrue);
      });

      test('answer returns empty amplitudes for all states', () {
        cubit.setSpeakingState();
        expect(cubit.state.answer.amplitudes, isEmpty);

        cubit.init();
        expect(cubit.state.answer.amplitudes, isEmpty);
      });
    });

    group('State transitions', () {
      test('idle -> waiting -> idle', () async {
        expect(cubit.state, isA<IdleState>());

        when(() => mockRepository.playWaitingSentence('Test')).thenAnswer((
          _,
        ) async {
          return;
        });

        await cubit.playWaitingSentence('Test');
        expect(cubit.state, isA<WaitingState>());

        when(() => mockRepository.stop()).thenAnswer((_) async {
          return;
        });
        await cubit.stop();
        expect(cubit.state, isA<IdleState>());
      });

      test('idle -> generating -> speaking -> idle', () async {
        expect(cubit.state, isA<IdleState>());

        when(() => mockRepository.generateSpeech('Test')).thenAnswer((_) async {
          return;
        });

        final Future<void> speechFuture = cubit.generateSpeech('Test');
        expect(cubit.state, isA<GeneratingState>());

        await speechFuture;
        expect(cubit.state, isA<SpeakingState>());

        when(() => mockRepository.stop()).thenAnswer((_) async {
          return;
        });
        await cubit.stop();
        expect(cubit.state, isA<IdleState>());
      });

      test('error -> idle after stop', () async {
        when(
          () => mockRepository.generateSpeech('Test'),
        ).thenThrow(Exception('Error'));

        await cubit.generateSpeech('Test');
        expect(cubit.state, isA<ErrorState>());

        when(() => mockRepository.stop()).thenAnswer((_) async {
          return;
        });
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
        when(() => mockRepository.playWaitingSentence('Test')).thenAnswer((
          _,
        ) async {
          return;
        });
        when(() => mockRepository.stop()).thenAnswer((_) async {
          return;
        });

        await cubit.playWaitingSentence('Test');
        await cubit.stop();
        cubit.setSpeakingState();
        await cubit.stop();

        expect(cubit.state, isA<IdleState>());
      });

      test('calling stop when already idle', () async {
        when(() => mockRepository.stop()).thenAnswer((_) async {
          return;
        });

        expect(cubit.state, isA<IdleState>());

        await cubit.stop();

        expect(cubit.state, isA<IdleState>());
        verify(() => mockRepository.stop()).called(1);
      });

      test('generating state does not play audio', () async {
        when(() => mockRepository.generateSpeech('Test')).thenAnswer((_) async {
          return;
        });

        final Future<void> speechFuture = cubit.generateSpeech('Test');

        expect(cubit.state.isPlaying, isFalse);

        await speechFuture;

        expect(cubit.state.isPlaying, isTrue);
      });
    });

    group('Interruption', () {
      late MockTalkingRepository mockRepository;
      late MockTtsPlaybackService mockPlaybackService;
      late InterruptionService interruptionService;
      late TalkingCubit cubit;

      setUp(() {
        mockRepository = MockTalkingRepository();
        mockPlaybackService = MockTtsPlaybackService(mockRepository);
        interruptionService = InterruptionService();

        when(() => mockRepository.stop()).thenAnswer((_) async {
          return;
        });
      });

      tearDown(() {
        cubit.close();
        interruptionService.dispose();
      });

      test('should stop animation and TTS when interrupted', () async {
        // Arrange
        cubit = TalkingCubit(
          mockRepository,
          interruptionService,
          mockPlaybackService,
        );

        // Start speaking
        cubit.setSpeakingState();
        expect(cubit.state, isA<SpeakingState>());

        // Act
        await interruptionService.interrupt();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(cubit.state, isA<IdleState>());
        verify(() => mockRepository.stop()).called(1);
      });
    });
  });
}
