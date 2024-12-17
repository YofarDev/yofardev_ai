import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/localization_manager.dart';
import '../../models/avatar.dart';
import '../../models/chat.dart';
import '../../models/chat_entry.dart';
import '../../repositories/yofardev_repository.dart';
import '../../services/chat_history_service.dart';
import '../../services/settings_service.dart';
import '../../utils/extensions.dart';
import '../../utils/platform_utils.dart';
import '../avatar/avatar_cubit.dart';
import '../talking/talking_cubit.dart';

part 'chats_state.dart';

class ChatsCubit extends Cubit<ChatsState> {
  ChatsCubit() : super(const ChatsState());



  void createNewChat(AvatarCubit avatarCubit, TalkingCubit talkingCubit) async {
    emit(state.copyWith(status: ChatsStatus.updating));
    final Chat newChat = await ChatHistoryService().createNewChat();
    emit(
      state.copyWith(
        chatsList: <Chat>[newChat, ...state.chatsList],
        status: ChatsStatus.success,
        currentChat: newChat,
      ),
    );
    avatarCubit.loadAvatar(newChat.id);
    talkingCubit.init();
  }

  void init() async {
    getCurrentChat();
    setCurrentLanguage(
      PlatformUtils.checkPlatform() == 'Web'
          ? "fr"
          : await SettingsService().getLanguage() ?? 'fr',
    );
  }

  void getCurrentChat() async {
    emit(state.copyWith(status: ChatsStatus.loading));
    final Chat currentChat = await ChatHistoryService().getCurrentChat();
    final bool soundEffectsEnabled = await SettingsService().getSoundEffects();
    emit(
      state.copyWith(
        status: ChatsStatus.success,
        currentChat: currentChat,
        soundEffectsEnabled: soundEffectsEnabled,
        currentLanguage:
            await SettingsService().getLanguage() ?? currentChat.language,
      ),
    );
  }

  void setCurrentLanguage(String language) async {
    await SettingsService().setLanguage(language);
    await LocalizationManager().initialize(language);
    emit(state.copyWith(currentLanguage: language));
  }

  void setSoundEffects(bool soundEffectsEnabled) async {
    emit(state.copyWith(soundEffectsEnabled: soundEffectsEnabled));
    await SettingsService().setSoundEffects(soundEffectsEnabled);
  }

  void fetchChatsList() async {
    emit(state.copyWith(status: ChatsStatus.loading));
    final List<Chat> chatsList =
        (await ChatHistoryService().getChatsList()).reversed.toList();
    emit(state.copyWith(status: ChatsStatus.success, chatsList: chatsList));
  }

  void deleteChat(String id) async {
    emit(state.copyWith(status: ChatsStatus.updating));
    await ChatHistoryService().deleteChat(id);
    final List<Chat> chatsList = state.chatsList;
    chatsList.removeWhere((Chat element) => element.id == id);
    emit(state.copyWith(chatsList: chatsList, status: ChatsStatus.success));
  }

  void setCurrentChat(Chat chat) {
    emit(state.copyWith(currentChat: chat));
    ChatHistoryService().setCurrentChatId(chat.id);
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
    final List<Map<String, dynamic>> functionsResults =
        await YofardevRepository().getFunctionsResults(
      lastUserMessage: lastUserMessage,
    );
    if (functionsResults.isNotEmpty) {
      final ChatEntry functionCallingEntry = ChatEntry(
        id: const Uuid().v4(),
        entryType: EntryType.functionCalling,
        body: jsonEncode(functionsResults),
        timestamp: DateTime.now(),
      );
      Chat chat = onlyText ? state.openedChat : state.currentChat;
      chat = chat.copyWith(
        entries: <ChatEntry>[...chat.entries, functionCallingEntry],
      );
      emit(
        state.copyWith(
          openedChat: onlyText ? chat : null,
          currentChat: onlyText ? null : chat,
        ),
      );
    }
    final String languageCode = await SettingsService().getLanguage() ?? 'fr';
    final String? username = await SettingsService().getUsername();
    final String wrappedUserMessage =
        "${localized.currentDate} : ${DateTime.now().toLongLocalDateString(language: languageCode)}\n${localized.currentAvatarConfig} :\n{\n$avatar\n}\n${username != null ? "${localized.currentUsername} : $username" : ''}${functionsResults.isNotEmpty ? "${localized.resultsFunctionCalling} :\n$functionsResults\n\n" : ''}${localized.userMessage} : \n'''$lastUserMessage'''";
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
        openedChat: onlyText ? chat : null,
        currentChat: onlyText ? null : chat,
      ),
    );
    final ChatEntry userEntry = await _getNewEntry(
      lastUserMessage: prompt,
      avatar: avatar,
      attachedImage: attachedImage,
      onlyText: onlyText,
    );
    chat = onlyText
        ? state.openedChat
        : state.currentChat; // need to get updated chat
    chat = chat.copyWith(entries: <ChatEntry>[...chat.entries]);
    final int index = chat.entries.indexWhere(
      (ChatEntry element) => element.id == temporaryId,
    );
    chat.entries[index] = userEntry;
    emit(
      state.copyWith(
        openedChat: onlyText ? chat : null,
        currentChat: onlyText ? null : chat,
      ),
    );
    try {
      final ChatEntry newModelEntry =
          await YofardevRepository.askYofardevAi(chat);
      final List<ChatEntry> entries = <ChatEntry>[
        ...chat.entries,
        newModelEntry,
      ];
      chat = chat.copyWith(entries: entries);
      emit(
        state.copyWith(
          openedChat: onlyText ? chat : null,
          currentChat: onlyText ? null : chat,
          status: ChatsStatus.success,
        ),
      );
      await ChatHistoryService().updateChat(
        chatId: chat.id,
        updatedChat: chat,
      );
      return newModelEntry;
    } catch (e) {
      debugPrint(e.toString());
      emit(
        state.copyWith(
          status: ChatsStatus.error,
          errorMessage: e.toString(),
        ),
      );
      return null;
    }
  }

  Future<void> updateBackgroundOpenedChat(AvatarBackgrounds bg) async {
    emit(state.copyWith(status: ChatsStatus.updating));
    final Chat chat = state.openedChat;
    emit(
      state.copyWith(
        openedChat: chat.copyWith(avatar: chat.avatar.copyWith(background: bg)),
        status: ChatsStatus.success,
      ),
    );
    await ChatHistoryService().updateAvatar(
      chat.id,
      chat.avatar.copyWith(background: bg),
    );
  }

  void updateAvatarOpenedChat(AvatarConfig avatarConfig) async {
    emit(state.copyWith(status: ChatsStatus.updating));
    final Chat chat = state.openedChat;
    final Avatar avatar = chat.avatar.copyWith(
      hat: avatarConfig.hat,
      top: avatarConfig.top,
      background: avatarConfig.background,
      glasses: avatarConfig.glasses,
      specials: avatarConfig.specials,
      costume: avatarConfig.costume,
    );
    emit(
      state.copyWith(
        openedChat: chat.copyWith(avatar: avatar),
        status: ChatsStatus.success,
      ),
    );
    await ChatHistoryService().updateAvatar(
      chat.id,
      avatar,
    );
  }
}
