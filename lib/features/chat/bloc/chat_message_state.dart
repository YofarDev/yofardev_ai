import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message_state.freezed.dart';

enum ChatMessageStatus { initial, loading, typing, streaming, success, error }

@freezed
sealed class ChatMessageState with _$ChatMessageState {
  const factory ChatMessageState({
    @Default(ChatMessageStatus.initial) ChatMessageStatus status,
    @Default('') String errorMessage,
    @Default('') String streamingContent,
    @Default(0) int streamingSentenceCount,
    @Default(<String>{}) Set<String> generatingTitleChatIds,
    @Default(<Map<String, dynamic>>[])
    List<Map<String, dynamic>> audioPathsWaitingSentences,
    @Default(true) bool initializing,
  }) = _ChatMessageState;

  factory ChatMessageState.initial() => const ChatMessageState();

  /// Streaming was interrupted by user
  const factory ChatMessageState.interrupted() = _Interrupted;
}
