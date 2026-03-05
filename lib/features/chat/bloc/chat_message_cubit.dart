import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/stream_processor/sentence_chunk.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../l10n/localization_manager.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/llm_config.dart';
import '../../../core/models/voice_effect.dart';
import '../../../core/services/llm/llm_service.dart';
import '../../../core/services/prompt_datasource.dart';
import '../../../core/services/stream_processor/stream_processor_service.dart';
import '../../avatar/data/datasources/avatar_cache_datasource.dart';
import '../../settings/domain/repositories/settings_repository.dart';
import '../../sound/domain/tts_queue_manager.dart';
import '../domain/models/chat.dart';
import '../domain/models/chat_entry.dart';
import '../domain/repositories/chat_repository.dart';
import 'chat_message_state.dart';
import 'chat_title_cubit.dart';

/// Cubit responsible for chat message operations
///
/// Handles:
/// - Sending messages (non-streaming)
/// - Streaming messages with real-time TTS
/// - Message state management
class ChatMessageCubit extends Cubit<ChatMessageState> {
  ChatMessageCubit({
    required ChatRepository chatRepository,
    required SettingsRepository settingsRepository,
    required LlmService llmService,
    required StreamProcessorService streamProcessor,
    required PromptDatasource promptDatasource,
    TtsQueueManager? ttsQueueManager,
    ChatTitleCubit? chatTitleCubit,
  }) : _chatRepository = chatRepository,
       _settingsRepository = settingsRepository,
       _llmService = llmService,
       _streamProcessor = streamProcessor,
       _promptDatasource = promptDatasource,
       _ttsQueueManager = ttsQueueManager,
       _chatTitleCubit = chatTitleCubit,
       super(ChatMessageState.initial());

  final ChatRepository _chatRepository;
  final SettingsRepository _settingsRepository;
  final LlmService _llmService;
  final StreamProcessorService _streamProcessor;
  final PromptDatasource _promptDatasource;
  final TtsQueueManager? _ttsQueueManager;
  final ChatTitleCubit? _chatTitleCubit;

  Future<void> prepareWaitingSentences(String language) async {
    if (PlatformUtils.checkPlatform() == 'Web') {
      emit(state.copyWith(initializing: false));
      return;
    }
    try {
      final List<Map<String, dynamic>>? cachedSentences =
          await AvatarCacheDatasource.getWaitingSentencesMap(language);
      if (cachedSentences != null) {
        emit(
          state.copyWith(
            audioPathsWaitingSentences: cachedSentences,
            initializing: false,
          ),
        );
      } else {
        emit(state.copyWith(initializing: false));
      }
    } catch (e) {
      AppLogger.error(
        'Failed to load waiting sentences',
        tag: 'ChatMessageCubit',
        error: e,
      );
      emit(state.copyWith(initializing: false));
    }
  }

  void shuffleWaitingSentences() {
    final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(
      state.audioPathsWaitingSentences,
    );
    list.shuffle();
    emit(state.copyWith(audioPathsWaitingSentences: list));
  }

  void removeWaitingSentence(String audioPath) {
    final List<Map<String, dynamic>> currentList =
        List<Map<String, dynamic>>.from(state.audioPathsWaitingSentences);
    currentList.removeWhere(
      (Map<String, dynamic> element) => element['audioPath'] == audioPath,
    );
    emit(state.copyWith(audioPathsWaitingSentences: currentList));
  }

  Future<void> askYofardev(
    String prompt, {
    required bool onlyText,
    String? attachedImage,
    required Avatar avatar,
    required Chat currentChat,
    required String language,
    void Function(Chat updatedChat)? onChatUpdated,
  }) async {
    emit(
      state.copyWith(
        audioPathsWaitingSentences: <Map<String, dynamic>>[],
        status: ChatMessageStatus.streaming,
        streamingContent: '',
        streamingSentenceCount: 0,
      ),
    );

    final String temporaryId = const Uuid().v4();

    final ChatEntry temporaryEntry = ChatEntry(
      id: temporaryId,
      entryType: EntryType.user,
      body: "${localized.userMessage} : \n'''$prompt'''",
      timestamp: DateTime.now(),
      attachedImage: attachedImage,
    );

    Chat chat = currentChat.copyWith(
      entries: <ChatEntry>[...currentChat.entries, temporaryEntry],
    );
    onChatUpdated?.call(chat);

    final ChatEntry userEntry = await _createUserEntry(
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
            status: ChatMessageStatus.error,
            errorMessage: 'No LLM configuration selected',
          ),
        );
        return;
      }
      // 1. Check for function calls first (same as non-streaming flow)
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
            tag: 'ChatMessageCubit',
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
        final List<ChatEntry> finalEntries = List<ChatEntry>.from(chat.entries);
        finalEntries[finalEntries.length - 1] = finalResponse;
        chat = chat.copyWith(entries: finalEntries);
        onChatUpdated?.call(chat);

        emit(
          state.copyWith(
            status: ChatMessageStatus.success,
            streamingContent: '',
          ),
        );
        await _chatRepository.updateChat(id: chat.id, updatedChat: chat);
        return;
      }

      // 3. No function calls - proceed with streaming

      final String systemPrompt = await _promptDatasource.getSystemPrompt();

      final StringBuffer contentBuffer = StringBuffer();
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
        sentenceChunk.when(
          sentence: (String text, int index) {
            contentBuffer.write(' $text');
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
                text: text,
                language: language,
                voiceEffect: VoiceEffect(pitch: 1.0, speedRate: 1.0),
              );
            }
          },
          metadata: (_) {},
          complete: () {
            AppLogger.debug(
              'Stream complete with $sentenceCount sentences',
              tag: 'ChatMessageCubit',
            );
          },
          error: (String msg) {
            AppLogger.error('Stream error: $msg', tag: 'ChatMessageCubit');
          },
        );
      }

      final ChatEntry finalEntry = streamingEntry.copyWith(
        body: contentBuffer.toString(),
      );

      final List<ChatEntry> finalEntries = List<ChatEntry>.from(chat.entries);
      finalEntries[finalEntries.length - 1] = finalEntry;
      chat = chat.copyWith(entries: finalEntries);
      onChatUpdated?.call(chat);

      emit(
        state.copyWith(status: ChatMessageStatus.success, streamingContent: ''),
      );

      await _chatRepository.updateChat(id: chat.id, updatedChat: chat);

      final ChatTitleCubit? titleCubit = _chatTitleCubit;
      if (titleCubit != null && titleCubit.shouldGenerateTitle(chat)) {
        titleCubit.generateTitle(chat.id, chat);
      }

      return;
    } catch (e) {
      AppLogger.error(
        'Error in streaming message',
        tag: 'ChatMessageCubit',
        error: e,
      );
      emit(
        state.copyWith(
          status: ChatMessageStatus.error,
          errorMessage: e.toString(),
          streamingContent: '',
        ),
      );
      return;
    }
  }

  Future<ChatEntry> _createUserEntry({
    required String prompt,
    required Avatar avatar,
    String? attachedImage,
  }) async {
    final String languageCode = (await _settingsRepository.getLanguage()).fold(
      (Exception error) => 'fr',
      (String? language) => language ?? 'fr',
    );
    final String wrappedUserMessage =
        "${localized.currentDate} : ${DateTime.now().toLongLocalDateString(language: languageCode)}\n${localized.currentAvatarConfig} :\n{\n$avatar\n}\n${localized.userMessage} : \n'''$prompt'''";

    return ChatEntry(
      id: const Uuid().v4(),
      entryType: EntryType.user,
      body: wrappedUserMessage,
      timestamp: DateTime.now(),
      attachedImage: attachedImage,
    );
  }
}
