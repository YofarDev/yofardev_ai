import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/services/avatar_animation_service.dart';
import 'package:yofardev_ai/features/avatar/domain/models/avatar_animation.dart';

void main() {
  group('AvatarAnimationService', () {
    late AvatarAnimationService service;

    setUp(() {
      service = AvatarAnimationService();
    });

    tearDown(() {
      service.dispose();
    });

    test('animations stream is a broadcast stream', () {
      // Assert
      expect(service.animations, isA<Stream<AvatarAnimation>>());
    });

    test(
      'playNewChatSequence emits clothes animation events in correct order',
      () async {
        // Arrange
        const String chatId = 'test-chat-id';
        const AvatarConfig config = AvatarConfig(
          background: AvatarBackgrounds.beach,
        );

        final List<AvatarAnimation> received = <AvatarAnimation>[];
        final StreamSubscription<AvatarAnimation> sub = service.animations
            .listen(received.add);

        // Act
        await service.playNewChatSequence(chatId, config);

        // Assert - should emit clothes(true) first, then clothes(false) last
        expect(received.first, const AvatarAnimation.clothes(true));
        expect(received.last, const AvatarAnimation.clothes(false));

        await sub.cancel();
      },
    );

    test('playNewChatSequence emits background transition event', () async {
      // Arrange
      const String chatId = 'test-chat-id';
      const AvatarConfig config = AvatarConfig(
        background: AvatarBackgrounds.beach,
      );

      final List<AvatarAnimation> received = <AvatarAnimation>[];
      final StreamSubscription<AvatarAnimation> sub = service.animations.listen(
        received.add,
      );

      // Act
      await service.playNewChatSequence(chatId, config);

      // Assert
      expect(
        received.any((AvatarAnimation e) => e is AvatarAnimationBackground),
        isTrue,
      );

      await sub.cancel();
    });

    test('playNewChatSequence emits updateConfig event', () async {
      // Arrange
      const String chatId = 'test-chat-id';
      const AvatarConfig config = AvatarConfig(
        background: AvatarBackgrounds.beach,
      );

      final List<AvatarAnimation> received = <AvatarAnimation>[];
      final StreamSubscription<AvatarAnimation> sub = service.animations.listen(
        received.add,
      );

      // Act
      await service.playNewChatSequence(chatId, config);

      // Assert
      expect(
        received.any((AvatarAnimation e) => e is AvatarAnimationUpdateConfig),
        isTrue,
      );

      await sub.cancel();
    });
  });
}
