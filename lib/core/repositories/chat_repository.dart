import '../models/avatar_config.dart';
import '../models/chat.dart';
import '../models/result.dart';

/// Stays in core: consumed by the demo feature (and chat itself); features
/// may not import another feature's internals, and chat → demo must stay
/// acyclic (demo may not depend on chat's barrel).
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
