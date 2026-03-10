import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yofardev_ai/core/services/avatar_animation_service.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_state.dart';

void main() {
  group('AvatarAnimationService', () {
    late AvatarAnimationService service;
    late MockAvatarCubit mockAvatarCubit;

    setUp(() {
      mockAvatarCubit = MockAvatarCubit();
      service = AvatarAnimationService(mockAvatarCubit);
    });

    test(
      'playNewChatSequence calls onClothesAnimationChanged with true',
      () async {
        // Arrange
        const String chatId = 'test-chat-id';
        const AvatarConfig config = AvatarConfig(
          background: AvatarBackgrounds.beach,
        );

        // Act
        final Future<void> future = service.playNewChatSequence(chatId, config);

        // Assert - immediate call
        verify(() => mockAvatarCubit.onClothesAnimationChanged(true)).called(1);

        // Wait for completion
        await future;
      },
    );

    test('playNewChatSequence calls onBackgroundTransitionChanged', () async {
      // Arrange
      const String chatId = 'test-chat-id';
      const AvatarConfig config = AvatarConfig(
        background: AvatarBackgrounds.beach,
      );

      // Act
      await service.playNewChatSequence(chatId, config);

      // Assert
      verify(
        () => mockAvatarCubit.onBackgroundTransitionChanged(
          BackgroundTransition.sliding,
        ),
      ).called(1);
    });

    test(
      'playNewChatSequence calls onClothesAnimationChanged with false at end',
      () async {
        // Arrange
        const String chatId = 'test-chat-id';
        const AvatarConfig config = AvatarConfig(
          background: AvatarBackgrounds.beach,
        );

        // Act
        await service.playNewChatSequence(chatId, config);

        // Assert - final call with false (rising)
        verify(
          () => mockAvatarCubit.onClothesAnimationChanged(false),
        ).called(1);
      },
    );

    test(
      'playNewChatSequence updates avatar config during animation',
      () async {
        // Arrange
        const String chatId = 'test-chat-id';
        const AvatarConfig config = AvatarConfig(
          background: AvatarBackgrounds.beach,
        );

        // Act
        await service.playNewChatSequence(chatId, config);

        // Assert
        verify(
          () => mockAvatarCubit.updateAvatarConfig(chatId, config),
        ).called(1);
      },
    );
  });
}

class MockAvatarCubit extends Mock implements AvatarCubit {}
