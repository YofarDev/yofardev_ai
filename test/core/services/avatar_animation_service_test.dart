import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/avatar/domain/services/avatar_animation_service.dart';
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
        const AvatarConfig config = AvatarConfig(background: AvatarScene.beach);

        final List<AvatarAnimation> received = <AvatarAnimation>[];
        final StreamSubscription<AvatarAnimation> sub = service.animations
            .listen(received.add);

        // Act
        await service.playNewChatSequence(chatId, config);
        // Broadcast events are delivered asynchronously; let the last one land.
        await Future<void>.delayed(Duration.zero);

        // Assert - should emit clothes(true) first, then clothes(false) last
        expect(received.first, const AvatarAnimation.clothes(true));
        expect(received.last, const AvatarAnimation.clothes(false));

        await sub.cancel();
      },
    );

    test('playNewChatSequence does not emit a background transition', () async {
      // Arrange
      const String chatId = 'test-chat-id';
      const AvatarConfig config = AvatarConfig(background: AvatarScene.beach);

      final List<AvatarAnimation> received = <AvatarAnimation>[];
      final StreamSubscription<AvatarAnimation> sub = service.animations.listen(
        received.add,
      );

      // Act
      await service.playNewChatSequence(chatId, config);
      await Future<void>.delayed(Duration.zero);

      // Assert - background changes are derived by AppLifecycleService from
      // the reply's avatar config, never by the new-chat sequence.
      expect(
        received.any((AvatarAnimation e) => e is AvatarAnimationBackground),
        isFalse,
      );

      await sub.cancel();
    });

    test('playNewChatSequence emits updateConfig event', () async {
      // Arrange
      const String chatId = 'test-chat-id';
      const AvatarConfig config = AvatarConfig(background: AvatarScene.beach);

      final List<AvatarAnimation> received = <AvatarAnimation>[];
      final StreamSubscription<AvatarAnimation> sub = service.animations.listen(
        received.add,
      );

      // Act
      await service.playNewChatSequence(chatId, config);
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(
        received.any((AvatarAnimation e) => e is AvatarAnimationUpdateConfig),
        isTrue,
      );

      await sub.cancel();
    });
  });
}
