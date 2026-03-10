import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/audio/interruption_service.dart';
import '../../../../core/services/llm/llm_service_interface.dart';
import '../../../../core/services/prompt_datasource.dart';
import '../../../../core/services/stream_processor/sentence_chunk.dart';
import '../../../../core/services/stream_processor/stream_processor_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/llm_config.dart';
import '../../../../core/models/voice_effect.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../../sound/data/tts_queue_manager.dart';
import '../../domain/models/chat.dart';
import '../../domain/models/chat_entry.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/services/chat_entry_service.dart';
import 'chat_streaming_state.dart';
import 'chats_cubit.dart';

/// Cubit responsible for coordinating LLM message streaming
///
/// Handles:
/// - Streaming responses from LLM
/// - Managing streaming state
/// - Function calling integration
/// - TTS enqueueing
class ChatStreamingCubit extends Cubit<ChatStreamingState> {
  ChatStreamingCubit({
    required ChatRepository chatRepository,
    required SettingsRepository settingsRepository,
    required LlmServiceInterface llmService,
    required StreamProcessorService streamProcessor,
    required PromptDatasource promptDatasource,
    required InterruptionService interruptionService,
    required ChatEntryService chatEntryService,
    required ChatsCubit chatsCubit,
    TtsQueueManager? ttsQueueManager,
  }) : _chatRepository = chatRepository,
       _llmService = llmService,
       _streamProcessor = streamProcessor,
       _promptDatasource = promptDatasource,
       _interruptionService = interruptionService,
       _chatEntryService = chatEntryService,
       _ttsQueueManager = ttsQueueManager,
       _chatsCubit = chatsCubit,
       super(ChatStreamingState.initial()) {
    // Listen to interruption stream
    _interruptionSubscription = _interruptionService.interruptionStream.listen((
      _,
    ) {
      _streamInterrupted = true;
      if (state.status == ChatStreamingStatus.streaming ||
          state.status == ChatStreamingStatus.loading ||
          state.status == ChatStreamingStatus.typing) {
        emit(
          state.copyWith(
            status: ChatStreamingStatus.interrupted,
            streamingContent: '',
          ),
        );
      }
    });
  }

  final ChatRepository _chatRepository;
  final LlmServiceInterface _llmService;
  final StreamProcessorService _streamProcessor;
  final PromptDatasource _promptDatasource;
  final InterruptionService _interruptionService;
  final ChatEntryService _chatEntryService;
  final TtsQueueManager? _ttsQueueManager;
  final ChatsCubit _chatsCubit;
  bool _streamInterrupted = false;

  StreamSubscription<void>? _interruptionSubscription;

  /// Streams a response from the LLM for the given prompt
  ///
  /// This method:
  /// 1. Resets interruption state
  /// 2. Creates a user entry
  /// 3. Checks for function calls
  /// 4. Streams the response (or uses function call result)
  /// 5. Updates the chat via callbacks
  /// 6. Enqueues TTS if not text-only
  Future<void> streamResponse(
    String prompt, {
    required bool onlyText,
    String? attachedImage,
    required Avatar avatar,
    required Chat currentChat,
    required String language,
    bool functionCallingEnabled = true,
    void Function(Chat updatedChat)? onChatUpdated,
  }) async {
    // Reset interruption state at start of new conversation
    _interruptionService.reset();
    _streamInterrupted = false;

    emit(
      state.copyWith(
        status: ChatStreamingStatus.streaming,
        streamingContent: '',
        streamingSentenceCount: 0,
      ),
    );

    final String temporaryId = const Uuid().v4();

    final ChatEntry temporaryEntry = ChatEntry(
      id: temporaryId,
      entryType: EntryType.user,
      body: "User : \n'''$prompt'''",
      timestamp: DateTime.now(),
      attachedImage: attachedImage,
    );

    Chat chat = currentChat.copyWith(
      entries: <ChatEntry>[...currentChat.entries, temporaryEntry],
    );
    onChatUpdated?.call(chat);

    final ChatEntry userEntry = await _chatEntryService.createUserEntry(
      prompt: prompt,
      avatar: avatar,
      attachedImage: attachedImage,
    );

    final List<ChatEntry> mutableEntries = List<ChatEntry>.from(chat.entries);
    final int index = mutableEntries.indexWhere(
      (ChatEntry element) => element.id == temporaryId,
    );
    mutableEntries[index] = userEntry;
    chat = chat.copyWith(entries: mutableEntries);
    onChatUpdated?.call(chat);

    final ChatEntry streamingEntry = ChatEntry(
      id: const Uuid().v4(),
      entryType: EntryType.yofardev,
      body: '',
      timestamp: DateTime.now(),
    );

    chat = chat.copyWith(entries: <ChatEntry>[...chat.entries, streamingEntry]);
    onChatUpdated?.call(chat);

    try {
      await _llmService.init();
      final LlmConfig? config = _llmService.getCurrentConfig();
      if (config == null) {
        emit(
          state.copyWith(
            status: ChatStreamingStatus.error,
            errorMessage: 'No LLM configuration selected',
          ),
        );
        return;
      }

      if (functionCallingEnabled) {
        // 1. Check for function calls first
        final Either<Exception, List<ChatEntry>> functionCheckResult =
            await _chatRepository.askYofardevAi(
              chat,
              userEntry.body,
              functionCallingEnabled: true,
            );

        List<ChatEntry> functionEntries = <ChatEntry>[];

        functionCheckResult.fold(
          (Exception error) {
            AppLogger.error(
              'Function calling check failed',
              tag: 'ChatStreamingCubit',
              error: error,
            );
            // Continue with streaming even if function calling fails
          },
          (List<ChatEntry> entries) {
            functionEntries = entries;
            // Add function call entries to chat if any
            if (entries.isNotEmpty) {
              final List<ChatEntry> updatedEntries = <ChatEntry>[
                ...chat.entries,
                ...entries,
              ];
              chat = chat.copyWith(entries: updatedEntries);
              onChatUpdated?.call(chat);
            }
          },
        );

        // 2. Check if we had function calls - if so, the final response is already included
        final bool hadFunctionCalls = functionEntries.any(
          (ChatEntry e) => e.entryType == EntryType.functionCalling,
        );

        if (hadFunctionCalls) {
          // Function calls were made, use the final response from the agent
          final ChatEntry finalResponse = functionEntries.last;
          final List<ChatEntry> finalEntries = List<ChatEntry>.from(
            chat.entries,
          );
          finalEntries[finalEntries.length - 1] = finalResponse;
          chat = chat.copyWith(entries: finalEntries);
          onChatUpdated?.call(chat);

          emit(
            state.copyWith(
              status: ChatStreamingStatus.success,
              streamingContent: '',
            ),
          );
          await _chatRepository.updateChat(id: chat.id, updatedChat: chat);

          // Generate title if needed
          if (_chatsCubit.shouldGenerateTitle(chat)) {
            // Fire and forget - don't await
            _chatsCubit.generateTitle(chat.id, chat);
          }

          return;
        }
      }

      // 3. No function calls - proceed with streaming

      final String systemPrompt = await _promptDatasource.getSystemPrompt();

      final StringBuffer contentBuffer = StringBuffer();
      String? fullJsonResponse;
      int sentenceCount = 0;

      await for (final SentenceChunk sentenceChunk
          in _streamProcessor.processStream(
            _llmService.promptModelStream(
              messages: chat.llmMessages,
              systemPrompt: systemPrompt,
              config: config,
              returnJson: true,
            ),
          )) {
        if (_streamInterrupted || _interruptionService.isInterrupted) {
          break;
        }

        sentenceChunk.when(
          sentence: (String text, int _) {
            if (_streamInterrupted || _interruptionService.isInterrupted) {
              return;
            }

            final String normalizedText = text.trim();
            if (normalizedText.isEmpty) {
              return;
            }

            if (contentBuffer.isNotEmpty) {
              contentBuffer.write(' ');
            }
            contentBuffer.write(normalizedText);
            sentenceCount++;

            final ChatEntry updatedEntry = streamingEntry.copyWith(
              body: contentBuffer.toString(),
            );

            final List<ChatEntry> updatedEntries = List<ChatEntry>.from(
              chat.entries,
            );
            updatedEntries[updatedEntries.length - 1] = updatedEntry;

            chat = chat.copyWith(entries: updatedEntries);
            onChatUpdated?.call(chat);

            emit(
              state.copyWith(
                streamingContent: contentBuffer.toString(),
                streamingSentenceCount: sentenceCount,
              ),
            );

            // Enqueue for TTS if manager is available and not in text-only mode
            if (!onlyText) {
              _ttsQueueManager?.enqueue(
                text: normalizedText,
                language: language,
                voiceEffect: VoiceEffect(pitch: 1.0, speedRate: 1.0),
              );
            }
          },
          metadata: (Map<String, dynamic> json) {
            // Capture the full JSON response
            if (json.containsKey('fullJson')) {
              fullJsonResponse = json['fullJson'] as String?;
            }
          },
          complete: () {
            AppLogger.debug(
              'Stream complete with $sentenceCount sentences',
              tag: 'ChatStreamingCubit',
            );
          },
          error: (String msg) {
            AppLogger.error('Stream error: $msg', tag: 'ChatStreamingCubit');
          },
        );
      }

      if (_streamInterrupted || _interruptionService.isInterrupted) {
        emit(
          state.copyWith(
            status: ChatStreamingStatus.interrupted,
            streamingContent: '',
          ),
        );
        await _chatRepository.updateChat(id: chat.id, updatedChat: chat);
        return;
      }

      // Use the full JSON if available, otherwise fall back to the content buffer
      final ChatEntry finalEntry = streamingEntry.copyWith(
        body: fullJsonResponse ?? contentBuffer.toString(),
      );

      final List<ChatEntry> finalEntries = List<ChatEntry>.from(chat.entries);
      finalEntries[finalEntries.length - 1] = finalEntry;
      chat = chat.copyWith(entries: finalEntries);
      onChatUpdated?.call(chat);

      emit(
        state.copyWith(
          status: ChatStreamingStatus.success,
          streamingContent: '',
        ),
      );

      await _chatRepository.updateChat(id: chat.id, updatedChat: chat);

      if (_chatsCubit.shouldGenerateTitle(chat)) {
        // Fire and forget - don't await
        _chatsCubit.generateTitle(chat.id, chat);
      }

      return;
    } catch (e) {
      AppLogger.error(
        'Error in streaming message',
        tag: 'ChatStreamingCubit',
        error: e,
      );
      emit(
        state.copyWith(
          status: ChatStreamingStatus.error,
          errorMessage: e.toString(),
          streamingContent: '',
        ),
      );
      return;
    }
  }

  @override
  Future<void> close() async {
    await _interruptionSubscription?.cancel();
    return super.close();
  }
}
