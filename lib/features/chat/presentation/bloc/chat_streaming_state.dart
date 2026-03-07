import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_streaming_state.freezed.dart';

enum ChatStreamingStatus {
  initial,
  loading,
  typing,
  streaming,
  success,
  error,
  interrupted,
}

@freezed
sealed class ChatStreamingState with _$ChatStreamingState {
  const factory ChatStreamingState({
    @Default(ChatStreamingStatus.initial) ChatStreamingStatus status,
    @Default('') String errorMessage,
    @Default('') String streamingContent,
    @Default(0) int streamingSentenceCount,
  }) = _ChatStreamingState;

  factory ChatStreamingState.initial() => const ChatStreamingState();
}
