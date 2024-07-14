import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/localization_manager.dart';
import '../../models/avatar.dart';
import '../../models/chat.dart';
import '../../models/chat_entry.dart';
import '../../services/chat_history_service.dart';
import '../../services/llm_service.dart';
import '../../services/settings_service.dart';
import '../../utils/extensions.dart';
import '../avatar/avatar_cubit.dart';
import '../talking/talking_cubit.dart';

part 'chats_state.dart';

class ChatsCubit extends Cubit<ChatsState> {
  ChatsCubit() : super(const ChatsState());

  final LlmService _llmService = LlmService();

  void getCurrentChat() async {
    emit(state.copyWith(status: ChatsStatus.loading));
    final Chat currentChat = await ChatHistoryService().getCurrentChat();
    final bool soundEffectsEnabled = await SettingsService().getSoundEffects();
    final Locale deviceLocale = PlatformDispatcher.instance.locales.first;
    emit(
      state.copyWith(
        status: ChatsStatus.success,
        currentChat: currentChat,
        soundEffectsEnabled: soundEffectsEnabled,
        currentLanguage: deviceLocale.languageCode,
      ),
    );
  }

  void setCurrentLanguage(String language) async {
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

  String _addPrePrompt(Avatar avatar, String prompt) =>
      "{[${DateTime.now().toLongLocalDateString(language: state.currentLanguage)}]\n$avatar\n${localized.hiddenPart}}\n$prompt";

  Future<Map<String, dynamic>?> askYofardev(
    String prompt, {
    required bool onlyText,
    String? attachedImage,
    required Avatar avatar,
  }) async {
    Chat chat = onlyText ? state.openedChat : state.currentChat;
    final List<ChatEntry> entries = <ChatEntry>[...chat.entries];
    final ChatEntry newUserEntry = ChatEntry(
      text: _addPrePrompt(avatar, prompt),
      isFromUser: true,
      timestamp: DateTime.now(),
      attachedImage: attachedImage ?? '',
    );
    entries.add(newUserEntry);
    chat = chat.copyWith(entries: entries);
    emit(
      state.copyWith(
        openedChat: onlyText ? chat : null,
        currentChat: onlyText ? null : chat,
        status: ChatsStatus.typing,
      ),
    );
    try {
      final Map<String, dynamic> responseMap = await _llmService
          .askYofardevAi(chat, onlyText: onlyText, avatar: avatar);
      responseMap['chatId'] = chat.id;
      final String answerText =
          "${responseMap['text'] ?? ''} ${(responseMap['annotations'] as List<String>).join(' ')}";
      final ChatEntry newModelEntry = ChatEntry(
        text: answerText,
        isFromUser: false,
        timestamp: DateTime.now(),
      );
      entries.add(newModelEntry);
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
      return responseMap;
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
      top: avatarConfig.top.lastOrNull,
      bottom: avatarConfig.bottom.lastOrNull,
      background: avatarConfig.backgrounds.lastOrNull,
      glasses: avatarConfig.glasses.lastOrNull,
      specials: avatarConfig.specials.lastOrNull,
      costume: avatarConfig.costume.lastOrNull,
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
}
