import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../settings/domain/repositories/settings_repository.dart';
import '../../domain/models/chat.dart';
import '../../domain/repositories/chat_repository.dart';
import 'chat_list_state.dart';

class ChatListCubit extends Cubit<ChatListState> {
  ChatListCubit({
    required ChatRepository chatRepository,
    required SettingsRepository settingsRepository,
  }) : _chatRepository = chatRepository,
       _settingsRepository = settingsRepository,
       super(ChatListState.initial());

  final ChatRepository _chatRepository;
  final SettingsRepository _settingsRepository;

  List<Chat> _cachedChats = <Chat>[];

  void init() {
    getCurrentChat();
    _loadSettings();
  }

  void _loadSettings() async {
    final Either<Exception, String?> languageResult = await _settingsRepository
        .getLanguage();
    languageResult.fold((Exception error) {}, (String? language) {
      if (language != null) {
        emit(state.copyWith(currentLanguage: language));
      }
    });

    final Either<Exception, bool> soundEffectsResult = await _settingsRepository
        .getSoundEffects();
    soundEffectsResult.fold(
      (Exception error) {},
      (bool enabled) => emit(state.copyWith(soundEffectsEnabled: enabled)),
    );
  }

  void createNewChat() async {
    emit(state.copyWith(status: ChatListStatus.updating));
    final Either<Exception, Chat> result = await _chatRepository
        .createNewChat();
    result.fold(
      (Exception error) {
        emit(
          state.copyWith(
            status: ChatListStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
      (Chat newChat) {
        _cachedChats = <Chat>[newChat, ..._cachedChats];
        emit(
          state.copyWith(
            status: ChatListStatus.success,
            chatsListIds: <String>[newChat.id, ...state.chatsListIds],
            currentChatId: newChat.id,
            openedChatId: newChat.id,
            chatCreated: true,
          ),
        );
        emit(state.copyWith(chatCreated: false));
      },
    );
  }

  void getCurrentChat() async {
    emit(state.copyWith(status: ChatListStatus.loading));
    final Either<Exception, Chat> currentChatResult = await _chatRepository
        .getCurrentChat();

    currentChatResult.fold(
      (Exception error) {
        emit(
          state.copyWith(
            status: ChatListStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
      (Chat currentChat) {
        _cachedChats = <Chat>[currentChat];
        emit(
          state.copyWith(
            status: ChatListStatus.success,
            currentChatId: currentChat.id,
            openedChatId: currentChat.id,
          ),
        );
      },
    );
  }

  Future<void> setCurrentLanguage(String language) async {
    final Either<Exception, void> result = await _settingsRepository
        .setLanguage(language);
    result.fold((Exception error) {}, (_) {
      emit(state.copyWith(currentLanguage: language));
    });
  }

  Future<void> setSoundEffects(bool soundEffectsEnabled) async {
    final Either<Exception, void> result = await _settingsRepository
        .setSoundEffects(soundEffectsEnabled);
    result.fold(
      (Exception error) {},
      (_) => emit(state.copyWith(soundEffectsEnabled: soundEffectsEnabled)),
    );
  }

  void fetchChatsList() async {
    emit(state.copyWith(status: ChatListStatus.loading));
    final Either<Exception, List<Chat>> result = await _chatRepository
        .getChatsList();
    result.fold(
      (Exception error) {
        emit(
          state.copyWith(
            status: ChatListStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
      (List<Chat> chatsList) {
        _cachedChats = chatsList.reversed.toList();
        final List<String> ids = chatsList.reversed
            .map((Chat c) => c.id)
            .toList();
        emit(state.copyWith(status: ChatListStatus.success, chatsListIds: ids));
      },
    );
  }

  void deleteChat(String id) async {
    emit(state.copyWith(status: ChatListStatus.updating));
    final Either<Exception, void> result = await _chatRepository.deleteChat(id);
    result.fold(
      (Exception error) {
        emit(
          state.copyWith(
            status: ChatListStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
      (_) {
        _cachedChats.removeWhere((Chat c) => c.id == id);
        final List<String> ids = state.chatsListIds
            .where((String i) => i != id)
            .toList();
        emit(state.copyWith(chatsListIds: ids, status: ChatListStatus.success));
      },
    );
  }

  void setCurrentChat(Chat chat) {
    emit(state.copyWith(currentChatId: chat.id));
    _chatRepository.setCurrentChatId(chat.id);
  }

  void setOpenedChat(Chat chat) {
    emit(state.copyWith(openedChatId: chat.id));
  }

  void toggleFunctionCalling() {
    emit(state.copyWith(functionCallingEnabled: !state.functionCallingEnabled));
  }

  Chat? getChatById(String id) {
    try {
      return _cachedChats.firstWhere((Chat c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Chat> get chatsList => _cachedChats;

  Chat? get currentChat {
    try {
      return _cachedChats.firstWhere((Chat c) => c.id == state.currentChatId);
    } catch (_) {
      return null;
    }
  }

  Chat? get openedChat {
    try {
      return _cachedChats.firstWhere((Chat c) => c.id == state.openedChatId);
    } catch (_) {
      return null;
    }
  }
}
