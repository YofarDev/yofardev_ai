// ignore_for_file: join_return_with_assignment

import '../../../../core/models/failure.dart';
import '../../../../core/models/result.dart';
import '../../../../core/services/agent/yofardev_agent.dart';
import '../../../../core/services/llm/fake_llm_service.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/chat.dart';
import '../../../../core/models/chat_entry.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../datasources/chat_local_datasource.dart';

class YofardevRepositoryImpl implements ChatRepository {
  final YofardevAgent _agent;
  final FakeLlmService _fakeLlmService;
  final ChatLocalDatasource _chatDatasource;
  final SettingsRepository _settingsRepository;

  YofardevRepositoryImpl({
    required SettingsRepository settingsRepository,
    required YofardevAgent agent,
    required FakeLlmService fakeLlmService,
    required ChatLocalDatasource chatDatasource,
  }) : _settingsRepository = settingsRepository,
       _agent = agent,
       _fakeLlmService = fakeLlmService,
       _chatDatasource = chatDatasource;

  @override
  Future<Result<Chat>> createNewChat({String? language}) async {
    try {
      final Chat chat = await _chatDatasource.createNewChat(language: language);
      return Result<Chat>.ok(chat);
    } catch (e) {
      return Result<Chat>.err(NetworkFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<Chat?>> getChat(String id) async {
    try {
      final Chat? chat = await _chatDatasource.getChat(id);
      return Result<Chat?>.ok(chat);
    } catch (e) {
      return Result<Chat?>.err(NetworkFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<List<Chat>>> getChatsList() async {
    try {
      final List<Chat> chats = await _chatDatasource.getChatsList();
      return Result<List<Chat>>.ok(chats);
    } catch (e) {
      return Result<List<Chat>>.err(NetworkFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<void>> updateChat({
    required String id,
    required Chat updatedChat,
  }) async {
    try {
      await _chatDatasource.updateChat(chatId: id, updatedChat: updatedChat);
      return Result<void>.ok(null);
    } catch (e) {
      return Result<void>.err(NetworkFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<void>> deleteChat(String id) async {
    try {
      await _chatDatasource.deleteChat(id);
      return Result<void>.ok(null);
    } catch (e) {
      return Result<void>.err(NetworkFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<void>> setCurrentChatId(String id) async {
    try {
      await _chatDatasource.setCurrentChatId(id);
      return Result<void>.ok(null);
    } catch (e) {
      return Result<void>.err(NetworkFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<Chat>> getCurrentChat() async {
    try {
      final Chat chat = await _chatDatasource.getCurrentChat();
      return Result<Chat>.ok(chat);
    } catch (e) {
      return Result<Chat>.err(NetworkFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<void>> updateAvatar(
    String chatId,
    Avatar avatar,
  ) async {
    try {
      await _chatDatasource.updateAvatar(chatId, avatar);
      return Result<void>.ok(null);
    } catch (e) {
      return Result<void>.err(NetworkFailure(e.toString(), e));
    }
  }

  @override
  Future<Result<(List<ChatEntry> functionEntries, String augmentedUserMessage)>>
      prepareToolTurn({
    required Chat chat,
    required String userMessage,
  }) async {
    try {
      // In demo mode the scripted response is consumed by the streaming path
      // (FakeLlmService.promptModelStream), so the tool turn is a no-op.
      if (_fakeLlmService.isActive) {
        return Result<(List<ChatEntry>, String)>.ok(
          (<ChatEntry>[], userMessage),
        );
      }

      final (List<ChatEntry>, String) result = await _agent
          .checkAndExecuteTools(
        chat: chat,
        userMessage: userMessage,
        settingsRepository: _settingsRepository,
      );
      return Result<(List<ChatEntry>, String)>.ok(result);
    } catch (e) {
      return Result<(List<ChatEntry>, String)>.err(
        NetworkFailure(e.toString(), e),
      );
    }
  }
}
