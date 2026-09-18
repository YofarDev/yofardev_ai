import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/models/result.dart';
import '../../../../core/models/chat.dart';
import '../../../../core/models/chat_entry.dart';
import '../../../../core/models/llm_config.dart';
import '../../../../core/models/llm_message.dart';
import '../../../../core/models/voice_effect.dart';
import '../../../../core/services/audio/interruption_service.dart';
import '../../../sound/sound.dart';
import '../../../../core/services/llm/llm_service_interface.dart';
import '../../../../core/services/prompt_datasource.dart';
import '../../../../core/services/stream_processor/sentence_chunk.dart';
import '../../../../core/services/stream_processor/stream_processor_service.dart';
import '../../../../core/utils/logger.dart';
import '../repositories/chat_repository.dart';
import 'chat_entry_service.dart';

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

      // Messages sent to the LLM stream. When tools were executed, the last
      // user message is replaced with the augmented version containing the
      // tool results.
      List<LlmMessage> messagesForStream = chat.llmMessages;

      if (functionCallingEnabled) {
        // 1. Detect and execute tools (no final answer generated here)
        final Result<(List<ChatEntry> functionEntries, String augmentedUserMessage)>
        functionCheckResult = await _chatRepository.prepareToolTurn(
          chat: chat,
          userMessage: userEntry.body,
        );

        List<ChatEntry> functionEntries = <ChatEntry>[];
        String augmentedUserMessage = userEntry.body;

        functionCheckResult.when(
          err: (Failure failure) {
            AppLogger.error(
              'Function calling check failed',
              tag: 'ChatStreamingService',
              error: failure,
            );
            // Continue with streaming even if function calling fails
          },
          ok:
              (
                (List<ChatEntry> entries, String augmented) toolTurn,
              ) {
                functionEntries = toolTurn.$1;
                augmentedUserMessage = toolTurn.$2;
                // Add function call entries to chat if any
                if (toolTurn.$1.isNotEmpty) {
                  final List<ChatEntry> updatedEntries = <ChatEntry>[
                    ...chat.entries,
                    ...toolTurn.$1,
                  ];
                  chat = chat.copyWith(entries: updatedEntries);
                  onChatUpdated(chat);
                }
              },
        );

        // 2. If tools fired, replace the last user message with the augmented
        // one so the streamed answer uses the tool results.
        final bool hadFunctionCalls = functionEntries.any(
          (ChatEntry e) => e.entryType == EntryType.functionCalling,
        );

        if (hadFunctionCalls) {
          final List<LlmMessage> messages = List<LlmMessage>.from(
            chat.llmMessages,
          );
          if (messages.isNotEmpty &&
              messages.last.role == LlmMessageRole.user) {
            final LlmMessage lastMsg = messages.last;
            messages[messages.length - 1] = LlmMessage(
              role: LlmMessageRole.user,
              body: augmentedUserMessage,
              attachedFile: lastMsg.attachedFile,
            );
          } else {
            messages.add(
              LlmMessage(
                role: LlmMessageRole.user,
                body: augmentedUserMessage,
              ),
            );
          }
          messagesForStream = messages;
        }
      }

      // 3. Stream the answer (covers both the plain path and the
      // tools-called path)
      final String systemPrompt = await _promptDatasource.getSystemPrompt();

      final StringBuffer contentBuffer = StringBuffer();
      String? fullJsonResponse;
      int sentenceCount = 0;
      bool streamError = false;

      await for (final SentenceChunk sentenceChunk
          in _streamProcessor.processStream(
            _llmService.promptModelStream(
              messages: messagesForStream,
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
