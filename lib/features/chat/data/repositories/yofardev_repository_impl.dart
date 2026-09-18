// ignore_for_file: join_return_with_assignment

import '../../../../core/models/failure.dart';
import '../../../../core/models/result.dart';
import '../../../../core/services/agent/yofardev_agent.dart';
import '../../../../core/services/llm/fake_llm_service.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/chat.dart';
import '../../../../core/models/chat_entry.dart';
import '../../../../core/models/demo_script.dart';
import '../../../../core/services/prompt_datasource.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../datasources/chat_local_datasource.dart';

class YofardevRepositoryImpl implements ChatRepository {
  final YofardevAgent _agent;
  final PromptDatasource _promptService;
  final FakeLlmService _fakeLlmService;
  final ChatLocalDatasource _chatDatasource;
  final SettingsRepository _settingsRepository;

  YofardevRepositoryImpl({
    required SettingsRepository settingsRepository,
    required YofardevAgent agent,
    required PromptDatasource promptService,
    required FakeLlmService fakeLlmService,
    required ChatLocalDatasource chatDatasource,
  }) : _settingsRepository = settingsRepository,
       _agent = agent,
       _promptService = promptService,
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
  Future<Result<List<ChatEntry>>> askYofardevAi(
    Chat chat,
    String userMessage, {
    bool functionCallingEnabled = true,
  }) async {
    try {
      // Check if fake LLM service has a scripted response
      if (_fakeLlmService.isActive) {
        final FakeLlmResponse? fakeResponse = _fakeLlmService.getNextResponse();
        if (fakeResponse != null) {
          // Wait 600ms to simulate LLM processing
          await Future<void>.delayed(const Duration(milliseconds: 600));

          return Result<List<ChatEntry>>.ok(<ChatEntry>[
            ChatEntry(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              entryType: EntryType.yofardev,
              body: fakeResponse.jsonBody,
              timestamp: DateTime.now(),
            ),
          ]);
        }
      }

      // Fall back to real LLM
      final List<ChatEntry> entries = await _agent.ask(
        chat: chat,
        userMessage: userMessage,
        systemPrompt: await _promptService.getSystemPrompt(),
        functionCallingEnabled: functionCallingEnabled,
        settingsRepository: _settingsRepository,
      );
      return Result<List<ChatEntry>>.ok(entries);
    } catch (e) {
      return Result<List<ChatEntry>>.err(NetworkFailure(e.toString(), e));
    }
  }
}
