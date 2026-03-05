import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_list_state.freezed.dart';

enum ChatListStatus { initial, loading, updating, success, error }

@freezed
sealed class ChatListState with _$ChatListState {
  const factory ChatListState({
    @Default(ChatListStatus.initial) ChatListStatus status,
    @Default(<String>[]) List<String> chatsListIds,
    required String currentChatId,
    required String openedChatId,
    @Default('') String errorMessage,
    @Default(true) bool soundEffectsEnabled,
    @Default('fr') String currentLanguage,
    @Default(true) bool functionCallingEnabled,
    @Default(false) bool chatCreated,
  }) = _ChatListState;

  factory ChatListState.initial() => const ChatListState(
    currentChatId: '',
    openedChatId: '',
    status: ChatListStatus.loading,
  );
}
