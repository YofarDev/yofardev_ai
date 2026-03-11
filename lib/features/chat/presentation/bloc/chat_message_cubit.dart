import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/avatar_config.dart';
import '../../domain/models/chat.dart';
import 'chat_message_state.dart';
import 'chat_streaming_cubit.dart';
import 'chat_streaming_state.dart';

/// Coordinator cubit for chat message operations
///
/// This cubit delegates to specialized cubits:
/// - ChatStreamingCubit: manages LLM streaming
///
/// The coordinator maintains backward compatibility for existing consumers
/// while providing a cleaner separation of concerns.
class ChatMessageCubit extends Cubit<ChatMessageState> {
  ChatMessageCubit({
    required ChatStreamingCubit chatStreamingCubit,
  }) : _chatStreamingCubit = chatStreamingCubit,
       super(ChatMessageState.initial()) {
    // Listen to streaming cubit state changes and emit combined state
    _streamingSubscription = _chatStreamingCubit.stream.listen((_) {
      emit(_buildCombinedState());
    });
  }

  final ChatStreamingCubit _chatStreamingCubit;

  /// Expose child cubits for testing purposes
  ChatStreamingCubit get chatStreamingCubit => _chatStreamingCubit;

  late final StreamSubscription<ChatStreamingState> _streamingSubscription;

  /// Builds the combined state from streaming cubit
  ChatMessageState _buildCombinedState() {
    final ChatStreamingState streamingState = _chatStreamingCubit.state;

    return ChatMessageState(
      status: _mapStreamingStatus(streamingState.status),
      errorMessage: streamingState.errorMessage,
      streamingContent: streamingState.streamingContent,
      streamingSentenceCount: streamingState.streamingSentenceCount,
      audioPathsWaitingSentences: const <Map<String, dynamic>>[],
      initializing: false,
    );
  }

  /// Maps ChatStreamingStatus to ChatMessageStatus for backward compatibility
  ChatMessageStatus _mapStreamingStatus(ChatStreamingStatus status) {
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

  // ===== Streaming State Delegation =====

  /// Get the current streaming state from ChatStreamingCubit
  ChatStreamingState get streamingState => _chatStreamingCubit.state;

  /// Stream of streaming state changes
  Stream<ChatStreamingState> get streamingStream => _chatStreamingCubit.stream;

  // ===== Streaming Methods Delegation =====

  /// Streams a response from the LLM
  Future<void> askYofardev(
    String prompt, {
    required bool onlyText,
    String? attachedImage,
    required Avatar avatar,
    required Chat currentChat,
    required String language,
    bool functionCallingEnabled = true,
    void Function(Chat updatedChat)? onChatUpdated,
  }) => _chatStreamingCubit.streamResponse(
    prompt,
    onlyText: onlyText,
    attachedImage: attachedImage,
    avatar: avatar,
    currentChat: currentChat,
    language: language,
    functionCallingEnabled: functionCallingEnabled,
    onChatUpdated: onChatUpdated,
  );

  @override
  Future<void> close() async {
    await _streamingSubscription.cancel();
    return super.close();
  }
}
