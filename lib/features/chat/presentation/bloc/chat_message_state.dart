import 'package:freezed_annotation/freezed_annotation.dart';

import 'chat_streaming_state.dart';

part 'chat_message_state.freezed.dart';

// Re-export the status enum for backward compatibility
typedef ChatMessageStatus = ChatStreamingStatus;

/// Coordinator state for chat message operations
///
/// This state combines the state from ChatAudioCubit and ChatStreamingCubit
/// to maintain backward compatibility with existing consumers.
@freezed
sealed class ChatMessageState with _$ChatMessageState {
  const factory ChatMessageState({
    @Default(ChatMessageStatus.initial) ChatMessageStatus status,
    @Default('') String errorMessage,
    @Default('') String streamingContent,
    @Default(0) int streamingSentenceCount,
    @Default(<Map<String, dynamic>>[])
    List<Map<String, dynamic>> audioPathsWaitingSentences,
    @Default(true) bool initializing,
  }) = _ChatMessageState;

  factory ChatMessageState.initial() => const ChatMessageState();
}
