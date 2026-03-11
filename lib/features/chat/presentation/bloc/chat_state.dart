import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/models/chat.dart';

part 'chat_state.freezed.dart';

/// Result of a title generation operation
class TitleResult {
  const TitleResult({required this.chatId, required this.title});

  final String chatId;
  final String title;
}

enum ChatStatus {
  initial,
  loading,
  updating,
  loaded,
  typing,
  success,
  streaming,
  error,
  interrupted,
  creatingChat,
}

enum ChatsListStatus {
  initial,
  loading,
  success,
  error,
}

@freezed
sealed class ChatState with _$ChatState {
  const factory ChatState({
    @Default(ChatStatus.initial) ChatStatus status,
    @Default(<Chat>[]) List<Chat> chatsList,
    @Default(ChatsListStatus.initial) ChatsListStatus chatsListStatus,
    String? chatsListError,
    required Chat currentChat,
    required Chat openedChat,
    @Default('') String errorMessage,
    @Default(true) bool soundEffectsEnabled,
    @Default('fr') String currentLanguage,
    @Default(<Map<String, dynamic>>[])
    List<Map<String, dynamic>> audioPathsWaitingSentences,
    @Default(true) bool initializing,
    @Default(false) bool functionCallingEnabled,
    @Default(false) bool chatCreated,
    @Default('') String streamingContent,
    @Default(0) int streamingSentenceCount,
    // Note: Named generatingTitleChatIds to match existing usage across the codebase
    // rather than renaming to generatingChatIds (as per original spec)
    // This field tracks which chats are currently generating titles
    @Default(<String>{}) Set<String> generatingTitleChatIds,

    /// Result of the most recent title generation
    TitleResult? lastGeneratedTitle,

    /// Flag to track if user has manually created a chat during initialization
    /// This prevents getCurrentChat from overwriting user's new chat
    @Default(false) bool userCreatedChatDuringInit,
  }) = _ChatsState;

  factory ChatState.initial() => const ChatState(
    currentChat: Chat(),
    openedChat: Chat(),
    status: ChatStatus.loading,
    chatsListStatus: ChatsListStatus.initial,
    chatsListError: null,
    streamingContent: '',
    streamingSentenceCount: 0,
    generatingTitleChatIds: <String>{},
    lastGeneratedTitle: null,
  );
}
