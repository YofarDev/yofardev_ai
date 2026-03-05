import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/stream_processor/sentence_chunk.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/logger.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/llm_config.dart';
import '../../../core/services/llm/llm_service.dart';
import '../../../core/services/stream_processor/stream_processor_service.dart';
import '../../../l10n/localization_manager.dart';
import '../../home/data/datasources/prompt_datasource.dart';
import '../../settings/domain/repositories/settings_repository.dart';
import '../domain/models/chat.dart';
import '../domain/models/chat_entry.dart';
import '../domain/repositories/chat_repository.dart';
import 'chat_message_state.dart';

class ChatMessageCubit extends Cubit<ChatMessageState> {
  ChatMessageCubit({
    required ChatRepository chatRepository,
    required SettingsRepository settingsRepository,
  }) : _chatRepository = chatRepository,
       _settingsRepository = settingsRepository,
       _llmService = LlmService(),
       _streamProcessor = StreamProcessorService(),
       super(ChatMessageState.initial());

  final ChatRepository _chatRepository;
  final SettingsRepository _settingsRepository;
  final LlmService _llmService;
  final StreamProcessorService _streamProcessor;

  void setLanguage(String language) {}

  Future<void> prepareWaitingSentences(String language) async {
    if (language == 'Web') {
      emit(state.copyWith(initializing: false));
      return;
    }
    try {
      final List<Map<String, dynamic>>? cachedSentences =
          await _getWaitingSentencesMap(language);
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

  Future<List<Map<String, dynamic>>?> _getWaitingSentencesMap(
    String language,
  ) async {
    return null;
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

  Future<ChatEntry?> askYofardev(
    String prompt, {
    required bool onlyText,
    String? attachedImage,
    required Avatar avatar,
    required Chat currentChat,
  }) async {
    emit(
      state.copyWith(
        audioPathsWaitingSentences: <Map<String, dynamic>>[],
        status: ChatMessageStatus.typing,
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

    try {
      final Either<Exception, List<ChatEntry>> result = await _chatRepository
          .askYofardevAi(chat, userEntry.body, functionCallingEnabled: true);

      return result.fold(
        (Exception error) {
          AppLogger.error(
            'Error sending text message',
            tag: 'ChatMessageCubit',
            error: error,
          );
          emit(
            state.copyWith(
              status: ChatMessageStatus.error,
              errorMessage: error.toString(),
            ),
          );
          return null;
        },
        (List<ChatEntry> newEntries) {
          final List<ChatEntry> entries = <ChatEntry>[
            ...chat.entries,
            ...newEntries,
          ];
          final Chat chatWithEntries = chat.copyWith(entries: entries);
          emit(state.copyWith(status: ChatMessageStatus.success));
          _chatRepository.updateChat(id: chat.id, updatedChat: chatWithEntries);
          return newEntries.isNotEmpty ? newEntries.last : null;
        },
      );
    } catch (e) {
      AppLogger.error(
        'Error sending text message',
        tag: 'ChatMessageCubit',
        error: e,
      );
      emit(
        state.copyWith(
          status: ChatMessageStatus.error,
          errorMessage: e.toString(),
        ),
      );
      return null;
    }
  }

  Future<ChatEntry?> askYofardevStream(
    String prompt, {
    required bool onlyText,
    String? attachedImage,
    required Avatar avatar,
    required Chat currentChat,
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

    final ChatEntry streamingEntry = ChatEntry(
      id: const Uuid().v4(),
      entryType: EntryType.yofardev,
      body: '',
      timestamp: DateTime.now(),
    );

    chat = chat.copyWith(entries: <ChatEntry>[...chat.entries, streamingEntry]);

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
        return null;
      }

      final PromptDatasource promptService = PromptDatasource();
      final String systemPrompt = await promptService.getSystemPrompt();

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
            emit(
              state.copyWith(
                streamingContent: contentBuffer.toString(),
                streamingSentenceCount: sentenceCount,
              ),
            );
          },
          metadata: (_) {},
          complete: () {},
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

      emit(
        state.copyWith(status: ChatMessageStatus.success, streamingContent: ''),
      );

      await _chatRepository.updateChat(id: chat.id, updatedChat: chat);

      return finalEntry;
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
      return null;
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

  String _sanitizeTitle(String title) {
    String sanitized = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    sanitized = sanitized.replaceAll(RegExp(r'''^["']|["']$'''), '');
    if (sanitized.length > 50) {
      sanitized = '${sanitized.substring(0, 47)}...';
    }
    return sanitized;
  }

  String? _getFirstUserMessage(Chat chat) {
    try {
      return chat.entries
          .where((ChatEntry e) => e.entryType == EntryType.user)
          .firstOrNull
          ?.body
          .getVisiblePrompt();
    } catch (e) {
      return null;
    }
  }

  Future<void> generateTitleForChat(Chat chat) async {
    if (chat.titleGenerated || chat.entries.isEmpty) return;

    final bool isAlreadyGenerating = state.generatingTitleChatIds.contains(
      chat.id,
    );
    if (isAlreadyGenerating) return;

    final Set<String> newGeneratingIds = <String>{
      ...state.generatingTitleChatIds,
      chat.id,
    };
    emit(state.copyWith(generatingTitleChatIds: newGeneratingIds));

    try {
      final String? firstUserMessage = _getFirstUserMessage(chat);
      if (firstUserMessage == null || firstUserMessage.isEmpty) return;

      final String? title = await _llmService.generateTitle(firstUserMessage);

      if (title != null && title.isNotEmpty && title.length <= 100) {
        final String sanitizedTitle = _sanitizeTitle(title);
        final Chat updatedChat = chat.copyWith(
          title: sanitizedTitle,
          titleGenerated: true,
        );
        await _chatRepository.updateChat(id: chat.id, updatedChat: updatedChat);
        AppLogger.info(
          'Title generated: $sanitizedTitle',
          tag: 'ChatMessageCubit',
        );
      }
    } catch (e) {
      AppLogger.error(
        'Failed to generate title',
        tag: 'ChatMessageCubit',
        error: e,
      );
    } finally {
      final Set<String> updatedIds = state.generatingTitleChatIds.toSet()
        ..remove(chat.id);
      emit(state.copyWith(generatingTitleChatIds: updatedIds));
    }
  }

  void triggerTitleGenerationIfNeeded(Chat chat) {
    final bool hasOnlyOneUserMessage =
        chat.entries
            .where((ChatEntry e) => e.entryType == EntryType.user)
            .length ==
        1;

    if (hasOnlyOneUserMessage && !chat.titleGenerated) {
      generateTitleForChat(chat);
    }
  }
}
