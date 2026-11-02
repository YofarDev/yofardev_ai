import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/models/chat.dart';
import '../../../../core/models/chat_status.dart';
import '../../../../core/models/failure.dart';

export '../../../../core/models/chat_status.dart';

part 'chat_state.freezed.dart';

/// Result of a title generation operation
class TitleResult {
  const TitleResult({required this.chatId, required this.title});

  final String chatId;
  final String title;
}

/// Single flat state on purpose: the conversation, its list, streaming and
/// titles are one coherent state machine (see flutter-architecture
/// "File Cohesion"). Do NOT split into micro-cubits.
@freezed
sealed class ChatState with _$ChatState {
  const factory ChatState({
    @Default(ChatStatus.initial) ChatStatus status,
    @Default(<Chat>[]) List<Chat> chatsList,
    required Chat currentChat,
    required Chat openedChat,
    Failure? error,
    @Default(true) bool initializing,
    @Default(true) bool functionCallingEnabled,
    @Default(false) bool chatCreated,
    // Note: Named generatingTitleChatIds to match existing usage across the codebase
    // rather than renaming to generatingChatIds (as per original spec)
    // This field tracks which chats are currently generating titles
    @Default(<String>{}) Set<String> generatingTitleChatIds,

    /// Result of the most recent title generation
    TitleResult? lastGeneratedTitle,

    /// Flag to track if user has manually created a chat during initialization
    /// This prevents getCurrentChat from overwriting user's new chat
    @Default(false) bool userCreatedChatDuringInit,

    /// Name of the tool the reply is running right now (null otherwise),
    /// for the Home stage tool chip.
    String? activeTool,
  }) = _ChatsState;

  factory ChatState.initial() => const ChatState(
    currentChat: Chat(),
    openedChat: Chat(),
    status: ChatStatus.loading,
    generatingTitleChatIds: <String>{},
    lastGeneratedTitle: null,
  );
}
