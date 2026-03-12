import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../models/avatar_config.dart';
import '../../models/chat.dart';
import '../../models/chat_entry.dart';
import '../../models/llm_config.dart';
import '../../models/voice_effect.dart';
import '../audio/interruption_service.dart';
import '../audio/tts_queue_service.dart';
import '../llm/llm_service_interface.dart';
import '../prompt_datasource.dart';
import '../stream_processor/sentence_chunk.dart';
import '../stream_processor/stream_processor_service.dart';
import '../../utils/logger.dart';
import '../../../features/chat/domain/repositories/chat_repository.dart';
import '../../../features/chat/domain/services/chat_entry_service.dart';

/// Service for handling LLM response streaming with function calling support.
///
/// This service coordinates the complex flow of:
/// 1. Creating user entries
/// 2. Checking for function calls
/// 3. Streaming LLM responses
/// 4. Managing TTS enqueuing
/// 5. Handling interruptions
class ChatStreamingService {
  ChatStreamingService({
    required ChatRepository chatRepository,
    required LlmServiceInterface llmService,
    required StreamProcessorService streamProcessor,
    required PromptDatasource promptDatasource,
    required InterruptionService interruptionService,
    required ChatEntryService chatEntryService,
    TtsQueueService? ttsQueueManager,
  }) : _chatRepository = chatRepository,
       _llmService = llmService,
       _streamProcessor = streamProcessor,
       _promptDatasource = promptDatasource,
       _interruptionService = interruptionService,
       _chatEntryService = chatEntryService,
       _ttsQueueManager = ttsQueueManager;

  final ChatRepository _chatRepository;
  final LlmServiceInterface _llmService;
  final StreamProcessorService _streamProcessor;
  final PromptDatasource _promptDatasource;
  final InterruptionService _interruptionService;
  final ChatEntryService _chatEntryService;
  final TtsQueueService? _ttsQueueManager;

  bool _streamInterrupted = false;

  /// Streams a response from the LLM for the given prompt.
  ///
  /// This method:
  /// 1. Resets interruption state
  /// 2. Creates a user entry
  /// 3. Checks for function calls
  /// 4. Streams the response (or uses function call result)
  /// 5. Updates the chat via callbacks
  /// 6. Enqueues TTS if not text-only
  Future<void> streamResponse({
    required String prompt,
    required bool onlyText,
    String? attachedImage,
    required Avatar avatar,
    required Chat currentChat,
    required String language,
    bool functionCallingEnabled = true,
    required void Function(Chat updatedChat) onChatUpdated,
    required void Function(String content, int sentenceCount) onStreamingUpdate,
    required void Function(Chat finalChat) onStreamComplete,
    required void Function(String error) onError,
  }) async {
    // Reset interruption state at start of new conversation
    _interruptionService.reset();
    _streamInterrupted = false;

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
    onChatUpdated(chat);

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
    onChatUpdated(chat);

    final ChatEntry streamingEntry = ChatEntry(
      id: const Uuid().v4(),
      entryType: EntryType.yofardev,
      body: '',
      timestamp: DateTime.now(),
    );

    chat = chat.copyWith(entries: <ChatEntry>[...chat.entries, streamingEntry]);
    // Don't call onChatUpdated here - the streaming entry has an empty body
    // It will be updated with actual content and then onChatUpdated will be called

    try {
      await _llmService.init();
      final LlmConfig? config = _llmService.getCurrentConfig();
      if (config == null) {
        onError('No LLM configuration selected');
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
              tag: 'ChatStreamingService',
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
              onChatUpdated(chat);
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
          onChatUpdated(chat);

          final ChatEntry lastEntry = chat.entries.last;
          AppLogger.debug(
            'Emitting state after function calls: entries.length=${chat.entries.length}, lastEntry.type=${lastEntry.entryType}, lastEntry.body="${lastEntry.body.length > 100 ? lastEntry.body.substring(0, 100) : lastEntry.body}"',
            tag: 'ChatStreamingService',
          );

          // Enqueue the final response for TTS if not in text-only mode
          if (!onlyText) {
            final String messageText = lastEntry.getMessage();
            if (messageText.isNotEmpty) {
              _ttsQueueManager?.enqueue(
                text: messageText,
                language: language,
                voiceEffect: VoiceEffect(pitch: 1.0, speedRate: 1.0),
              );
              AppLogger.debug(
                'Enqueued TTS for function calling response: "${messageText.length > 50 ? messageText.substring(0, 50) : messageText}..."',
                tag: 'ChatStreamingService',
              );
            }
          }

          onStreamComplete(chat);
          await _chatRepository.updateChat(id: chat.id, updatedChat: chat);
          return;
        }
      }

      // 3. No function calls - proceed with streaming

      final String systemPrompt = await _promptDatasource.getSystemPrompt();

      final StringBuffer contentBuffer = StringBuffer();
      String? fullJsonResponse;
      int sentenceCount = 0;
      bool streamError = false;

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
            onChatUpdated(chat);

            onStreamingUpdate(contentBuffer.toString(), sentenceCount);

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
              tag: 'ChatStreamingService',
            );
          },
          error: (String msg) {
            AppLogger.error('Stream error: $msg', tag: 'ChatStreamingService');
            onError(msg);
            streamError = true;
          },
        );
      }

      // If an error occurred during streaming, don't proceed with finalization
      if (streamError) {
        return;
      }

      if (_streamInterrupted || _interruptionService.isInterrupted) {
        onStreamComplete(chat);
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
      onChatUpdated(chat);

      onStreamComplete(chat);
      await _chatRepository.updateChat(id: chat.id, updatedChat: chat);

      return;
    } catch (e) {
      AppLogger.error(
        'Error in streaming message',
        tag: 'ChatStreamingService',
        error: e,
      );
      onError(e.toString());
      return;
    }
  }

  /// Mark the stream as interrupted (called from external interruption listener)
  void markInterrupted() {
    _streamInterrupted = true;
  }
}
