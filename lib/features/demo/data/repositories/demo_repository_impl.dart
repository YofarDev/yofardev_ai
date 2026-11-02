import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/avatar_scene.dart';
import '../../../../core/models/chat.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/models/result.dart';
import '../../../avatar/avatar.dart';
import '../../../../core/repositories/chat_repository.dart';
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

      // Update avatar
      return await avatarRepository.updateAvatar(chatId, newAvatar);
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
