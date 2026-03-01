import 'package:fpdart/fpdart.dart';
import '../models/chat.dart';
import '../models/chat_entry.dart';
import '../../../avatar/domain/models/avatar_config.dart';

abstract class ChatRepository {
  Future<Either<Exception, Chat>> createNewChat();
  Future<Either<Exception, Chat?>> getChat(String id);
  Future<Either<Exception, List<Chat>>> getChatsList();
  Future<Either<Exception, void>> updateChat({
    required String id,
    required Chat updatedChat,
  });
  Future<Either<Exception, void>> deleteChat(String id);
  Future<Either<Exception, void>> setCurrentChatId(String id);
  Future<Either<Exception, Chat>> getCurrentChat();
  Future<Either<Exception, void>> updateAvatar(String chatId, Avatar avatar);
  Future<Either<Exception, ChatEntry>> askYofardevAi(
    Chat chat,
    String userMessage, {
    bool functionCallingEnabled = true,
  });
}
