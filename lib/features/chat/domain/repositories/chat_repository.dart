import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/chat.dart';
import '../../../../core/models/chat_entry.dart';
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
  /// Detects and executes tools for the turn without generating the final
  /// answer. Returns the function-calling entries (empty if no tools were
  /// called) and the user message augmented with tool results (unchanged if
  /// no tools were called).
  Future<Result<(List<ChatEntry> functionEntries, String augmentedUserMessage)>>
      prepareToolTurn({
    required Chat chat,
    required String userMessage,
  });
}
