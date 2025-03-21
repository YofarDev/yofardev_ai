import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/avatar.dart';
import '../models/chat.dart';
import '../repositories/yofardev_repository.dart';
import 'settings_service.dart';

class ChatHistoryService {
  Future<Chat> createNewChat() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String newChatId = DateTime.now().toIso8601String();
    final Locale deviceLocale = PlatformDispatcher.instance.locales.first;
    final ChatPersona persona = await SettingsService().getPersona();
    final Chat newChat = Chat(
      id: newChatId,
      avatar: persona.getDefaultAvatar(),
      language: deviceLocale.languageCode,
      systemPrompt: await YofardevRepository.getSystemPrompt(),
      persona: persona,
    );
    await _removeEmptyChats();
    await prefs.setString(newChatId, newChat.toJson());
    await updateChatsList(newChatId);
    await setCurrentChatId(newChatId);
    return newChat;
  }

  Future<Chat?> getChat(String chatId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? chatJson = prefs.getString(chatId);
    if (chatJson == null) return null;
    return Chat.fromJson(chatJson);
  }

  Future<void> updateChat({
    required String chatId,
    required Chat updatedChat,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(chatId, updatedChat.toJson());
    await updateChatsList(chatId);
    await setCurrentChatId(chatId);
  }

  Future<void> deleteChat(String chatId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(chatId);
    final List<String> chatsList =
        prefs.getStringList('chatsList') ?? <String>[];
    if (chatsList.contains(chatId)) {
      chatsList.remove(chatId);
      await prefs.setStringList('chatsList', chatsList);
    }
  }

  Future<void> updateChatsList(String chatId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> chatsList =
        prefs.getStringList('chatsList') ?? <String>[];
    if (!chatsList.contains(chatId)) {
      chatsList.add(chatId);
      await prefs.setStringList('chatsList', chatsList);
    }
  }

  Future<List<String>> _getHistoryIds() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> chatsList =
        prefs.getStringList('chatsList') ?? <String>[];
    return chatsList;
  }

  Future<List<Chat>> getChatsList() async {
    final List<Chat> list = <Chat>[];
    final List<String> chatIds = await _getHistoryIds();
    for (final String chatId in chatIds) {
      final Chat? chat = await getChat(chatId);
      if (chat == null) continue;
      list.add(chat);
    }
    return list;
  }

  Future<Chat> getCurrentChat() async {
    final String currentChatId = await _getCurrentChatId();
    final Chat chat = await getChat(currentChatId) ?? await createNewChat();
    return chat;
  }

  Future<String> _getCurrentChatId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String currentChat =
        prefs.getString('currentChat') ?? (await createNewChat()).id;
    return currentChat;
  }

  Future<void> setCurrentChatId(String chatId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentChat', chatId);
  }

  Future<void> updateAvatar(String chatId, Avatar avatar) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    Chat currentChat = await getChat(chatId) ?? await createNewChat();
    currentChat = currentChat.copyWith(avatar: avatar);
    await prefs.setString(chatId, currentChat.toJson());
  }

  Future<void> _removeEmptyChats() async {
    final List<String> chatIds = await _getHistoryIds();
    for (final String chatId in chatIds) {
      final Chat? chat = await getChat(chatId);
      if (chat == null || chat.entries.isEmpty) {
        await deleteChat(chatId);
      }
    }
  }
}
