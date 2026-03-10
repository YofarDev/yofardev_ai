import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/utils/logger.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../domain/models/chat.dart';
import '../../domain/repositories/chat_repository.dart';
import 'chats_state.dart';

/// Main coordinator cubit for chat operations
///
/// This cubit provides a simplified API that coordinates between
/// the specialized cubits (ChatListCubit, ChatMessageCubit, ChatTitleCubit).
class ChatsCubit extends Cubit<ChatsState> {
  ChatsCubit({
    required ChatRepository chatRepository,
    required SettingsRepository settingsRepository,
  }) : _chatRepository = chatRepository,
       _settingsRepository = settingsRepository,
       super(ChatsState.initial());

  final ChatRepository _chatRepository;
  final SettingsRepository _settingsRepository;

  /// Initialize the chat system
  Future<void> init() async {
    await getCurrentChat();
    await _loadSettings();
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
    emit(state.copyWith(status: ChatsStatus.loading));
    final Either<Exception, Chat> currentChatResult = await _chatRepository
        .getCurrentChat();

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
        emit(
          state.copyWith(
            status: ChatsStatus.success,
            currentChat: currentChat,
            openedChat: currentChat,
          ),
        );
      },
    );
  }

  /// Fetch the list of all chats
  Future<void> fetchChatsList() async {
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

  /// Create a new chat
  Future<void> createNewChat() async {
    emit(state.copyWith(status: ChatsStatus.updating));
    final Either<Exception, Chat> result = await _chatRepository.createNewChat(
      language: state.currentLanguage,
    );
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
            functionCallingEnabled: false,
          ),
        );
        emit(state.copyWith(chatCreated: false));
      },
    );
  }

  /// Delete a chat by ID
  Future<void> deleteChat(String id) async {
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

  /// Update avatar for the opened chat
  Future<void> updateAvatarOpenedChat(AvatarConfig avatarConfig) async {
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

  /// Update background for the opened chat
  Future<void> updateBackgroundOpenedChat(AvatarBackgrounds bg) async {
    emit(state.copyWith(status: ChatsStatus.updating));
    final Chat chat = state.openedChat;
    final Chat updatedChat = chat.copyWith(
      avatar: chat.avatar.copyWith(background: bg),
    );
    emit(state.copyWith(openedChat: updatedChat, status: ChatsStatus.success));
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
          tag: 'ChatsCubit',
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
          tag: 'ChatsCubit',
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
    emit(state.copyWith(status: ChatsStatus.error, errorMessage: message));
  }

  /// Reset status to success
  void resetStatus() {
    emit(state.copyWith(status: ChatsStatus.success));
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
        status: ChatsStatus.streaming,
      ),
    );
  }

  // Getters for convenience
  Chat get currentChat => state.currentChat;
  Chat get openedChat => state.openedChat;
  ChatsStatus get status => state.status;
  String get currentLanguage => state.currentLanguage;
  bool get soundEffectsEnabled => state.soundEffectsEnabled;
  bool get functionCallingEnabled => state.functionCallingEnabled;
}
