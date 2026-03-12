import 'dart:async';

import '../models/avatar_config.dart';
import '../utils/logger.dart';

/// Service for coordinating cross-feature lifecycle events.
///
/// This service handles coordination logic that was previously embedded
/// in home_bloc_listeners widget, reducing tight coupling between cubits.
///
/// Instead of cubits depending on each other, they emit events that
/// this service coordinates through callbacks.
class AppLifecycleService {
  AppLifecycleService({
    required void Function() onNewChatEntry,
    required void Function() onStreamingComplete,
    required void Function() onInterruption,
    required Future<void> Function(AvatarConfig) onUpdateAvatar,
  }) : _onNewChatEntry = onNewChatEntry,
       _onStreamingComplete = onStreamingComplete,
       _onInterruption = onInterruption,
       _onUpdateAvatar = onUpdateAvatar;

  final void Function() _onNewChatEntry;
  final void Function() _onStreamingComplete;
  final void Function() _onInterruption;
  final Future<void> Function(AvatarConfig) _onUpdateAvatar;

  /// Called when a new chat entry is added during streaming.
  ///
  /// Triggers avatar animation for new messages.
  Future<void> onNewChatEntry({
    required String chatId,
    required AvatarConfig? avatarConfig,
  }) async {
    AppLogger.debug('AppLifecycleService: New chat entry', tag: 'AppLifecycle');

    // Trigger avatar animation if config is available
    if (avatarConfig != null) {
      await _onUpdateAvatar(avatarConfig);
    }

    // Notify listeners
    _onNewChatEntry();
  }

  /// Called when TTS streaming completes.
  void onStreamingStateChanged({
    required bool isStreaming,
    required bool isSuccess,
  }) {
    if (!isStreaming && isSuccess) {
      AppLogger.debug(
        'AppLifecycleService: Streaming completed successfully',
        tag: 'AppLifecycle',
      );
      _onStreamingComplete();
    }
  }

  /// Called when an interruption occurs (e.g., user stops generation).
  void onInterruption() {
    AppLogger.debug(
      'AppLifecycleService: Interruption triggered',
      tag: 'AppLifecycle',
    );
    _onInterruption();
  }
}
