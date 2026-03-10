import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/models/chat.dart';

part 'chats_state.freezed.dart';

enum ChatsStatus {
  initial,
  loading,
  updating,
  loaded,
  typing,
  success,
  streaming,
  error,
}

@freezed
sealed class ChatsState with _$ChatsState {
  const factory ChatsState({
    @Default(ChatsStatus.initial) ChatsStatus status,
    @Default(<Chat>[]) List<Chat> chatsList,
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
    @Default(<String>{}) Set<String> generatingTitleChatIds,
  }) = _ChatsState;

  factory ChatsState.initial() => const ChatsState(
    currentChat: Chat(),
    openedChat: Chat(),
    status: ChatsStatus.loading,
    streamingContent: '',
    streamingSentenceCount: 0,
    generatingTitleChatIds: <String>{},
  );
}
