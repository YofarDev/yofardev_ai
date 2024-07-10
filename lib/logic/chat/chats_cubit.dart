import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/bg_images.dart';
import '../../models/chat.dart';
import '../../models/chat_entry.dart';
import '../../services/chat_history_service.dart';
import '../../services/llm_service.dart';
import '../../utils/extensions.dart';

part 'chats_state.dart';

class ChatsCubit extends Cubit<ChatsState> {
  ChatsCubit() : super(const ChatsState());

  void getCurrentChat() async {
    emit(state.copyWith(status: ChatsStatus.loading));
    final Chat currentChat = await ChatHistoryService().getCurrentChat();
    emit(state.copyWith(status: ChatsStatus.success, currentChat: currentChat));
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
  }

  void setOpenedChat(Chat chat) {
    emit(state.copyWith(openedChat: chat));
  }

  // Text only version
  void onTextPromptSubmitted(String prompt) async {
    Chat openedChat = state.openedChat;
    final List<ChatEntry> entries = openedChat.entries;
    entries.add(
      ChatEntry(text: prompt, isFromUser: true, timestamp: DateTime.now()),
    );
    openedChat = openedChat.copyWith(entries: entries);
    emit(
      state.copyWith(
        openedChat: openedChat,
        status: ChatsStatus.typing,
      ),
    );
    final Map<String, dynamic> responseMap =
        await LlmService().askYofardevAi(prompt, openedChat);
    final String answerText =
        "${responseMap['text'] ?? ''} ${(responseMap['annotations'] as List<String>).join(' ')}";
    entries.add(
      ChatEntry(
        text: answerText,
        isFromUser: false,
        timestamp: DateTime.now(),
      ),
    );
    openedChat = openedChat.copyWith(entries: entries);

    emit(
      state.copyWith(
        openedChat: openedChat,
        status: ChatsStatus.success,
      ),
    );
    final List<BgImages> bgs =
        (responseMap['annotations'] as List<String>).getBgImages();
    if (bgs.length == 1) {
      setBgImage(bgs.first);
    }
  }

  void setBgImage(BgImages bgImage) async {
    emit(state.copyWith(status: ChatsStatus.updating));
    await ChatHistoryService().updateBgImage(state.openedChat.id, bgImage);
    final Chat chat = state.openedChat.copyWith(bgImages: bgImage);
    emit(
      state.copyWith(
        openedChat: chat,
        currentChat: state.currentChat.id == chat.id
            ? chat
            : null,
        status: ChatsStatus.success,
      ),
    );
  }

  void createNewChat() async {
    emit(state.copyWith(status: ChatsStatus.updating));
    final Chat newChat = await ChatHistoryService().createNewChat();
    emit(
      state.copyWith(
        chatsList: <Chat>[newChat, ...state.chatsList],
        status: ChatsStatus.success,
      ),
    );
  }
}
