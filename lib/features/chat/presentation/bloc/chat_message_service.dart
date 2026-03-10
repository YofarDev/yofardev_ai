import 'chat_audio_cubit.dart';
import 'chat_audio_state.dart';
import 'chat_message_state.dart';
import 'chat_streaming_cubit.dart';
import 'chat_streaming_state.dart';

/// Service that provides coordination logic for chat message operations.
///
/// This service extracts the coordination logic that was in ChatMessageCubit,
/// specifically state combination and status mapping. It operates as a pure
/// function service that doesn't hold state or manage streams.
///
/// The ChatMessageCubit continues to exist as a thin wrapper that maintains
/// backward compatibility while delegating coordination logic to this service.
class ChatMessageService {
  /// Builds the combined state from both audio and streaming cubits.
  ///
  /// This method combines the state from [ChatAudioCubit] and [ChatStreamingCubit]
  /// into a single [ChatMessageState] for backward compatibility with consumers.
  ///
  /// [audioState] - The current state from ChatAudioCubit
  /// [streamingState] - The current state from ChatStreamingCubit
  ///
  /// Returns a combined [ChatMessageState] with fields from both inputs.
  static ChatMessageState buildCombinedState({
    required ChatAudioState audioState,
    required ChatStreamingState streamingState,
  }) {
    return ChatMessageState(
      status: mapStreamingStatus(streamingState.status),
      errorMessage: streamingState.errorMessage,
      streamingContent: streamingState.streamingContent,
      streamingSentenceCount: streamingState.streamingSentenceCount,
      audioPathsWaitingSentences: audioState.audioPathsWaitingSentences,
      initializing: audioState.initializing,
    );
  }

  /// Maps [ChatStreamingStatus] to [ChatMessageStatus] for backward compatibility.
  ///
  /// This ensures that the unified ChatMessageStatus type can represent
  /// all the states from the streaming cubit.
  ///
  /// [status] - The streaming status to map
  ///
  /// Returns the corresponding [ChatMessageStatus].
  static ChatMessageStatus mapStreamingStatus(ChatStreamingStatus status) {
    return switch (status) {
      ChatStreamingStatus.initial => ChatMessageStatus.initial,
      ChatStreamingStatus.loading => ChatMessageStatus.loading,
      ChatStreamingStatus.typing => ChatMessageStatus.typing,
      ChatStreamingStatus.streaming => ChatMessageStatus.streaming,
      ChatStreamingStatus.success => ChatMessageStatus.success,
      ChatStreamingStatus.error => ChatMessageStatus.error,
      ChatStreamingStatus.interrupted => ChatMessageStatus.interrupted,
    };
  }
}
