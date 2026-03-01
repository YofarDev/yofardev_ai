// ignore_for_file: join_return_with_assignment

import 'package:fpdart/fpdart.dart';
import '../../../avatar/domain/models/avatar_config.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/models/chat.dart';
import '../../domain/models/chat_entry.dart';
import '../../../demo/domain/models/demo_script.dart';
import '../../../../core/services/agent/yofardev_agent.dart';
import '../../../home/data/datasources/prompt_datasource.dart';
import '../../../../core/services/llm/fake_llm_service.dart';
import '../datasources/chat_local_datasource.dart';

class YofardevRepositoryImpl implements ChatRepository {
  final YofardevAgent _agent = YofardevAgent();
  final PromptDatasource _promptService = PromptDatasource();
  final FakeLlmService _fakeLlmService = FakeLlmService();
  final ChatLocalDatasource _chatDatasource = ChatLocalDatasource();

  @override
  Future<Either<Exception, Chat>> createNewChat() async {
    try {
      final Chat chat = await _chatDatasource.createNewChat();
      return Right(chat);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, Chat?>> getChat(String id) async {
    try {
      final Chat? chat = await _chatDatasource.getChat(id);
      return Right(chat);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, List<Chat>>> getChatsList() async {
    try {
      final List<Chat> chats = await _chatDatasource.getChatsList();
      return Right(chats);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> updateChat({
    required String id,
    required Chat updatedChat,
  }) async {
    try {
      await _chatDatasource.updateChat(chatId: id, updatedChat: updatedChat);
      return const Right(null);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> deleteChat(String id) async {
    try {
      await _chatDatasource.deleteChat(id);
      return const Right(null);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> setCurrentChatId(String id) async {
    try {
      await _chatDatasource.setCurrentChatId(id);
      return const Right(null);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, Chat>> getCurrentChat() async {
    try {
      final Chat chat = await _chatDatasource.getCurrentChat();
      return Right(chat);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> updateAvatar(
    String chatId,
    Avatar avatar,
  ) async {
    try {
      await _chatDatasource.updateAvatar(chatId, avatar);
      return const Right(null);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, ChatEntry>> askYofardevAi(
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

          return Right(
            ChatEntry(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              entryType: EntryType.yofardev,
              body: fakeResponse.jsonBody,
              timestamp: DateTime.now(),
            ),
          );
        }
      }

      // Fall back to real LLM
      final entry = await _agent.ask(
        chat: chat,
        userMessage: userMessage,
        systemPrompt: await _promptService.getSystemPrompt(),
        functionCallingEnabled: functionCallingEnabled,
      );
      return Right(entry);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }
}
