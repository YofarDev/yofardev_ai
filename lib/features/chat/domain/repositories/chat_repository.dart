import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/chat.dart';
import '../../../../core/models/result.dart';

abstract class ChatRepository {
  Future<Result<Chat>> createNewChat({String? language});
  Future<Result<Chat?>> getChat(String id);
  Future<Result<List<Chat>>> getChatsList();
  Future<Result<void>> updateChat({
    required String id,
    required Chat updatedChat,
  });
  Future<Result<void>> deleteChat(String id);
  Future<Result<void>> setCurrentChatId(String id);
  Future<Result<Chat>> getCurrentChat();
  Future<Result<void>> updateAvatar(String chatId, Avatar avatar);
}
