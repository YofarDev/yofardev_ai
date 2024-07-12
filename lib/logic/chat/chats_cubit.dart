import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/avatar.dart';
import '../../models/avatar_backgrounds.dart';
import '../../models/chat.dart';
import '../../models/chat_entry.dart';
import '../../services/chat_history_service.dart';
import '../../services/llm_service.dart';
import '../../utils/extensions.dart';
import '../avatar/avatar_cubit.dart';

part 'chats_state.dart';

class ChatsCubit extends Cubit<ChatsState> {
  ChatsCubit() : super(const ChatsState());

  final LlmService _llmService = LlmService();


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
    ChatHistoryService().setCurrentChatId(chat.id);
  }

  void setOpenedChat(Chat chat) {
    emit(state.copyWith(openedChat: chat));
  }

  String _addPrePrompt(Avatar avatar, String prompt) =>
      "{[${DateTime.now().toLongLocalDateString()}]\n$avatar[${state.currentChat.bg}]\nCette partie n'est pas visible par l'utilisateur, n'en tenez pas compte dans votre réponse.}\n$prompt";

  Future<Map<String, dynamic>> askYofardev(
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
    final Map<String, dynamic> responseMap = await _llmService
        .askYofardevAi(chat, onlyText: onlyText, avatar: avatar);
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
    if (onlyText) {
      final List<AvatarBackgrounds> bgs =
          (responseMap['annotations'] as List<String>).getBgImages();
      if (bgs.length == 1) {
        setBgImage(bgs.first);
      }
    }
    return responseMap;
  }

  void setBgImage(AvatarBackgrounds bgImage, {bool currentOnly = false}) async {
    emit(state.copyWith(status: ChatsStatus.updating));
    await ChatHistoryService().updateBgImage(
      currentOnly ? state.currentChat.id : state.openedChat.id,
      bgImage,
    );
    Chat chat = currentOnly ? state.currentChat : state.openedChat;
    chat = chat.copyWith(bg: bgImage);
    emit(
      state.copyWith(
        openedChat: currentOnly ? null : chat,
        currentChat: state.currentChat.id == chat.id
            ? chat
            : currentOnly
                ? chat
                : null,
        status: ChatsStatus.success,
      ),
    );
  }

  void createNewChat(AvatarCubit avatarCubit) async {
    emit(state.copyWith(status: ChatsStatus.updating));
    final Chat newChat = await ChatHistoryService().createNewChat();
    emit(
      state.copyWith(
        chatsList: <Chat>[newChat, ...state.chatsList],
        status: ChatsStatus.success,
        currentChat: newChat,
      ),
    );
    avatarCubit.resetAvatar();
  }
}
