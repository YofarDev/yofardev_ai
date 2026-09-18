import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/chat.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/models/result.dart';
import '../../../../core/repositories/avatar_repository.dart';
import '../../../chat/chat.dart';
import '../../domain/repositories/demo_repository.dart';

/// Implementation of DemoRepository using ChatRepository and AvatarRepository.
class DemoRepositoryImpl implements DemoRepository {
  DemoRepositoryImpl({
    required this.chatRepository,
    required this.avatarRepository,
  });

  final ChatRepository chatRepository;
  final AvatarRepository avatarRepository;

  @override
  Future<Result<void>> setAvatarBackground(
    String chatId,
    AvatarBackgrounds background,
  ) async {
    try {
      // Get current chat
      final Result<Chat?> chatResult = await chatRepository.getChat(
        chatId,
      );
      if (!chatResult.isOk) {
        return Result<void>.err(StorageFailure('Chat not found: $chatId'));
      }

      final Chat? chat = chatResult.getOrNull;
      if (chat == null) {
        return Result<void>.err(StorageFailure('Chat not found: $chatId'));
      }

      // Create new avatar with updated background
      final Avatar newAvatar = chat.avatar.copyWith(background: background);

      // Update avatar
      return avatarRepository.updateAvatar(chatId, newAvatar);
    } catch (e) {
      return Result<void>.err(
        Failure.fromException(e),
      );
    }
  }

  @override
  Future<Result<String>> getCurrentChatId() async {
    try {
      final Result<Chat> chatResult = await chatRepository
          .getCurrentChat();
      if (!chatResult.isOk) {
        return Result<String>.err(StorageFailure('No current chat'));
      }
      final Chat chat = chatResult.getOrNull!;
      return Result<String>.ok(chat.id);
    } catch (e) {
      return Result<String>.err(
        StorageFailure('Failed to get current chat', e),
      );
    }
  }

  @override
  Future<Result<void>> updateChatForDemo(String chatId) async {
    // This can be used for any demo-specific chat updates
    return Result<void>.ok(null);
  }
}
