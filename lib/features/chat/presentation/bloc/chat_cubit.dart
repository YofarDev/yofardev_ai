import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/audio/interruption_service.dart';
import '../../../../core/services/avatar_animation_service.dart';
import '../../../../core/services/llm/llm_service_interface.dart';
import '../../../../core/services/prompt_datasource.dart';
import '../../../../core/services/stream_processor/sentence_chunk.dart';
import '../../../../core/services/stream_processor/stream_processor_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/llm_config.dart';
import '../../../../core/models/voice_effect.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../../../core/services/audio/tts_queue_service.dart';
import '../../domain/models/chat.dart';
import '../../domain/models/chat_entry.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/services/chat_entry_service.dart';
import '../../domain/services/chat_title_service.dart';
import 'chat_state.dart';

/// Main coordinator cubit for chat operations
///
/// This cubit provides a simplified API that coordinates between
/// the specialized cubits (ChatMessageCubit, ChatTitleCubit).
class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required ChatRepository chatRepository,
    required SettingsRepository settingsRepository,
    required AvatarAnimationService avatarAnimationService,
    required ChatTitleService chatTitleService,
    required LlmServiceInterface llmService,
    required StreamProcessorService streamProcessor,
    required PromptDatasource promptDatasource,
    required InterruptionService interruptionService,
    required ChatEntryService chatEntryService,
    TtsQueueService? ttsQueueManager,
  }) : _chatRepository = chatRepository,
       _settingsRepository = settingsRepository,
       _avatarAnimationService = avatarAnimationService,
       _chatTitleService = chatTitleService,
       _llmService = llmService,
       _streamProcessor = streamProcessor,
       _promptDatasource = promptDatasource,
       _interruptionService = interruptionService,
       _chatEntryService = chatEntryService,
       _ttsQueueManager = ttsQueueManager,
       super(ChatState.initial()) {
    // Listen to interruption stream
    _interruptionSubscription = _interruptionService.interruptionStream.listen((
      _,
    ) {
      _streamInterrupted = true;
      if (state.status == ChatStatus.streaming) {
        emit(
          state.copyWith(
            streamingContent: '',
          ),
        );
      }
    });
  }

  final ChatRepository _chatRepository;
  final SettingsRepository _settingsRepository;
  final AvatarAnimationService _avatarAnimationService;
  final ChatTitleService _chatTitleService;
  final LlmServiceInterface _llmService;
  final StreamProcessorService _streamProcessor;
  final PromptDatasource _promptDatasource;
  final InterruptionService _interruptionService;
  final ChatEntryService _chatEntryService;
  final TtsQueueService? _ttsQueueManager;

  bool _streamInterrupted = false;
  StreamSubscription<void>? _interruptionSubscription;

  /// Initialize the chat system
  Future<void> init() async {
    await getCurrentChat();
    await _loadSettings();
    await fetchChatsList();
    emit(state.copyWith(initializing: false));
  }

  /// Load user settings (language, sound effects)
  Future<void> _loadSettings() async {
    final Either<Exception, String?> languageResult = await _settingsRepository
        .getLanguage();
    languageResult.fold(
      (Exception error) => emit(state.copyWith(currentLanguage: 'fr')),
      (String? language) =>
          emit(state.copyWith(currentLanguage: language ?? 'fr')),
    );

    final Either<Exception, bool> soundEffectsResult = await _settingsRepository
        .getSoundEffects();
    soundEffectsResult.fold(
      (Exception error) => emit(state.copyWith(soundEffectsEnabled: false)),
      (bool enabled) => emit(state.copyWith(soundEffectsEnabled: enabled)),
    );
  }

  /// Get the current active chat
  Future<void> getCurrentChat() async {
    emit(state.copyWith(status: ChatStatus.loading));
    final Either<Exception, Chat> currentChatResult = await _chatRepository
        .getCurrentChat();

    currentChatResult.fold(
      (Exception error) {
        emit(
          state.copyWith(
            status: ChatStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
      (Chat currentChat) {
        // Only update if user hasn't created a chat during initialization
        // This prevents race condition where getCurrentChat overwrites user's new chat
        if (state.userCreatedChatDuringInit) {
          // User already created a chat, keep their chat and just update status
          emit(state.copyWith(status: ChatStatus.success));
        } else {
          // Normal initialization, set the current chat from storage
          emit(
            state.copyWith(
              status: ChatStatus.success,
              currentChat: currentChat,
              openedChat: currentChat,
            ),
          );
        }
      },
    );
  }

  /// Fetch the list of all chats
  Future<void> fetchChatsList() async {
    emit(state.copyWith(status: ChatStatus.loading));
    final Either<Exception, List<Chat>> result = await _chatRepository
        .getChatsList();
    result.fold(
      (Exception error) {
        emit(
          state.copyWith(
            status: ChatStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
      (List<Chat> chatsList) {
        final List<Chat> reversed = chatsList.reversed.toList();
        emit(state.copyWith(status: ChatStatus.success, chatsList: reversed));
      },
    );
  }

  /// Create a new chat
  Future<void> createNewChat() async {
    emit(state.copyWith(status: ChatStatus.updating));
    final Either<Exception, Chat> result = await _chatRepository.createNewChat(
      language: state.currentLanguage,
    );
    result.fold(
      (Exception error) {
        emit(
          state.copyWith(
            status: ChatStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
      (Chat newChat) async {
        // If creating chat during initialization, set the flag
        // This prevents getCurrentChat from overwriting this new chat
        final bool wasInitializing = state.initializing;

        emit(
          state.copyWith(
            status: ChatStatus.success,
            chatsList: <Chat>[newChat, ...state.chatsList],
            currentChat: newChat,
            openedChat: newChat,
            chatCreated: true,
            functionCallingEnabled: false,
            userCreatedChatDuringInit: wasInitializing,
          ),
        );
        emit(state.copyWith(chatCreated: false));

        // Trigger animation sequence
        await _avatarAnimationService.playNewChatSequence(
          newChat.id,
          AvatarConfig(background: newChat.avatar.background),
        );
      },
    );
  }

  /// Delete a chat by ID
  Future<void> deleteChat(String id) async {
    emit(state.copyWith(status: ChatStatus.updating));
    final Either<Exception, void> result = await _chatRepository.deleteChat(id);
    result.fold(
      (Exception error) {
        emit(
          state.copyWith(
            status: ChatStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
      (_) {
        final List<Chat> chatsList = List<Chat>.from(state.chatsList);
        chatsList.removeWhere((Chat element) => element.id == id);
        emit(state.copyWith(chatsList: chatsList, status: ChatStatus.success));
      },
    );
  }

  /// Update avatar for the opened chat
  Future<void> updateAvatarOpenedChat(AvatarConfig avatarConfig) async {
    emit(state.copyWith(status: ChatStatus.updating));
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
    emit(state.copyWith(openedChat: updatedChat, status: ChatStatus.success));
    await _chatRepository.updateAvatar(chat.id, avatar);
  }

  /// Update background for the opened chat
  Future<void> updateBackgroundOpenedChat(AvatarBackgrounds bg) async {
    emit(state.copyWith(status: ChatStatus.updating));
    final Chat chat = state.openedChat;
    final Chat updatedChat = chat.copyWith(
      avatar: chat.avatar.copyWith(background: bg),
    );
    emit(state.copyWith(openedChat: updatedChat, status: ChatStatus.success));
    await _chatRepository.updateAvatar(chat.id, updatedChat.avatar);
  }

  /// Set the current language
  Future<void> setCurrentLanguage(String language) async {
    final Either<Exception, void> result = await _settingsRepository
        .setLanguage(language);
    result.fold(
      (Exception error) {
        AppLogger.error(
          'Failed to set language',
          tag: 'ChatCubit',
          error: error,
        );
      },
      (_) {
        emit(state.copyWith(currentLanguage: language));
      },
    );
  }

  /// Set sound effects enabled/disabled
  Future<void> setSoundEffects(bool soundEffectsEnabled) async {
    final Either<Exception, void> result = await _settingsRepository
        .setSoundEffects(soundEffectsEnabled);
    result.fold(
      (Exception error) {
        AppLogger.error(
          'Failed to set sound effects',
          tag: 'ChatCubit',
          error: error,
        );
      },
      (_) {
        emit(state.copyWith(soundEffectsEnabled: soundEffectsEnabled));
      },
    );
  }

  /// Toggle function calling feature
  void toggleFunctionCalling() {
    emit(state.copyWith(functionCallingEnabled: !state.functionCallingEnabled));
  }

  /// Update the current chat reference
  void setCurrentChat(Chat chat) {
    emit(state.copyWith(currentChat: chat));
    _chatRepository.setCurrentChatId(chat.id);
  }

  /// Update the opened chat reference
  void setOpenedChat(Chat chat) {
    emit(state.copyWith(openedChat: chat));
  }

  /// Clear streaming content (called when stream completes)
  void clearStreamingContent() {
    emit(state.copyWith(streamingContent: '', streamingSentenceCount: 0));
  }

  /// Update error message
  void setError(String message) {
    emit(state.copyWith(status: ChatStatus.error, errorMessage: message));
  }

  /// Reset status to success
  void resetStatus() {
    emit(state.copyWith(status: ChatStatus.success));
  }

  /// Update the chat state (both current and opened) without saving to the repo
  /// Ideal for rapid real-time streaming updates
  void updateChatStreaming(Chat chat) {
    // Also update the corresponding chat in chatsList to keep it in sync
    final List<Chat> updatedChatsList = state.chatsList
        .map((Chat c) => c.id == chat.id ? chat : c)
        .toList();

    emit(
      state.copyWith(
        currentChat: chat,
        openedChat: chat,
        chatsList: updatedChatsList,
        status: ChatStatus.streaming,
      ),
    );
  }

  /// Generate a title for a chat based on its first user message
  Future<void> generateTitle(String chatId, Chat chat) async {
    // Prevent duplicate generation attempts
    if (state.generatingTitleChatIds.contains(chatId)) {
      AppLogger.debug(
        'Already generating title for chat $chatId, skipping',
        tag: 'ChatCubit',
      );
      return;
    }

    // Add to generating set
    emit(
      state.copyWith(
        generatingTitleChatIds: <String>{...state.generatingTitleChatIds, chatId},
      ),
    );

    try {
      final String? title = await _chatTitleService.generateTitle(chatId, chat);

      if (title != null) {
        emit(
          state.copyWith(
            lastGeneratedTitle: TitleResult(
              chatId: chatId,
              title: title,
            ),
          ),
        );
      }
    } finally {
      // Remove from generating set
      final Set<String> updatedIds = state.generatingTitleChatIds.toSet()
        ..remove(chatId);
      emit(state.copyWith(generatingTitleChatIds: updatedIds));
    }
  }

  /// Check if title generation should be triggered for a chat
  bool shouldGenerateTitle(Chat chat) {
    return _chatTitleService.shouldGenerateTitle(chat);
  }

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
            status: ChatStatus.error,
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
              tag: 'ChatCubit',
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
              streamingContent: '',
            ),
          );
          await _chatRepository.updateChat(id: chat.id, updatedChat: chat);

          // Generate title if needed
          if (shouldGenerateTitle(chat)) {
            // Fire and forget - don't await
            generateTitle(chat.id, chat);
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
              tag: 'ChatCubit',
            );
          },
          error: (String msg) {
            AppLogger.error('Stream error: $msg', tag: 'ChatCubit');
          },
        );
      }

      if (_streamInterrupted || _interruptionService.isInterrupted) {
        emit(
          state.copyWith(
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
          streamingContent: '',
        ),
      );

      await _chatRepository.updateChat(id: chat.id, updatedChat: chat);

      if (shouldGenerateTitle(chat)) {
        // Fire and forget - don't await
        generateTitle(chat.id, chat);
      }

      return;
    } catch (e) {
      AppLogger.error(
        'Error in streaming message',
        tag: 'ChatCubit',
        error: e,
      );
      emit(
        state.copyWith(
          status: ChatStatus.error,
          errorMessage: e.toString(),
          streamingContent: '',
        ),
      );
      return;
    }
  }

  // Getters for convenience
  Chat get currentChat => state.currentChat;
  Chat get openedChat => state.openedChat;
  ChatStatus get status => state.status;
  String get currentLanguage => state.currentLanguage;
  bool get soundEffectsEnabled => state.soundEffectsEnabled;
  bool get functionCallingEnabled => state.functionCallingEnabled;

  /// Get a chat by its ID from the chats list
  Chat? getChatById(String id) {
    try {
      return state.chatsList.firstWhere((Chat c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() async {
    await _interruptionSubscription?.cancel();
    return super.close();
  }
}
