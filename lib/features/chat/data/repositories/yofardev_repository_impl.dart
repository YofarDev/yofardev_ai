// ignore_for_file: join_return_with_assignment

import 'package:fpdart/fpdart.dart';

import '../../../../core/services/agent/yofardev_agent.dart';
import '../../../../core/services/llm/fake_llm_service.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../demo/domain/models/demo_script.dart';
import '../../../../core/services/prompt_datasource.dart';
import '../../domain/models/chat.dart';
import '../../domain/models/chat_entry.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../datasources/chat_local_datasource.dart';

class YofardevRepositoryImpl implements ChatRepository {
  final YofardevAgent _agent = YofardevAgent();
  final PromptDatasource _promptService = PromptDatasource();
  final FakeLlmService _fakeLlmService = FakeLlmService();
  final ChatLocalDatasource _chatDatasource = ChatLocalDatasource();
  final SettingsRepository _settingsRepository;

  YofardevRepositoryImpl({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  @override
  Future<Either<Exception, Chat>> createNewChat() async {
    try {
      final Chat chat = await _chatDatasource.createNewChat();
      return Right<Exception, Chat>(chat);
    } catch (e) {
      return Left<Exception, Chat>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, Chat?>> getChat(String id) async {
    try {
      final Chat? chat = await _chatDatasource.getChat(id);
      return Right<Exception, Chat?>(chat);
    } catch (e) {
      return Left<Exception, Chat?>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, List<Chat>>> getChatsList() async {
    try {
      final List<Chat> chats = await _chatDatasource.getChatsList();
      return Right<Exception, List<Chat>>(chats);
    } catch (e) {
      return Left<Exception, List<Chat>>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> updateChat({
    required String id,
    required Chat updatedChat,
  }) async {
    try {
      await _chatDatasource.updateChat(chatId: id, updatedChat: updatedChat);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> deleteChat(String id) async {
    try {
      await _chatDatasource.deleteChat(id);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> setCurrentChatId(String id) async {
    try {
      await _chatDatasource.setCurrentChatId(id);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, Chat>> getCurrentChat() async {
    try {
      final Chat chat = await _chatDatasource.getCurrentChat();
      return Right<Exception, Chat>(chat);
    } catch (e) {
      return Left<Exception, Chat>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> updateAvatar(
    String chatId,
    Avatar avatar,
  ) async {
    try {
      await _chatDatasource.updateAvatar(chatId, avatar);
      return const Right<Exception, void>(null);
    } catch (e) {
      return Left<Exception, void>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, List<ChatEntry>>> askYofardevAi(
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

          return Right<Exception, List<ChatEntry>>(<ChatEntry>[
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
      return Right<Exception, List<ChatEntry>>(entries);
    } catch (e) {
      return Left<Exception, List<ChatEntry>>(Exception(e.toString()));
    }
  }
}
