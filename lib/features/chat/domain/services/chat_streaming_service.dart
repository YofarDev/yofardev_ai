import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/avatar_cue.dart';
import '../../../../core/models/chat.dart';
import '../../../../core/models/chat_entry.dart';
import '../../../../core/models/function_info.dart';
import '../../../../core/models/llm_config.dart';
import '../../../../core/models/llm_message.dart';
import '../../../../core/models/voice_effect.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/services/agent/tool_registry.dart';
import '../../../../core/services/audio/interruption_service.dart';
import '../../../sound/sound.dart';
import '../../../../core/services/llm/llm_service_interface.dart';
import '../../../../core/services/llm/llm_stream_chunk.dart';
import '../../../../core/services/prompt_datasource.dart';
import '../../../../core/services/stream_processor/sentence_chunk.dart';
import '../../../../core/services/stream_processor/stream_processor_service.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/logger.dart';
import '../repositories/chat_repository.dart';
import 'chat_entry_service.dart';
import 'cue_parser.dart';
import 'global_memory_service.dart';

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
    ToolRegistry? toolRegistry,
    SettingsRepository? settingsRepository,
    GlobalMemoryService? globalMemoryService,
  }) : _chatRepository = chatRepository,
       _llmService = llmService,
       _streamProcessor = streamProcessor,
       _promptDatasource = promptDatasource,
       _interruptionService = interruptionService,
       _chatEntryService = chatEntryService,
       _ttsQueueManager = ttsQueueManager,
       _toolRegistry = toolRegistry,
       _settingsRepository = settingsRepository,
       _globalMemoryService = globalMemoryService;

  final ChatRepository _chatRepository;
  final LlmServiceInterface _llmService;
  final StreamProcessorService _streamProcessor;
  final PromptDatasource _promptDatasource;
  final InterruptionService _interruptionService;
  final ChatEntryService _chatEntryService;
  final TtsQueueService? _ttsQueueManager;
  final ToolRegistry? _toolRegistry;
  final SettingsRepository? _settingsRepository;
  final GlobalMemoryService? _globalMemoryService;

  bool _streamInterrupted = false;

  final StreamController<List<AvatarCue>> _streamingCuesController =
      StreamController<List<AvatarCue>>.broadcast();

  /// Cues of each streamed sentence when TTS is disabled (onlyText mode):
  /// with no playback to time them against, they fire as soon as their
  /// sentence chunk finishes streaming.
  Stream<List<AvatarCue>> get streamingCues => _streamingCuesController.stream;

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

      // Messages sent to the LLM stream. Tool definitions are passed inline
      // so tool detection happens inside the streamed call itself; when tools
      // fire, their results are appended and the answer is streamed in a
      // further round.
      List<LlmMessage> messagesForStream = chat.llmMessages;

      // Transient tail context, injected AFTER the history (right before the
      // current user message), never into the system prompt: the prefix
      // [system prompt | history] then stays byte-identical across turns so
      // provider-side prompt caches keep hitting. Global memory and the
      // per-turn avatar/date context (previously baked into every stored
      // user body) both ride here.
      final List<LlmMessage> tailContext = <LlmMessage>[];
      if (_globalMemoryService != null && messagesForStream.isNotEmpty) {
        final LlmMessage? memoryMessage = await _globalMemoryService
            .buildMemoryMessage();
        if (memoryMessage != null) {
          tailContext.add(memoryMessage);
        }
      }
      tailContext.add(
        LlmMessage(
          role: LlmMessageRole.system,
          body:
              'Date : ${DateTime.now().toLongLocalDateString(language: language)}\n'
              'Avatar Config :\n'
              '{\n$avatar\n}\n',
        ),
      );
      if (tailContext.isNotEmpty) {
        int insertIndex = messagesForStream.length - 1;
        for (int i = messagesForStream.length - 1; i >= 0; i--) {
          if (messagesForStream[i].role == LlmMessageRole.user) {
            insertIndex = i;
            break;
          }
        }
        messagesForStream = <LlmMessage>[
          ...messagesForStream.sublist(0, insertIndex),
          ...tailContext,
          ...messagesForStream.sublist(insertIndex),
        ];
      }

      List<Map<String, dynamic>>? tools;
      if (functionCallingEnabled &&
          _toolRegistry != null &&
          _settingsRepository != null) {
        final List<FunctionInfo> availableFunctions = await _toolRegistry
            .getFunctionInfos(_settingsRepository);
        if (availableFunctions.isNotEmpty) {
          tools = availableFunctions.toOpenAiTools();
        }
      }

      // 3. Stream the answer (covers both the plain path and the
      // tools-called path)
      final String systemPrompt = await _promptDatasource.getSystemPrompt();

      final StringBuffer contentBuffer = StringBuffer();
      String? fullJsonResponse;
      bool streamError = false;

      // Inline avatar cues ([g:...]/[s:...]) are stripped from the stream
      // here; each sentence's cues ride its TTS queue item so they can fire
      // in time with speech. A fresh parser per reply: cue state never
      // leaks between replies. The current scene decides which scene-event
      // cues are valid.
      final CueSentenceCollector cueCollector = CueSentenceCollector(
        CueParser(currentScene: avatar.background),
      );

      /// Hands one delivery's cues to the avatar: on its TTS queue item (so
      /// they fire when that audio starts), or straight away in text-only
      /// mode. A cue-only delivery (empty text) becomes a cue-only item.
      void deliverCues(String cleanText, List<AvatarCue> cues) {
        if (!onlyText) {
          _ttsQueueManager?.enqueue(
            text: cleanText,
            language: language,
            voiceEffect: VoiceEffect(pitch: 1.0, speedRate: 1.0),
            cues: cues,
          );
        } else if (cues.isNotEmpty) {
          _streamingCuesController.add(cues);
        }
      }

      /// Appends one clean sentence to the reply, updates the chat, and
      /// enqueues it for TTS together with its cues.
      void deliverSentence(CueDelivery delivery) {
        if (delivery.text.isEmpty) {
          deliverCues('', delivery.cues);
          return;
        }
        if (contentBuffer.isNotEmpty) {
          contentBuffer.write(' ');
        }
        contentBuffer.write(delivery.text);

        final ChatEntry updatedEntry = streamingEntry.copyWith(
          body: contentBuffer.toString(),
        );

        final List<ChatEntry> updatedEntries = List<ChatEntry>.from(
          chat.entries,
        );
        updatedEntries[updatedEntries.length - 1] = updatedEntry;

        chat = chat.copyWith(entries: updatedEntries);
        onChatUpdated(chat);

        deliverCues(delivery.text, delivery.cues);
      }

      // Hard cap on tool rounds to avoid infinite tool-call loops.
      const int maxToolRounds = 3;
      for (int round = 0; round < maxToolRounds; round++) {
        // Accumulate fragmented tool_call deltas while the stream flows
        // through the sentence processor.
        final Map<int, Map<String, String>> pendingToolCalls =
            <int, Map<String, String>>{};

        contentBuffer.clear();
        fullJsonResponse = null;

        final Stream<LlmStreamChunk> instrumentedStream = _llmService
            .promptModelStream(
              messages: messagesForStream,
              systemPrompt: systemPrompt,
              config: config,
              returnJson: true,
              tools: tools,
            )
            .map((LlmStreamChunk chunk) {
              chunk.when(
                text: (String content, bool isComplete) {},
                error: (String message) {},
                complete: () {},
                toolCallDelta:
                    (
                      int index,
                      String? id,
                      String? name,
                      String? argumentsDelta,
                    ) {
                      final Map<String, String> call = pendingToolCalls
                          .putIfAbsent(
                            index,
                            () => <String, String>{
                              'id': '',
                              'name': '',
                              'arguments': '',
                            },
                          );
                      if (id != null) call['id'] = id;
                      if (name != null) call['name'] = name;
                      if (argumentsDelta != null) {
                        call['arguments'] = call['arguments']! + argumentsDelta;
                      }
                    },
              );
              return chunk;
            });

        await for (final SentenceChunk sentenceChunk
            in _streamProcessor.processStream(instrumentedStream)) {
          if (_streamInterrupted || _interruptionService.isInterrupted) {
            break;
          }

          sentenceChunk.when(
            sentence: (String text, int _) {
              if (_streamInterrupted || _interruptionService.isInterrupted) {
                return;
              }

              // Null for a cue-only chunk: its cues ride the next sentence.
              final CueDelivery? delivery = cueCollector.add(text);
              if (delivery != null) {
                deliverSentence(delivery);
              }
            },
            metadata: (Map<String, dynamic> json) {
              // Capture the full JSON response, with cues stripped from the
              // stored text so saved entries keep only the clean text.
              if (json.containsKey('fullJson')) {
                fullJsonResponse = CueParser.stripCuesFromReplyJson(
                  json['fullJson'] as String?,
                );
              }
            },
            complete: () {
              AppLogger.debug('Stream complete', tag: 'ChatStreamingService');
            },
            error: (String msg) {
              AppLogger.error(
                'Stream error: $msg',
                tag: 'ChatStreamingService',
              );
              onError(msg);
              streamError = true;
            },
          );
        }

        // End of stream: literal leftover text and any trailing cues
        // (`See you! [g:wave]`) are delivered now instead of being lost.
        final CueDelivery? leftover = cueCollector.finish();
        if (!streamError && leftover != null) {
          deliverSentence(leftover);
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

        if (tools == null || pendingToolCalls.isEmpty) {
          break; // Final answer streamed.
        }

        if (round == maxToolRounds - 1) {
          AppLogger.warning(
            'Tool round cap reached; dropping ${pendingToolCalls.length} unexecuted tool calls',
            tag: 'ChatStreamingService',
          );
          break;
        }

        // Tools fired: execute them, surface the entries in the chat, append
        // the assistant tool_calls message plus one tool result each, and
        // stream the answer in the next round.
        final List<LlmMessage> toolMessages = <LlmMessage>[];
        final List<Map<String, dynamic>> assistantToolCalls =
            <Map<String, dynamic>>[];
        final List<ChatEntry> functionEntries = <ChatEntry>[];

        final List<int> indexes = pendingToolCalls.keys.toList()..sort();
        for (final int index in indexes) {
          final Map<String, String> call = pendingToolCalls[index]!;
          final String toolCallId = call['id']!.isEmpty
              ? 'call_$index'
              : call['id']!;
          final String name = call['name']!;
          final String argumentsJson = call['arguments']!;

          assistantToolCalls.add(<String, dynamic>{
            'id': toolCallId,
            'type': 'function',
            'function': <String, dynamic>{
              'name': name,
              'arguments': argumentsJson,
            },
          });

          Map<String, dynamic> parameters = <String, dynamic>{};
          if (argumentsJson.isNotEmpty) {
            try {
              parameters = json.decode(argumentsJson) as Map<String, dynamic>;
            } catch (e) {
              AppLogger.warning(
                'Failed to parse tool arguments for $name: $e',
                tag: 'ChatStreamingService',
              );
            }
          }

          dynamic result;
          final AgentTool? tool = _toolRegistry?.getTool(name);
          if (tool == null) {
            result = 'Unknown tool: $name';
          } else {
            try {
              result = await _toolRegistry!.executeTool(
                tool,
                parameters,
                _settingsRepository!,
              );
            } catch (e) {
              result = 'Error executing tool: $e';
            }
          }

          toolMessages.add(
            LlmMessage(
              role: LlmMessageRole.tool,
              body: result.toString(),
              toolCallId: toolCallId,
            ),
          );

          functionEntries.add(
            ChatEntry(
              id: const Uuid().v4(),
              entryType: EntryType.functionCalling,
              body: json.encode(<Map<String, dynamic>>[
                <String, dynamic>{
                  'name': name,
                  'parameters': parameters,
                  'result': result,
                },
              ]),
              timestamp: DateTime.now(),
            ),
          );
        }

        messagesForStream = <LlmMessage>[
          ...messagesForStream,
          LlmMessage(
            role: LlmMessageRole.assistant,
            body: '',
            toolCalls: assistantToolCalls,
          ),
          ...toolMessages,
        ];

        // Insert tool entries BEFORE the streaming entry: the per-sentence
        // updates replace the LAST entry with the answer, so appending after
        // it would clobber the last function-calling tile.
        final List<ChatEntry> entriesWithTools = List<ChatEntry>.from(
          chat.entries,
        )..insertAll(chat.entries.length - 1, functionEntries);
        chat = chat.copyWith(entries: entriesWithTools);
        onChatUpdated(chat);
        AppLogger.debug(
          'Executed ${functionEntries.length} streamed tool call(s), streaming answer round ${round + 2}',
          tag: 'ChatStreamingService',
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
