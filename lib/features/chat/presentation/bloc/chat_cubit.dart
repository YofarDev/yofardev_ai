import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/models/app_lifecycle_event.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/avatar_scene.dart';
import '../../../../core/models/chat_entry.dart';
import '../../../../core/models/demo_script.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/models/result.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/services/app_lifecycle_service.dart';
import '../../../avatar/avatar.dart';
import '../../../../features/chat/domain/services/chat_streaming_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/models/chat.dart';
import '../../../../core/repositories/chat_repository.dart';
import '../../domain/services/chat_title_service.dart';
import '../../domain/services/global_memory_service.dart';
import '../../../demo/demo.dart';
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
    required GlobalMemoryService globalMemoryService,
    required DemoService demoService,
  }) : _chatRepository = chatRepository,
       _settingsRepository = settingsRepository,
       _avatarAnimationService = avatarAnimationService,
       _chatTitleService = chatTitleService,
       _chatStreamingService = chatStreamingService,
       _appLifecycleService = appLifecycleService,
       _globalMemoryService = globalMemoryService,
       _demoService = demoService,
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

    // Subscribe to avatar change requests from AvatarTool
    _avatarChangeRequestedSubscription = _appLifecycleService
        .avatarChangeRequestedEvents
        .listen(
          _handleAvatarChangeRequested,
          onError: (Object error) {
            AppLogger.error(
              'Avatar change requested stream error',
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
  final GlobalMemoryService _globalMemoryService;
  final DemoService _demoService;
  StreamSubscription<NewChatEntryPayload>? _newChatEntrySubscription;
  StreamSubscription<DemoScript>? _demoScriptSubscription;
  StreamSubscription<AvatarChangeRequested>? _avatarChangeRequestedSubscription;

  /// Handle avatar change requests emitted by AvatarTool.
  ///
  /// Persists the new avatar and triggers the animation.
  Future<void> _handleAvatarChangeRequested(
    AvatarChangeRequested request,
  ) async {
    AppLogger.debug(
      'ChatCubit: avatar change requested (backgroundOnly=${request.backgroundOnly})',
      tag: 'ChatCubit',
    );
    if (request.backgroundOnly) {
      await updateBackgroundOpenedChat(request.newConfig.background!);
    } else {
      await updateAvatarOpenedChat(request.newConfig);
    }
    _avatarAnimationService.emitUpdateConfig(
      state.openedChat.id,
      request.configWithAnimation,
    );
  }

  /// Handle new chat entry events from app lifecycle service.
  ///
  /// Persists the avatar configuration from new AI entries.
  void _handleNewChatEntryEvent(NewChatEntryPayload payload) {
    AppLogger.debug(
      'ChatCubit: received newChatEntry event for chat ${payload.chatId}',
      tag: 'ChatCubit',
    );

    // Extract the actual avatar config from the entry (without animation specials)
    // The payload.newAvatarConfig includes animation triggers like leaveAndComeBack
    // but we want to save only the actual avatar appearance
    final AvatarConfig actualAvatarConfig = payload.entry.getAvatarConfig();

    AppLogger.debug(
      'ChatCubit: actualAvatarConfig from entry: bg=${actualAvatarConfig.background}, top=${actualAvatarConfig.top}, hat=${actualAvatarConfig.hat}, glasses=${actualAvatarConfig.glasses}, costume=${actualAvatarConfig.costume}, specials=${actualAvatarConfig.specials}',
      tag: 'ChatCubit',
    );

    AppLogger.debug(
      'ChatCubit: current openedChat avatar: bg=${state.openedChat.avatar.background}',
      tag: 'ChatCubit',
    );

    // Update the chat with the actual avatar config
    // Use updateAvatarOpenedChat if we have changes, otherwise skip
    if (actualAvatarConfig.background != null ||
        actualAvatarConfig.hat != null ||
        actualAvatarConfig.top != null ||
        actualAvatarConfig.glasses != null ||
        actualAvatarConfig.costume != null ||
        actualAvatarConfig.topTint != null ||
        actualAvatarConfig.hatTint != null) {
      AppLogger.debug(
        'ChatCubit: calling updateAvatarOpenedChat with new avatar config',
        tag: 'ChatCubit',
      );
      updateAvatarOpenedChat(actualAvatarConfig);
    } else {
      AppLogger.debug(
        'ChatCubit: no avatar changes detected, skipping update',
        tag: 'ChatCubit',
      );
    }
  }

  /// Handle demo script changed events from app lifecycle service.
  ///
  /// Activates demo mode for the current chat.
  Future<void> _handleDemoScriptChangedEvent(DemoScript script) async {
    AppLogger.info('Demo script changed to: ${script.name}', tag: 'ChatCubit');

    final Chat currentChat = state.currentChat;

    AppLogger.info(
      'Activating demo for chat: ${currentChat.id}',
      tag: 'ChatCubit',
    );

    await _demoService.activateDemo(chatId: currentChat.id, script: script);

    AppLogger.info(
      'Demo activated, FakeLlmService isActive: ${_demoService.isActive}',
      tag: 'ChatCubit',
    );

    // Note: Snackbar showing is now handled by the widget layer
    // The widget should listen for state changes or use a separate notification mechanism
  }

  @override
  Future<void> close() async {
    await _newChatEntrySubscription?.cancel();
    await _demoScriptSubscription?.cancel();
    await _avatarChangeRequestedSubscription?.cancel();
    return super.close();
  }

  /// Announces the current chat's persona whenever another chat becomes
  /// current (or its persona changes): the avatar's body language follows
  /// it through [AppLifecycleService] (M10 ruling 10), like the mood.
  @override
  void onChange(Change<ChatState> change) {
    super.onChange(change);
    final Chat before = change.currentState.currentChat;
    final Chat after = change.nextState.currentChat;
    if (before.id != after.id || before.persona != after.persona) {
      _appLifecycleService.emitPersonaChanged(after.persona);
    }
  }

  /// Initialize the chat system
  Future<void> init() async {
    await getCurrentChat();
    await fetchChatsList();
    emit(state.copyWith(initializing: false));
  }

  /// Get the current active chat
  Future<void> getCurrentChat() async {
    emit(state.copyWith(status: ChatStatus.loading));
    final Result<Chat> currentChatResult = await _chatRepository
        .getCurrentChat();

    currentChatResult.when(
      err: (Failure failure) {
        emit(state.copyWith(status: ChatStatus.error, error: failure));
      },
      ok: (Chat currentChat) {
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
          // Notify AvatarCubit to load the avatar for this chat
          _appLifecycleService.emitChatChanged(currentChat.id);
        }
      },
    );
  }

  /// Fetch the list of all chats
  Future<void> fetchChatsList() async {
    emit(state.copyWith(status: ChatStatus.loading));
    final Result<List<Chat>> result = await _chatRepository.getChatsList();
    result.when(
      err: (Failure failure) {
        emit(state.copyWith(status: ChatStatus.error, error: failure));
      },
      ok: (List<Chat> chatsList) {
        final List<Chat> reversed = chatsList.reversed.toList();
        emit(state.copyWith(status: ChatStatus.success, chatsList: reversed));
      },
    );
  }

  /// Create a new chat
  Future<void> createNewChat() async {
    emit(state.copyWith(status: ChatStatus.updating));
    final String language = await _settingsRepository.getLanguage().then(
      (Result<String?> result) => result.getOrNull ?? 'fr',
    );
    final Result<Chat> result = await _chatRepository.createNewChat(
      language: language,
    );
    result.when(
      err: (Failure failure) {
        emit(state.copyWith(status: ChatStatus.error, error: failure));
      },
      ok: (Chat newChat) async {
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
            topTint: newChat.avatar.topTint,
            hatTint: newChat.avatar.hatTint,
          ),
        );
      },
    );
  }

  /// Delete a chat by ID
  Future<void> deleteChat(String id) async {
    emit(state.copyWith(status: ChatStatus.updating));
    final Result<void> result = await _chatRepository.deleteChat(id);
    result.when(
      err: (Failure failure) {
        emit(state.copyWith(status: ChatStatus.error, error: failure));
      },
      ok: (_) {
        final List<Chat> chatsList = List<Chat>.from(state.chatsList);
        chatsList.removeWhere((Chat element) => element.id == id);
        emit(state.copyWith(chatsList: chatsList, status: ChatStatus.success));
      },
    );
  }

  /// Update avatar for the opened chat
  Future<void> updateAvatarOpenedChat(AvatarConfig avatarConfig) async {
    AppLogger.debug(
      'ChatCubit.updateAvatarOpenedChat: called with bg=${avatarConfig.background}, top=${avatarConfig.top}, hat=${avatarConfig.hat}',
      tag: 'ChatCubit',
    );
    emit(state.copyWith(status: ChatStatus.updating));
    final Chat chat = state.openedChat;
    final Avatar avatar = chat.avatar.copyWith(
      hat: avatarConfig.hat ?? chat.avatar.hat,
      top: avatarConfig.top ?? chat.avatar.top,
      background: avatarConfig.background ?? chat.avatar.background,
      glasses: avatarConfig.glasses ?? chat.avatar.glasses,
      specials: avatarConfig.specials ?? chat.avatar.specials,
      costume: avatarConfig.costume ?? chat.avatar.costume,
      topTint: avatarConfig.topTint ?? chat.avatar.topTint,
      hatTint: avatarConfig.hatTint ?? chat.avatar.hatTint,
    );
    final Chat updatedChat = chat.copyWith(avatar: avatar);

    // Update both openedChat and currentChat since both are used throughout the app
    // Also update chatsList to keep it in sync
    final List<Chat> updatedChatsList = state.chatsList
        .map((Chat c) => c.id == updatedChat.id ? updatedChat : c)
        .toList();

    AppLogger.debug(
      'ChatCubit.updateAvatarOpenedChat: saving to repository, chat.id=${chat.id}, new avatar bg=${avatar.background}',
      tag: 'ChatCubit',
    );
    final Result<void> saveResult = await _chatRepository.updateAvatar(
      chat.id,
      avatar,
    );
    if (isClosed) {
      return;
    }
    saveResult.when(
      err: (Failure failure) {
        AppLogger.error(
          'Failed to save avatar change for chat ${chat.id}',
          error: failure,
          tag: 'ChatCubit',
        );
        emit(state.copyWith(status: ChatStatus.error, error: failure));
      },
      ok: (_) {
        emit(
          state.copyWith(
            openedChat: updatedChat,
            currentChat: updatedChat,
            chatsList: updatedChatsList,
            status: ChatStatus.success,
          ),
        );
      },
    );

    AppLogger.debug(
      'ChatCubit.updateAvatarOpenedChat: completed, state.currentChat.avatar.bg=${state.currentChat.avatar.background}',
      tag: 'ChatCubit',
    );
  }

  /// Update background for the opened chat
  Future<void> updateBackgroundOpenedChat(AvatarScene bg) async {
    emit(state.copyWith(status: ChatStatus.updating));
    final Chat chat = state.openedChat;
    final Chat updatedChat = chat.copyWith(
      avatar: chat.avatar.copyWith(background: bg),
    );

    // Update both openedChat and currentChat since both are used throughout the app
    // Also update chatsList to keep it in sync
    final List<Chat> updatedChatsList = state.chatsList
        .map((Chat c) => c.id == updatedChat.id ? updatedChat : c)
        .toList();

    final Result<void> saveResult = await _chatRepository.updateAvatar(
      chat.id,
      updatedChat.avatar,
    );
    if (isClosed) {
      return;
    }
    saveResult.when(
      err: (Failure failure) {
        AppLogger.error(
          'Failed to save background change for chat ${chat.id}',
          error: failure,
          tag: 'ChatCubit',
        );
        emit(state.copyWith(status: ChatStatus.error, error: failure));
      },
      ok: (_) {
        emit(
          state.copyWith(
            openedChat: updatedChat,
            currentChat: updatedChat,
            chatsList: updatedChatsList,
            status: ChatStatus.success,
          ),
        );
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

  /// Reset status to success
  void resetStatus() {
    emit(state.copyWith(status: ChatStatus.success));
  }

  /// Update the chat state (both current and opened) without saving to the repo
  /// Ideal for rapid real-time streaming updates
  ///
  /// The streamed chat was captured when the message was sent: it keeps the
  /// opened chat's avatar, which a tool (`change_avatar`) may have changed
  /// since.
  void updateChatStreaming(Chat chat) {
    if (isClosed) return;
    final Chat streamed = chat.id == state.openedChat.id
        ? chat.copyWith(avatar: state.openedChat.avatar)
        : chat;
    // Also update the corresponding chat in chatsList to keep it in sync
    final List<Chat> updatedChatsList = state.chatsList
        .map((Chat c) => c.id == streamed.id ? streamed : c)
        .toList();

    emit(
      state.copyWith(
        currentChat: streamed,
        openedChat: streamed,
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
        // Reload the chat from storage to get the updated title
        final Result<Chat?> chatResult = await _chatRepository.getChat(chatId);

        chatResult.when(
          err: (Failure failure) {
            AppLogger.error(
              'Failed to reload chat after title generation',
              tag: 'ChatCubit',
              error: failure,
            );
          },
          ok: (Chat? updatedChat) {
            if (isClosed) return;
            if (updatedChat != null) {
              // Update currentChat and openedChat if this is the current chat
              final Chat? currentChat = state.currentChat.id == chatId
                  ? updatedChat
                  : null;
              final Chat? openedChat = state.openedChat.id == chatId
                  ? updatedChat
                  : null;

              // Update the chat in chatsList
              final List<Chat> updatedChatsList = state.chatsList
                  .map((Chat c) => c.id == chatId ? updatedChat : c)
                  .toList();

              emit(
                state.copyWith(
                  lastGeneratedTitle: TitleResult(chatId: chatId, title: title),
                  currentChat: currentChat ?? state.currentChat,
                  openedChat: openedChat ?? state.openedChat,
                  chatsList: updatedChatsList,
                ),
              );
            } else {
              emit(
                state.copyWith(
                  lastGeneratedTitle: TitleResult(chatId: chatId, title: title),
                ),
              );
            }
          },
        );
      }
    } finally {
      // Remove from generating set
      final Set<String> updatedIds = state.generatingTitleChatIds.toSet()
        ..remove(chatId);
      if (!isClosed) {
        emit(state.copyWith(generatingTitleChatIds: updatedIds));
      }
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
    // Set status to typing to show typing animation
    AppLogger.debug(
      'Setting status to typing, current status: ${state.status}',
      tag: 'ChatCubit',
    );
    emit(state.copyWith(status: ChatStatus.typing));
    AppLogger.debug('Status after emit: ${state.status}', tag: 'ChatCubit');
    _appLifecycleService.emitStreamingStateChanged(ChatStatus.typing);

    try {
      await _streamWith(
        prompt,
        onlyText: onlyText,
        attachedImage: attachedImage,
        avatar: avatar,
        currentChat: currentChat,
        language: language,
        functionCallingEnabled: functionCallingEnabled,
      );
    } catch (e, stackTrace) {
      // A failure outside the service's own error path (before its stream
      // starts): end the reply like any other failure.
      AppLogger.error(
        'streamResponse failed',
        tag: 'ChatCubit',
        error: e,
        stackTrace: stackTrace,
      );
      _failReply(UnknownFailure(e.toString(), e));
    }
  }

  /// Ends a failed reply: the error state for the UI, and the error
  /// streaming state so the talking state leaves "generating" (the avatar's
  /// thought bubble and the Stage orb's thinking).
  void _failReply(Failure failure) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: ChatStatus.error,
        error: failure,
        activeTool: null,
      ),
    );
    _appLifecycleService.emitStreamingStateChanged(ChatStatus.error);
  }

  Future<void> _streamWith(
    String prompt, {
    required bool onlyText,
    String? attachedImage,
    required Avatar avatar,
    required Chat currentChat,
    required String language,
    required bool functionCallingEnabled,
  }) async {
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
      onStreamComplete: (Chat finalChat) {
        if (isClosed) return;
        // Stream completed successfully
        // Also update the corresponding chat in chatsList to keep it in sync
        final List<Chat> updatedChatsList = state.chatsList
            .map((Chat c) => c.id == finalChat.id ? finalChat : c)
            .toList();

        emit(
          state.copyWith(
            currentChat: finalChat,
            openedChat: finalChat,
            chatsList: updatedChatsList,
            status: ChatStatus.success,
            activeTool: null,
          ),
        );
        _appLifecycleService.emitStreamingStateChanged(ChatStatus.success);

        // Trigger avatar animation if the last entry contains avatar changes
        if (finalChat.entries.isNotEmpty) {
          final ChatEntry lastEntry = finalChat.entries.last;
          if (lastEntry.entryType == EntryType.yofardev) {
            // Get the current avatar config before the change
            final AvatarConfig currentAvatarConfig = AvatarConfig(
              background: finalChat.avatar.background,
              hat: finalChat.avatar.hat,
              top: finalChat.avatar.top,
              glasses: finalChat.avatar.glasses,
              costume: finalChat.avatar.costume,
              topTint: finalChat.avatar.topTint,
              hatTint: finalChat.avatar.hatTint,
              specials: finalChat.avatar.specials,
            );

            // Emit event to trigger avatar animation
            _appLifecycleService.emitNewChatEntry(
              lastEntry,
              finalChat.id,
              currentAvatarConfig,
            );
          }
        }

        // Generate title if needed
        if (shouldGenerateTitle(finalChat)) {
          // Fire and forget - don't await
          generateTitle(finalChat.id, finalChat);
        }

        // Update the global memory from this exchange
        // Fire and forget - don't await
        unawaited(_globalMemoryService.updateMemory(finalChat));
      },
      onError: (String error) => _failReply(UnknownFailure(error, error)),
      onToolActivity: (String? toolName) {
        if (isClosed) return;
        emit(state.copyWith(activeTool: toolName));
      },
      // The avatar a tool set mid-reply (updateAvatarOpenedChat) is kept in
      // the completed and stored chat.
      currentAvatar: () => state.openedChat.id == currentChat.id
          ? state.openedChat.avatar
          : currentChat.avatar,
    );
  }

  // Getters for convenience
  Chat get currentChat => state.currentChat;
  Chat get openedChat => state.openedChat;
  ChatStatus get status => state.status;
  bool get functionCallingEnabled => state.functionCallingEnabled;

  /// Get a chat by its ID from the chats list
  Chat? getChatById(String id) {
    try {
      return state.chatsList.firstWhere((Chat c) => c.id == id);
    } catch (e) {
      AppLogger.debug(
        'Chat with id $id not found in chats list: $e',
        tag: 'ChatCubit',
      );
      return null;
    }
  }
}
