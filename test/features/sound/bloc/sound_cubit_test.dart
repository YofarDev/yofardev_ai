import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/features/sound/domain/repositories/sound_repository.dart';
import 'package:yofardev_ai/features/sound/presentation/bloc/sound_cubit.dart';
import 'package:yofardev_ai/features/sound/presentation/bloc/sound_state.dart';

// Mock SoundService implementation for testing
class MockSoundRepository implements SoundRepository {
  bool shouldFail = false;
  String? failureMessage;
  String? lastPlayedSound;

  @override
  Future<Result<void>> play(String soundName) async {
    lastPlayedSound = soundName;
    if (shouldFail) {
      return Result<void>.err(
        UnknownFailure(failureMessage ?? 'Sound not found'),
      );
    }
    return Result<void>.ok(null);
  }

  @override
  Future<Result<void>> stop() async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<bool>> get isPlaying async {
    return Result<bool>.ok(false);
  }
}

void main() {
  late MockSoundRepository mockSoundRepository;
  late SoundCubit cubit;

  setUp(() {
    mockSoundRepository = MockSoundRepository();
    cubit = SoundCubit(soundRepository: mockSoundRepository);
  });

  tearDown(() {
    cubit.close();
  });

  group('SoundCubit', () {
    test('initial state is SoundInitial', () {
      expect(cubit.state, equals(const SoundInitial()));
    });

    test(
      'emits [SoundPlaying, SoundInitial] when playSound succeeds',
      () async {
        // Arrange
        mockSoundRepository.shouldFail = false;

        // Act
        final List<SoundState> states = <SoundState>[];
        final StreamSubscription<SoundState> subscription = cubit.stream.listen(
          states.add,
        );

        // Trigger the action
        await cubit.playSound('test');

        // Give it a moment to emit all states
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(states, const <SoundState>[
          SoundPlaying('test'),
          SoundInitial(),
        ]);
        expect(mockSoundRepository.lastPlayedSound, 'test');

        await subscription.cancel();
      },
    );

    test('emits SoundError when playSound fails', () async {
      // Arrange
      mockSoundRepository.shouldFail = true;
      mockSoundRepository.failureMessage = 'Sound not found';

      // Act
      final List<SoundState> states = <SoundState>[];
      final StreamSubscription<SoundState> subscription = cubit.stream.listen(
        states.add,
      );

      // Trigger the action
      await cubit.playSound('test');

      // Give it a moment to emit all states
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(states.length, 3);
      expect(states[0], const SoundPlaying('test'));
      expect(states[1], isA<SoundError>());
      expect((states[1] as SoundError).failure.message, 'Sound not found');
      expect(states[2], const SoundInitial());
      expect(mockSoundRepository.lastPlayedSound, 'test');

      await subscription.cancel();
    });

    test('multiple playSound calls work correctly', () async {
      // Arrange
      mockSoundRepository.shouldFail = false;

      // Act - first call
      final List<SoundState> firstStates = <SoundState>[];
      int firstEmitCount = 0;
      final StreamSubscription<SoundState> firstSubscription = cubit.stream
          .listen((SoundState state) {
            if (firstEmitCount < 2) {
              firstStates.add(state);
              firstEmitCount++;
            }
          });

      await cubit.playSound('sound1');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await firstSubscription.cancel();

      // Act - second call
      final List<SoundState> secondStates = <SoundState>[];
      int secondEmitCount = 0;
      final StreamSubscription<SoundState> secondSubscription = cubit.stream
          .listen((SoundState state) {
            if (secondEmitCount < 2) {
              secondStates.add(state);
              secondEmitCount++;
            }
          });

      await cubit.playSound('sound2');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await secondSubscription.cancel();

      // Assert
      expect(firstStates, const <SoundState>[
        SoundPlaying('sound1'),
        SoundInitial(),
      ]);
      expect(secondStates, const <SoundState>[
        SoundPlaying('sound2'),
        SoundInitial(),
      ]);
      expect(mockSoundRepository.lastPlayedSound, 'sound2');
    });

    test('recovers from error state', () async {
      // Arrange
      mockSoundRepository.shouldFail = true;
      mockSoundRepository.failureMessage = 'First error';

      // Act - first call fails
      final List<SoundState> firstStates = <SoundState>[];
      int firstEmitCount = 0;
      final StreamSubscription<SoundState> firstSubscription = cubit.stream
          .listen((SoundState state) {
            if (firstEmitCount < 2) {
              firstStates.add(state);
              firstEmitCount++;
            }
          });

      await cubit.playSound('sound1');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await firstSubscription.cancel();

      // Arrange - now succeed
      mockSoundRepository.shouldFail = false;

      // Act - second call succeeds
      final List<SoundState> secondStates = <SoundState>[];
      int secondEmitCount = 0;
      final StreamSubscription<SoundState> secondSubscription = cubit.stream
          .listen((SoundState state) {
            if (secondEmitCount < 2) {
              secondStates.add(state);
              secondEmitCount++;
            }
          });

      await cubit.playSound('sound2');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await secondSubscription.cancel();

      // Assert
      expect(firstStates.length, 2);
      expect(firstStates[0], const SoundPlaying('sound1'));
      expect(firstStates[1], isA<SoundError>());
      expect(secondStates, const <SoundState>[
        SoundPlaying('sound2'),
        SoundInitial(),
      ]);
      expect(mockSoundRepository.lastPlayedSound, 'sound2');
    });
  });
}
