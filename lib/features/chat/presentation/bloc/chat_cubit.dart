import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/models/app_lifecycle_event.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/demo_script.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/services/app_lifecycle_service.dart';
import '../../../../core/services/avatar_animation_service.dart';
import '../../../../core/services/chat/chat_streaming_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/models/chat.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/services/chat_title_service.dart';
import '../../../demo/data/repositories/demo_repository_impl.dart';
import 'chat_state.dart';

/// Main coordinator cubit for chat operations.
///
/// This cubit manages chat state and CRUD operations.
/// Streaming logic has been extracted to ChatStreamingService.
class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required ChatRepository chatRepository,
    required SettingsRepository settingsRepository,
    required AvatarAnimationService avatarAnimationService,
    required ChatTitleService chatTitleService,
    required ChatStreamingService chatStreamingService,
    required AppLifecycleService appLifecycleService,
  }) : _chatRepository = chatRepository,
       _settingsRepository = settingsRepository,
       _avatarAnimationService = avatarAnimationService,
       _chatTitleService = chatTitleService,
       _chatStreamingService = chatStreamingService,
       _appLifecycleService = appLifecycleService,
       super(ChatState.initial()) {
    // Subscribe to new chat entry events to persist avatar changes
    _newChatEntrySubscription = _appLifecycleService.newChatEntryEvents.listen(
      _handleNewChatEntryEvent,
      onError: (Object error) {
        AppLogger.error(
          'New chat entry stream error',
          tag: 'ChatCubit',
          error: error,
        );
      },
    );

    // Subscribe to demo script changed events
    _demoScriptSubscription = _appLifecycleService.demoScriptChangedEvents
        .listen(
          _handleDemoScriptChangedEvent,
          onError: (Object error) {
            AppLogger.error(
              'Demo script stream error',
              tag: 'ChatCubit',
              error: error,
            );
          },
        );
  }

  final ChatRepository _chatRepository;
  final SettingsRepository _settingsRepository;
  final AvatarAnimationService _avatarAnimationService;
  final ChatTitleService _chatTitleService;
  final ChatStreamingService _chatStreamingService;
  final AppLifecycleService _appLifecycleService;
  // ignore: unused_field
  StreamSubscription<NewChatEntryPayload>? _newChatEntrySubscription;
  // ignore: unused_field
  StreamSubscription<DemoScript>? _demoScriptSubscription;

  /// Handle new chat entry events from app lifecycle service.
  ///
  /// Persists the avatar configuration from new AI entries.
  void _handleNewChatEntryEvent(NewChatEntryPayload payload) {
    updateAvatarOpenedChat(payload.newAvatarConfig);
  }

  /// Handle demo script changed events from app lifecycle service.
  ///
  /// Activates demo mode for the current chat.
  Future<void> _handleDemoScriptChangedEvent(DemoScript script) async {
    AppLogger.info('Demo script changed to: ${script.name}', tag: 'ChatCubit');

    final DemoService demoService = getIt<DemoService>();
    final Chat currentChat = state.currentChat;

    AppLogger.info(
      'Activating demo for chat: ${currentChat.id}',
      tag: 'ChatCubit',
    );

    await demoService.activateDemo(chatId: currentChat.id, script: script);

    AppLogger.info(
      'Demo activated, FakeLlmService isActive: ${demoService.isActive}',
      tag: 'ChatCubit',
    );

    // Note: Snackbar showing is now handled by the widget layer
    // The widget should listen for state changes or use a separate notification mechanism
  }

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
          AvatarConfig(
            background: newChat.avatar.background,
            hat: newChat.avatar.hat,
            top: newChat.avatar.top,
            glasses: newChat.avatar.glasses,
            costume: newChat.avatar.costume,
          ),
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

  /// Generate a title for a chat based on its first user message.
  ///
  /// This is a convenience wrapper around ChatTitleService.
  /// Use ChatTitleService.generateTitle() directly for more control.
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
        generatingTitleChatIds: <String>{
          ...state.generatingTitleChatIds,
          chatId,
        },
      ),
    );

    try {
      final String? title = await _chatTitleService.generateTitle(chatId, chat);

      if (title != null) {
        emit(
          state.copyWith(
            lastGeneratedTitle: TitleResult(chatId: chatId, title: title),
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

  /// Check if title generation should be triggered for a chat.
  ///
  /// This is a convenience wrapper around ChatTitleService.
  /// Use ChatTitleService.shouldGenerateTitle() directly for more control.
  bool shouldGenerateTitle(Chat chat) {
    return _chatTitleService.shouldGenerateTitle(chat);
  }

  /// Streams a response from the LLM for the given prompt.
  ///
  /// Delegates to ChatStreamingService which handles:
  /// - User entry creation
  /// - Function calling
  /// - Response streaming
  /// - TTS enqueuing
  Future<void> streamResponse(
    String prompt, {
    required bool onlyText,
    String? attachedImage,
    required Avatar avatar,
    required Chat currentChat,
    required String language,
    bool functionCallingEnabled = true,
  }) async {
    emit(state.copyWith(streamingContent: '', streamingSentenceCount: 0));

    await _chatStreamingService.streamResponse(
      prompt: prompt,
      onlyText: onlyText,
      attachedImage: attachedImage,
      avatar: avatar,
      currentChat: currentChat,
      language: language,
      functionCallingEnabled: functionCallingEnabled,
      onChatUpdated: (Chat updatedChat) {
        // Update chat state during streaming
        updateChatStreaming(updatedChat);
      },
      onStreamingUpdate: (String content, int sentenceCount) {
        // Update streaming content state
        emit(
          state.copyWith(
            streamingContent: content,
            streamingSentenceCount: sentenceCount,
          ),
        );
      },
      onStreamComplete: (Chat finalChat) {
        // Stream completed successfully
        // Also update the corresponding chat in chatsList to keep it in sync
        final List<Chat> updatedChatsList = state.chatsList
            .map((Chat c) => c.id == finalChat.id ? finalChat : c)
            .toList();

        emit(
          state.copyWith(
            streamingContent: '',
            currentChat: finalChat,
            openedChat: finalChat,
            chatsList: updatedChatsList,
          ),
        );

        // Generate title if needed
        if (shouldGenerateTitle(finalChat)) {
          // Fire and forget - don't await
          generateTitle(finalChat.id, finalChat);
        }
      },
      onError: (String error) {
        // Stream failed
        emit(
          state.copyWith(
            status: ChatStatus.error,
            errorMessage: error,
            streamingContent: '',
          ),
        );
      },
    );
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
}
