import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/models/chat.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/services/prompt_datasource.dart';
import '../../../../core/services/settings_local_datasource.dart';

class ChatLocalDatasource {
  static const String _chatPrefix = 'chat_';
  static const String _chatMigrationKey = 'chat_title_migration_v1';

  final SettingsLocalDatasource _settingsDatasource;
  final PromptDatasource _promptDatasource;

  ChatLocalDatasource({
    required SettingsLocalDatasource settingsDatasource,
    required PromptDatasource promptDatasource,
  }) : _settingsDatasource = settingsDatasource,
       _promptDatasource = promptDatasource;

  Future<void> init() async {
    await _migrateChatDataIfNeeded();
  }

  Future<Chat> createNewChat({String? language}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String newChatId = DateTime.now().toIso8601String();
    // Use provided language or fall back to device locale
    final String chatLanguage =
        language ?? PlatformDispatcher.instance.locales.first.languageCode;
    final ChatPersona persona = await _settingsDatasource.getPersona();
    final Avatar defaultAvatar = persona.getDefaultAvatar();
    // Use the new chat pool instead of all backgrounds
    final AvatarBackgrounds randomBackground =
        AvatarBackgroundsNewChatPool.getRandom();
    final Chat newChat = Chat(
      id: newChatId,
      avatar: defaultAvatar.copyWith(background: randomBackground),
      language: chatLanguage,
      systemPrompt: await _promptDatasource.getSystemPrompt(),
      persona: persona,
    );
    await _removeEmptyChats();
    await prefs.setString(
      '$_chatPrefix$newChatId',
      json.encode(newChat.toMap()),
    );
    await updateChatsList(newChatId);
    await setCurrentChatId(newChatId);
    return newChat;
  }

  Future<Chat?> getChat(String chatId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? chatJson = prefs.getString('$_chatPrefix$chatId');
    if (chatJson == null) return null;
    return Chat.fromMap(json.decode(chatJson) as Map<String, dynamic>);
  }

  Future<void> updateChat({
    required String chatId,
    required Chat updatedChat,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_chatPrefix$chatId',
      json.encode(updatedChat.toMap()),
    );
    await updateChatsList(chatId);
    await setCurrentChatId(chatId);
  }

  Future<void> deleteChat(String chatId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_chatPrefix$chatId');
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
    await prefs.setString(
      '$_chatPrefix$chatId',
      json.encode(currentChat.toMap()),
    );
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

  Future<void> _migrateChatDataIfNeeded() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool hasMigrated = prefs.getBool(_chatMigrationKey) ?? false;

      if (!hasMigrated) {
        AppLogger.info(
          'Starting chat title migration',
          tag: 'ChatLocalDatasource',
        );

        final List<Chat> chats = await getChatsList();

        // Add title/titleGenerated fields to all existing chats
        for (final Chat chat in chats) {
          final Chat migratedChat = chat.copyWith(
            title: chat.title.isNotEmpty ? chat.title : '',
            titleGenerated: chat.titleGenerated,
          );
          await prefs.setString(
            '$_chatPrefix${chat.id}',
            json.encode(migratedChat.toMap()),
          );
        }

        await prefs.setBool(_chatMigrationKey, true);
        AppLogger.info(
          'Chat title migration complete',
          tag: 'ChatLocalDatasource',
        );
      }
    } catch (e) {
      AppLogger.error(
        'Chat migration failed',
        tag: 'ChatLocalDatasource',
        error: e,
      );
    }
  }
}
