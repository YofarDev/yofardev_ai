import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/features/sound/bloc/sound_cubit.dart';
import 'package:yofardev_ai/features/sound/bloc/sound_state.dart';

// Mock SoundService implementation for testing
class MockSoundService implements SoundService {
  bool shouldFail = false;
  String? failureMessage;
  String? lastPlayedSound;

  @override
  Future<void> playSound(String soundName) async {
    lastPlayedSound = soundName;
    if (shouldFail) {
      throw Exception(failureMessage ?? 'Sound not found');
    }
  }
}

void main() {
  late MockSoundService mockSoundService;
  late SoundCubit cubit;

  setUp(() {
    mockSoundService = MockSoundService();
    cubit = SoundCubit(soundService: mockSoundService);
  });

  tearDown(() {
    cubit.close();
  });

  group('SoundCubit', () {
    test('initial state is SoundInitial', () {
      expect(cubit.state, equals(const SoundInitial()));
    });

    test('emits [SoundPlaying, SoundInitial] when playSound succeeds',
        () async {
      // Arrange
      mockSoundService.shouldFail = false;

      // Act
      final states = <SoundState>[];
      final subscription = cubit.stream.listen(states.add);

      // Trigger the action
      await cubit.playSound('test');

      // Give it a moment to emit all states
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(states, [const SoundPlaying('test'), const SoundInitial()]);
      expect(mockSoundService.lastPlayedSound, 'test');

      await subscription.cancel();
    });

    test('emits SoundError when playSound fails', () async {
      // Arrange
      mockSoundService.shouldFail = true;
      mockSoundService.failureMessage = 'Sound not found';

      // Act
      final states = <SoundState>[];
      final subscription = cubit.stream.listen(states.add);

      // Trigger the action
      await cubit.playSound('test');

      // Give it a moment to emit all states
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(states, [const SoundPlaying('test'), const SoundError('Exception: Sound not found')]);
      expect(mockSoundService.lastPlayedSound, 'test');

      await subscription.cancel();
    });

    test('multiple playSound calls work correctly', () async {
      // Arrange
      mockSoundService.shouldFail = false;

      // Act - first call
      final firstStates = <SoundState>[];
      var firstEmitCount = 0;
      final firstSubscription = cubit.stream.listen((state) {
        if (firstEmitCount < 2) {
          firstStates.add(state);
          firstEmitCount++;
        }
      });

      await cubit.playSound('sound1');
      await Future.delayed(const Duration(milliseconds: 100));
      await firstSubscription.cancel();

      // Act - second call
      final secondStates = <SoundState>[];
      var secondEmitCount = 0;
      final secondSubscription = cubit.stream.listen((state) {
        if (secondEmitCount < 2) {
          secondStates.add(state);
          secondEmitCount++;
        }
      });

      await cubit.playSound('sound2');
      await Future.delayed(const Duration(milliseconds: 100));
      await secondSubscription.cancel();

      // Assert
      expect(firstStates, [const SoundPlaying('sound1'), const SoundInitial()]);
      expect(secondStates, [const SoundPlaying('sound2'), const SoundInitial()]);
      expect(mockSoundService.lastPlayedSound, 'sound2');
    });

    test('recovers from error state', () async {
      // Arrange
      mockSoundService.shouldFail = true;
      mockSoundService.failureMessage = 'First error';

      // Act - first call fails
      final firstStates = <SoundState>[];
      var firstEmitCount = 0;
      final firstSubscription = cubit.stream.listen((state) {
        if (firstEmitCount < 2) {
          firstStates.add(state);
          firstEmitCount++;
        }
      });

      await cubit.playSound('sound1');
      await Future.delayed(const Duration(milliseconds: 100));
      await firstSubscription.cancel();

      // Arrange - now succeed
      mockSoundService.shouldFail = false;

      // Act - second call succeeds
      final secondStates = <SoundState>[];
      var secondEmitCount = 0;
      final secondSubscription = cubit.stream.listen((state) {
        if (secondEmitCount < 2) {
          secondStates.add(state);
          secondEmitCount++;
        }
      });

      await cubit.playSound('sound2');
      await Future.delayed(const Duration(milliseconds: 100));
      await secondSubscription.cancel();

      // Assert
      expect(firstStates, [const SoundPlaying('sound1'), const SoundError('Exception: First error')]);
      expect(secondStates, [const SoundPlaying('sound2'), const SoundInitial()]);
      expect(mockSoundService.lastPlayedSound, 'sound2');
    });
  });
}
