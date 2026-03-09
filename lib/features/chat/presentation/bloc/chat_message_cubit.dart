import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/avatar_config.dart';
import '../../domain/models/chat.dart';
import 'chat_audio_cubit.dart';
import 'chat_audio_state.dart';
import 'chat_message_state.dart';
import 'chat_streaming_cubit.dart';
import 'chat_streaming_state.dart';

/// Coordinator cubit for chat message operations
///
/// This cubit delegates to specialized cubits:
/// - ChatAudioCubit: manages waiting sentences
/// - ChatStreamingCubit: manages LLM streaming
///
/// The coordinator maintains backward compatibility for existing consumers
/// while providing a cleaner separation of concerns.
class ChatMessageCubit extends Cubit<ChatMessageState> {
  ChatMessageCubit({
    required ChatAudioCubit chatAudioCubit,
    required ChatStreamingCubit chatStreamingCubit,
    bool closeChatAudioOnDispose = false,
  }) : _chatAudioCubit = chatAudioCubit,
       _chatStreamingCubit = chatStreamingCubit,
       _closeChatAudioOnDispose = closeChatAudioOnDispose,
       super(ChatMessageState.initial()) {
    // Listen to audio cubit state changes and emit combined state
    _audioSubscription = _chatAudioCubit.stream.listen((_) {
      emit(_buildCombinedState());
    });

    // Listen to streaming cubit state changes and emit combined state
    _streamingSubscription = _chatStreamingCubit.stream.listen((_) {
      emit(_buildCombinedState());
    });
  }

  final ChatAudioCubit _chatAudioCubit;
  final ChatStreamingCubit _chatStreamingCubit;
  final bool _closeChatAudioOnDispose;

  /// Expose child cubits for testing purposes
  ChatAudioCubit get chatAudioCubit => _chatAudioCubit;
  ChatStreamingCubit get chatStreamingCubit => _chatStreamingCubit;

  late final StreamSubscription<ChatAudioState> _audioSubscription;
  late final StreamSubscription<ChatStreamingState> _streamingSubscription;

  /// Builds the combined state from both cubits
  ChatMessageState _buildCombinedState() {
    final ChatAudioState audioState = _chatAudioCubit.state;
    final ChatStreamingState streamingState = _chatStreamingCubit.state;

    return ChatMessageState(
      status: _mapStreamingStatus(streamingState.status),
      errorMessage: streamingState.errorMessage,
      streamingContent: streamingState.streamingContent,
      streamingSentenceCount: streamingState.streamingSentenceCount,
      audioPathsWaitingSentences: audioState.audioPathsWaitingSentences,
      initializing: audioState.initializing,
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

  // ===== Audio State Delegation =====

  /// Get the current audio state from ChatAudioCubit
  ChatAudioState get audioState => _chatAudioCubit.state;

  /// Stream of audio state changes
  Stream<ChatAudioState> get audioStream => _chatAudioCubit.stream;

  // ===== Streaming State Delegation =====

  /// Get the current streaming state from ChatStreamingCubit
  ChatStreamingState get streamingState => _chatStreamingCubit.state;

  /// Stream of streaming state changes
  Stream<ChatStreamingState> get streamingStream => _chatStreamingCubit.stream;

  // ===== Audio Methods Delegation =====

  /// Loads waiting sentences from cache
  Future<void> prepareWaitingSentences(String language) =>
      _chatAudioCubit.prepareWaitingSentences(language);

  /// Shuffles the waiting sentences list
  void shuffleWaitingSentences() => _chatAudioCubit.shuffleWaitingSentences();

  /// Removes a waiting sentence by its audio path
  void removeWaitingSentence(String audioPath) =>
      _chatAudioCubit.removeWaitingSentence(audioPath);

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
    await _audioSubscription.cancel();
    await _streamingSubscription.cancel();
    if (_closeChatAudioOnDispose) {
      await _chatAudioCubit.close();
    }
    return super.close();
  }
}
