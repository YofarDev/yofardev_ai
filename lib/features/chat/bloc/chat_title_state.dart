import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_title_state.freezed.dart';

/// Result of a title generation operation
class TitleResult {
  const TitleResult({required this.chatId, required this.title});

  final String chatId;
  final String title;
}

@freezed
sealed class ChatTitleState with _$ChatTitleState {
  const factory ChatTitleState({
    @Default(<String>{}) Set<String> generatingChatIds,
    TitleResult? lastGeneratedTitle,
  }) = _ChatTitleState;

  factory ChatTitleState.initial() => const ChatTitleState();
}
