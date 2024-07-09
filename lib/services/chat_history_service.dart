import 'package:shared_preferences/shared_preferences.dart';

import '../models/bg_images.dart';
import '../models/chat.dart';
import '../models/chat_entry.dart';

class ChatHistoryService {
  Future<void> saveChat({
    required String chatId,
    required String userPrompt,
    required String modelResonse,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final DateTime now = DateTime.now();
    final List<ChatEntry> fullChat = await getChat(chatId) ?? <ChatEntry>[];
    final ChatEntry userEntry =
        ChatEntry(isFromUser: true, text: userPrompt, timestamp: now);
    fullChat.add(userEntry);
    final ChatEntry modelEntry =
        ChatEntry(isFromUser: false, text: modelResonse, timestamp: now);
    fullChat.add(modelEntry);
    final List<String> chatEntries =
        fullChat.map((ChatEntry entry) => entry.toJson()).toList();
    await prefs.setStringList(chatId, chatEntries);
    await updateChatsList(chatId);
  }

  Future<List<ChatEntry>?> getChat(String chatId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String>? chatEntries = prefs.getStringList(chatId);
    if (chatEntries != null) {
      final List<ChatEntry> list = <ChatEntry>[];
      for (final String chatEntry in chatEntries) {
        list.add(ChatEntry.fromJson(chatEntry));
      }
      return list;
    }
    return null;
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

  Future<List<Chat>> getHistoryList() async {
    final List<Chat> list = <Chat>[];
    final List<String> chatIds = await _getHistoryIds();
    for (final String chatId in chatIds) {
      final List<ChatEntry> chat = await getChat(chatId) ?? <ChatEntry>[];
      list.add(
        Chat(id: chatId, entries: chat, bgImages: BgImages.mountainsAndLake),
      );
    }
    return list;
  }

  Future<String> getCurrentChatId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String currentChat =
        prefs.getString('currentChat') ?? await setNewChatId();
    return currentChat;
  }

  Future<void> setCurrentChatId(String chatId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentChat', chatId);
  }

  Future<String> setNewChatId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String newChatId = DateTime.now().toIso8601String();
    await prefs.setString('currentChat', newChatId);
    return newChatId;
  }
}
