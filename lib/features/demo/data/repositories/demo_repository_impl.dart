import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/avatar_scene.dart';
import '../../../../core/models/chat.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/models/result.dart';
import '../../../../core/repositories/chat_repository.dart';
import '../../domain/repositories/demo_repository.dart';

/// Implementation of DemoRepository using the shared ChatRepository
/// (the app's single avatar persistence path).
class DemoRepositoryImpl implements DemoRepository {
  DemoRepositoryImpl({required this.chatRepository});

  final ChatRepository chatRepository;

  @override
  Future<Result<void>> setAvatarBackground(
    String chatId,
    AvatarScene background,
  ) async {
    try {
      // Get current chat
      final Result<Chat?> chatResult = await chatRepository.getChat(chatId);
      if (!chatResult.isOk) {
        return Result<void>.err(StorageFailure('Chat not found: $chatId'));
      }

      final Chat? chat = chatResult.getOrNull;
      if (chat == null) {
        return Result<void>.err(StorageFailure('Chat not found: $chatId'));
      }

      // Create new avatar with updated background
      final Avatar newAvatar = chat.avatar.copyWith(background: background);

      // Update avatar (persisted through ChatRepository — the single path)
      final Result<void> result = await chatRepository.updateAvatar(
        chatId,
        newAvatar,
      );
      return result;
    } catch (e, st) {
      return Result<void>.err(
        mapExceptionToFailure(e, stackTrace: st, tag: 'DemoRepository'),
      );
    }
  }

  @override
  Future<Result<String>> getCurrentChatId() async {
    try {
      final Result<Chat> chatResult = await chatRepository.getCurrentChat();
      if (!chatResult.isOk) {
        return Result<String>.err(StorageFailure('No current chat'));
      }
      final Chat chat = chatResult.getOrNull!;
      return Result<String>.ok(chat.id);
    } catch (e, st) {
      return Result<String>.err(
        mapExceptionToFailure(e, stackTrace: st, tag: 'DemoRepository'),
      );
    }
  }

  @override
  Future<Result<void>> updateChatForDemo(String chatId) async {
    // This can be used for any demo-specific chat updates
    return Result<void>.ok(null);
  }
}
