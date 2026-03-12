import 'dart:async';

import '../../../core/models/avatar_config.dart';
import '../../features/avatar/domain/models/avatar_animation.dart';

/// Service for orchestrating avatar animations across features.
///
/// This service provides a centralized way to trigger avatar animations
/// without creating cross-feature dependencies.
///
/// The service emits animation events via a stream, which cubits can
/// subscribe to. This eliminates the need for the service to depend on
/// any presentation layer components.
class AvatarAnimationService {
  AvatarAnimationService() {
    // Create a broadcast stream so multiple listeners can subscribe
    _animationController = StreamController<AvatarAnimation>.broadcast();
  }

  late final StreamController<AvatarAnimation> _animationController;

  /// Stream of animation events.
  ///
  /// Cubits should subscribe to this stream to react to animation triggers.
  Stream<AvatarAnimation> get animations => _animationController.stream;

  /// Plays the new chat creation animation sequence.
  ///
  /// Sequence:
  /// 1. Avatar drops down (off-screen)
  /// 2. Config is updated (background changes are handled by _onNewChatEntry)
  /// 3. Avatar rises back up
  ///
  /// Note: Background animations are NOT triggered here because they are
  /// already handled by HomeBlocListeners._onNewChatEntry which checks
  /// if the background actually changed before animating.
  Future<void> playNewChatSequence(String chatId, AvatarConfig config) async {
    // 1. Avatar drops
    _animationController.add(const AvatarAnimation.clothes(true));
    await Future<void>.delayed(Duration(seconds: 0));

    // 2. Update config while avatar is off-screen
    // Background changes are handled separately by _onNewChatEntry
    _animationController.add(AvatarAnimation.updateConfig(chatId, config));
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // 3. Avatar rises
    _animationController.add(const AvatarAnimation.clothes(false));
  }

  /// Dispose of the service and close the stream.
  void dispose() {
    _animationController.close();
  }
}
