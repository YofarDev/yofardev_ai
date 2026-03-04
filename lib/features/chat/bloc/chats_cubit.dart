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
import '../../../core/models/llm_message.dart';
import '../../../core/services/llm/llm_service.dart';
import '../../../core/services/stream_processor/stream_processor_service.dart';
import '../../avatar/data/datasources/avatar_cache_datasource.dart';
import '../../home/data/datasources/prompt_datasource.dart';
import '../../settings/domain/repositories/settings_repository.dart';
import '../../sound/data/datasources/tts_datasource.dart';
import '../../sound/domain/tts_queue_manager.dart';
import '../domain/models/chat.dart';
import '../domain/models/chat_entry.dart';
import '../domain/repositories/chat_repository.dart';
import 'chats_state.dart';

class ChatsCubit extends Cubit<ChatsState> {
  ChatsCubit({
    required ChatRepository chatRepository,
    required SettingsRepository settingsRepository,
    required LocalizationManager localizationManager,
    required TtsQueueManager ttsQueueManager,
  }) : _chatRepository = chatRepository,
       _settingsRepository = settingsRepository,
       _localizationManager = localizationManager,
       _ttsQueueManager = ttsQueueManager,
       super(ChatsState.initial());

  final ChatRepository _chatRepository;
  final SettingsRepository _settingsRepository;
  final LocalizationManager _localizationManager;
  final TtsQueueManager _ttsQueueManager;

  final StreamProcessorService _streamProcessor = StreamProcessorService();

  void createNewChat() async {
    emit(state.copyWith(status: ChatsStatus.updating));
    final Either<Exception, Chat> result = await _chatRepository
        .createNewChat();
    result.fold(
      (Exception error) {
        emit(
          state.copyWith(
            status: ChatsStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
      (Chat newChat) {
        emit(
          state.copyWith(
            status: ChatsStatus.success,
            chatsList: <Chat>[newChat, ...state.chatsList],
            currentChat: newChat,
            chatCreated: true,
          ),
        );
        emit(state.copyWith(chatCreated: false));
      },
    );
  }

  void init() async {
    getCurrentChat();
    if (PlatformUtils.checkPlatform() == 'Web' ||
        PlatformUtils.checkPlatform() == 'MacOS') {
      setCurrentLanguage("fr");
    } else {
      final Either<Exception, String?> languageResult =
          await _settingsRepository.getLanguage();
      languageResult.fold(
        (Exception error) => 'fr',
        (String? language) => setCurrentLanguage(language ?? 'fr'),
      );
    }
  }

  void toggleFunctionCalling() {
    emit(state.copyWith(functionCallingEnabled: !state.functionCallingEnabled));
  }

  Future<void> prepareWaitingSentences(List<String> sentences) async {
    if (PlatformUtils.checkPlatform() == 'Web') {
      emit(state.copyWith(initializing: false));
      return;
    }
    try {
      final List<Map<String, dynamic>>? cachedSentences =
          await AvatarCacheDatasource.getWaitingSentencesMap(
            state.currentLanguage,
          );
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
        tag: 'ChatsCubit',
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

  void getCurrentChat() async {
    emit(state.copyWith(status: ChatsStatus.loading));
    final Either<Exception, Chat> currentChatResult = await _chatRepository
        .getCurrentChat();
    final Either<Exception, bool> soundEffectsResult = await _settingsRepository
        .getSoundEffects();
    final Either<Exception, String?> languageResult = await _settingsRepository
        .getLanguage();

    currentChatResult.fold(
      (Exception error) {
        emit(
          state.copyWith(
            status: ChatsStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
      (Chat currentChat) {
        final String language = languageResult.fold(
          (Exception error) => currentChat.language,
          (String? lang) => lang ?? currentChat.language,
        );
        final bool soundEffectsEnabled = soundEffectsResult.fold(
          (Exception error) => false,
          (bool enabled) => enabled,
        );
        emit(
          state.copyWith(
            status: ChatsStatus.success,
            currentChat: currentChat,
            soundEffectsEnabled: soundEffectsEnabled,
            currentLanguage: language,
          ),
        );
      },
    );
  }

  Future<void> setCurrentLanguage(String language) async {
    final Either<Exception, void> result = await _settingsRepository
        .setLanguage(language);
    result.fold(
      (Exception error) {
        AppLogger.error(
          'Failed to set language',
          tag: 'ChatsCubit',
          error: error,
        );
      },
      (_) {
        // Don't await localization in tests - it can cause issues
        _localizationManager.initialize(language).ignore();
        emit(state.copyWith(currentLanguage: language));
      },
    );
  }

  Future<void> setSoundEffects(bool soundEffectsEnabled) async {
    final Either<Exception, void> result = await _settingsRepository
        .setSoundEffects(soundEffectsEnabled);
    result.fold(
      (Exception error) {
        AppLogger.error(
          'Failed to set sound effects',
          tag: 'ChatsCubit',
          error: error,
        );
      },
      (_) {
        emit(state.copyWith(soundEffectsEnabled: soundEffectsEnabled));
      },
    );
  }

  void fetchChatsList() async {
    emit(state.copyWith(status: ChatsStatus.loading));
    final Either<Exception, List<Chat>> result = await _chatRepository
        .getChatsList();
    result.fold(
      (Exception error) {
        emit(
          state.copyWith(
            status: ChatsStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
      (List<Chat> chatsList) {
        final List<Chat> reversed = chatsList.reversed.toList();
        emit(state.copyWith(status: ChatsStatus.success, chatsList: reversed));
      },
    );
  }

  void deleteChat(String id) async {
    emit(state.copyWith(status: ChatsStatus.updating));
    final Either<Exception, void> result = await _chatRepository.deleteChat(id);
    result.fold(
      (Exception error) {
        emit(
          state.copyWith(
            status: ChatsStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
      (_) {
        final List<Chat> chatsList = List<Chat>.from(state.chatsList);
        chatsList.removeWhere((Chat element) => element.id == id);
        emit(state.copyWith(chatsList: chatsList, status: ChatsStatus.success));
      },
    );
  }

  void setCurrentChat(Chat chat) {
    emit(state.copyWith(currentChat: chat));
    _chatRepository.setCurrentChatId(chat.id);
  }

  void setOpenedChat(Chat chat) {
    emit(state.copyWith(openedChat: chat));
  }

  Future<ChatEntry> _getNewEntry({
    required String lastUserMessage,
    required Avatar avatar,
    required bool onlyText,
    String? attachedImage,
  }) async {
    final String languageCode = (await _settingsRepository.getLanguage()).fold(
      (Exception error) => 'fr',
      (String? language) => language ?? 'fr',
    );
    final String wrappedUserMessage =
        "${localized.currentDate} : ${DateTime.now().toLongLocalDateString(language: languageCode)}\n${localized.currentAvatarConfig} :\n{\n$avatar\n}\n${localized.userMessage} : \n'''$lastUserMessage'''";
    final ChatEntry newUserEntry = ChatEntry(
      id: const Uuid().v4(),
      entryType: EntryType.user,
      body: wrappedUserMessage,
      timestamp: DateTime.now(),
      attachedImage: attachedImage,
    );

    return newUserEntry;
  }

  Future<ChatEntry?> askYofardev(
    String prompt, {
    required bool onlyText,
    String? attachedImage,
    required Avatar avatar,
  }) async {
    Chat chat = onlyText ? state.openedChat : state.currentChat;
    final String temporaryId = const Uuid().v4();
    final ChatEntry temporaryEntry = ChatEntry(
      id: temporaryId,
      entryType: EntryType.user,
      body: "${localized.userMessage} : \n'''$prompt'''",
      timestamp: DateTime.now(),
      attachedImage: attachedImage,
    );
    chat = chat.copyWith(entries: <ChatEntry>[...chat.entries, temporaryEntry]);
    emit(
      state.copyWith(
        status: ChatsStatus.typing,
        openedChat: onlyText ? chat : state.openedChat,
        currentChat: onlyText ? state.currentChat : chat,
      ),
    );
    final ChatEntry userEntry = await _getNewEntry(
      lastUserMessage: prompt,
      avatar: avatar,
      attachedImage: attachedImage,
      onlyText: onlyText,
    );
    chat = onlyText ? state.openedChat : state.currentChat;
    final List<ChatEntry> mutableEntries = List<ChatEntry>.from(chat.entries);
    final int index = mutableEntries.indexWhere(
      (ChatEntry element) => element.id == temporaryId,
    );
    mutableEntries[index] = userEntry;
    chat = chat.copyWith(entries: mutableEntries);
    emit(
      state.copyWith(
        openedChat: onlyText ? chat : state.openedChat,
        currentChat: onlyText ? state.currentChat : chat,
      ),
    );
    try {
      final Either<Exception, List<ChatEntry>> result = await _chatRepository
          .askYofardevAi(
            chat,
            userEntry.body,
            functionCallingEnabled: state.functionCallingEnabled,
          );
      return result.fold(
        (Exception error) {
          AppLogger.error(
            'Error sending text message',
            tag: 'ChatsCubit',
            error: error,
          );
          emit(
            state.copyWith(
              status: ChatsStatus.error,
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
          chat = chat.copyWith(entries: entries);
          emit(
            state.copyWith(
              openedChat: onlyText ? chat : state.openedChat,
              currentChat: onlyText ? state.currentChat : chat,
              status: ChatsStatus.success,
            ),
          );
          // Update chat with new entries
          _chatRepository.updateChat(id: chat.id, updatedChat: chat);
          // Return the last entry (which should be the actual response)
          return newEntries.isNotEmpty ? newEntries.last : null;
        },
      );
    } catch (e) {
      AppLogger.error(
        'Error sending text message',
        tag: 'ChatsCubit',
        error: e,
      );
      emit(
        state.copyWith(status: ChatsStatus.error, errorMessage: e.toString()),
      );
      return null;
    }
  }

  /// Send message with streaming response and real-time TTS
  Future<ChatEntry?> askYofardevStream(
    String prompt, {
    required bool onlyText,
    String? attachedImage,
    required Avatar avatar,
  }) async {
    Chat chat = onlyText ? state.openedChat : state.currentChat;
    final String temporaryId = const Uuid().v4();

    // Add user entry immediately
    final ChatEntry temporaryEntry = ChatEntry(
      id: temporaryId,
      entryType: EntryType.user,
      body: "${localized.userMessage} : \n'''$prompt'''",
      timestamp: DateTime.now(),
      attachedImage: attachedImage,
    );

    chat = chat.copyWith(entries: <ChatEntry>[...chat.entries, temporaryEntry]);

    emit(
      state.copyWith(
        status: ChatsStatus.streaming,
        streamingContent: '',
        streamingSentenceCount: 0,
        openedChat: onlyText ? chat : state.openedChat,
        currentChat: onlyText ? state.currentChat : chat,
      ),
    );

    final ChatEntry userEntry = await _getNewEntry(
      lastUserMessage: prompt,
      avatar: avatar,
      attachedImage: attachedImage,
      onlyText: onlyText,
    );

    chat = onlyText ? state.openedChat : state.currentChat;
    final List<ChatEntry> mutableEntries = List<ChatEntry>.from(chat.entries);
    final int index = mutableEntries.indexWhere(
      (ChatEntry element) => element.id == temporaryId,
    );
    mutableEntries[index] = userEntry;
    chat = chat.copyWith(entries: mutableEntries);

    // Create streaming response entry
    final ChatEntry streamingEntry = ChatEntry(
      id: const Uuid().v4(),
      entryType: EntryType.yofardev,
      body: '',
      timestamp: DateTime.now(),
    );

    chat = chat.copyWith(entries: <ChatEntry>[...chat.entries, streamingEntry]);

    emit(
      state.copyWith(
        openedChat: onlyText ? chat : state.openedChat,
        currentChat: onlyText ? state.currentChat : chat,
      ),
    );

    try {
      final LlmService llmService = LlmService();
      await llmService.init();

      final LlmConfig? config = llmService.getCurrentConfig();
      if (config == null) {
        emit(
          state.copyWith(
            status: ChatsStatus.error,
            errorMessage: 'No LLM configuration selected',
          ),
        );
        return null;
      }

      // Get system prompt
      final PromptDatasource promptService = PromptDatasource();
      final String systemPrompt = await promptService.getSystemPrompt();

      // Build messages
      final List<LlmMessage> messages = chat.llmMessages;

      // Start streaming
      final StringBuffer contentBuffer = StringBuffer();
      int sentenceCount = 0;

      await for (final SentenceChunk sentenceChunk
          in _streamProcessor.processStream(
            llmService.promptModelStream(
              messages: messages,
              systemPrompt: systemPrompt,
              config: config,
              returnJson: true,
            ),
          )) {
        sentenceChunk.when(
          sentence: (String text, int index) {
            // Add to streaming content
            contentBuffer.write(' $text');
            sentenceCount++;

            // Update UI
            final ChatEntry updatedEntry = streamingEntry.copyWith(
              body: contentBuffer.toString(),
            );

            final List<ChatEntry> updatedEntries = List<ChatEntry>.from(
              chat.entries,
            );
            updatedEntries[updatedEntries.length - 1] = updatedEntry;

            chat = chat.copyWith(entries: updatedEntries);

            emit(
              state.copyWith(
                streamingContent: contentBuffer.toString(),
                streamingSentenceCount: sentenceCount,
                openedChat: onlyText ? chat : state.openedChat,
                currentChat: onlyText ? state.currentChat : chat,
              ),
            );

            // Enqueue for TTS
            _ttsQueueManager.enqueue(
              text: text,
              language: state.currentLanguage,
              voiceEffect: VoiceEffect(pitch: 1.0, speedRate: 1.0),
            );
          },
          metadata: (Map<String, dynamic> json) {
            // Handle any metadata if needed
          },
          complete: () {
            AppLogger.debug(
              'Stream complete with $sentenceCount sentences',
              tag: 'ChatsCubit',
            );
          },
          error: (String message) {
            AppLogger.error('Stream error: $message', tag: 'ChatsCubit');
          },
        );
      }

      // Final update
      final ChatEntry finalEntry = streamingEntry.copyWith(
        body: contentBuffer.toString(),
      );

      final List<ChatEntry> finalEntries = List<ChatEntry>.from(chat.entries);
      finalEntries[finalEntries.length - 1] = finalEntry;
      chat = chat.copyWith(entries: finalEntries);

      emit(
        state.copyWith(
          openedChat: onlyText ? chat : state.openedChat,
          currentChat: onlyText ? state.currentChat : chat,
          status: ChatsStatus.success,
          streamingContent: '',
        ),
      );

      // Save to repository
      await _chatRepository.updateChat(id: chat.id, updatedChat: chat);

      return finalEntry;
    } catch (e) {
      AppLogger.error(
        'Error in streaming message',
        tag: 'ChatsCubit',
        error: e,
      );
      emit(
        state.copyWith(
          status: ChatsStatus.error,
          errorMessage: e.toString(),
          streamingContent: '',
        ),
      );
      return null;
    }
  }

  Future<void> updateBackgroundOpenedChat(AvatarBackgrounds bg) async {
    emit(state.copyWith(status: ChatsStatus.updating));
    final Chat chat = state.openedChat;
    final Chat updatedChat = chat.copyWith(
      avatar: chat.avatar.copyWith(background: bg),
    );
    emit(state.copyWith(openedChat: updatedChat, status: ChatsStatus.success));
    await _chatRepository.updateAvatar(chat.id, updatedChat.avatar);
  }

  void updateAvatarOpenedChat(AvatarConfig avatarConfig) async {
    emit(state.copyWith(status: ChatsStatus.updating));
    final Chat chat = state.openedChat;
    final Avatar avatar = chat.avatar.copyWith(
      hat: avatarConfig.hat ?? chat.avatar.hat,
      top: avatarConfig.top ?? chat.avatar.top,
      background: avatarConfig.background ?? chat.avatar.background,
      glasses: avatarConfig.glasses ?? chat.avatar.glasses,
      specials: avatarConfig.specials ?? chat.avatar.specials,
      costume: avatarConfig.costume ?? chat.avatar.costume,
    );
    final Chat updatedChat = chat.copyWith(avatar: avatar);
    emit(state.copyWith(openedChat: updatedChat, status: ChatsStatus.success));
    await _chatRepository.updateAvatar(chat.id, avatar);
  }
}
