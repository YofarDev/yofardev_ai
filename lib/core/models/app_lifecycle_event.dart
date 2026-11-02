import '../models/avatar_config.dart';
import '../models/chat_entry.dart';
import '../models/chat_status.dart';

/// Events emitted by [AppLifecycleService] for cross-feature coordination.
///
/// Cubits subscribe to specific event streams to react to app lifecycle changes.
/// This replaces direct service-to-cubit method calls, maintaining proper dependency direction.
sealed class AppLifecycleEvent {
  const AppLifecycleEvent();
}

/// Emitted when a new chat entry is created.
///
/// [AvatarCubit] subscribes to update avatar based on entry content.
/// [ChatCubit] subscribes to persist avatar configuration.
class NewChatEntryEvent extends AppLifecycleEvent {
  const NewChatEntryEvent(this.payload);
  final NewChatEntryPayload payload;
}

/// Emitted when the current chat changes.
///
/// [TalkingCubit] subscribes to stop talking.
/// [AvatarCubit] subscribes to load new avatar.
class ChatChangedEvent extends AppLifecycleEvent {
  const ChatChangedEvent(this.chatId);
  final String chatId;
}

/// Emitted when chat streaming status changes.
///
/// [TalkingCubit] subscribes to control thinking animation.
class StreamingStateChangedEvent extends AppLifecycleEvent {
  const StreamingStateChangedEvent(this.status);
  final ChatStatus status;
}

/// Payload for new chat entry events.
///
/// Contains the new avatar configuration with animations already determined
/// by the [AppLifecycleService] based on what changed.
class NewChatEntryPayload {
  const NewChatEntryPayload({
    required this.entry,
    required this.chatId,
    required this.newAvatarConfig,
  });

  final ChatEntry entry;
  final String chatId;
  final AvatarConfig newAvatarConfig;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NewChatEntryPayload &&
        other.entry == entry &&
        other.chatId == chatId &&
        other.newAvatarConfig == newAvatarConfig;
  }

  @override
  int get hashCode => Object.hash(entry, chatId, newAvatarConfig);
}

/// Request to change the avatar of the currently open chat.
/// Emitted by AvatarTool; handled by ChatCubit, which owns the chat id.
class AvatarChangeRequested {
  const AvatarChangeRequested({
    required this.newConfig,
    required this.configWithAnimation,
    required this.backgroundOnly,
  });

  /// Config to persist (raw values only, no animation specials).
  final AvatarConfig newConfig;

  /// Config including animation specials (leaveAndComeBack / outOfScreen).
  final AvatarConfig configWithAnimation;

  /// True when only the background changed (selects the cheaper update path).
  final bool backgroundOnly;
}
