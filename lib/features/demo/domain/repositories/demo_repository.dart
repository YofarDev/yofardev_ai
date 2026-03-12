import 'package:fpdart/fpdart.dart';

import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/chat.dart';
import '../../../../core/repositories/avatar_repository.dart';
import '../../../chat/domain/repositories/chat_repository.dart';

/// Repository for demo-related operations.
///
/// This interface abstracts demo operations to remove direct
/// dependencies on Cubits and BuildContext from DemoService.
abstract class DemoRepository {
  /// Sets the avatar background for a specific chat.
  Future<Either<Exception, void>> setAvatarBackground(
    String chatId,
    AvatarBackgrounds background,
  );

  /// Gets the current chat ID.
  Future<Either<Exception, String>> getCurrentChatId();

  /// Updates the current chat for demo purposes.
  Future<Either<Exception, void>> updateChatForDemo(String chatId);
}

/// Implementation of DemoRepository using ChatRepository and AvatarRepository.
class DemoRepositoryImpl implements DemoRepository {
  DemoRepositoryImpl({
    required this.chatRepository,
    required this.avatarRepository,
  });

  final ChatRepository chatRepository;
  final AvatarRepository avatarRepository;

  @override
  Future<Either<Exception, void>> setAvatarBackground(
    String chatId,
    AvatarBackgrounds background,
  ) async {
    try {
      // Get current chat
      final Either<Exception, Chat?> chatResult = await chatRepository.getChat(
        chatId,
      );
      if (chatResult.isLeft()) {
        return Left<Exception, void>(Exception('Chat not found: $chatId'));
      }

      final Chat? chat = chatResult.getOrElse((Exception _) => null);
      if (chat == null) {
        return Left<Exception, void>(Exception('Chat not found: $chatId'));
      }

      // Create new avatar with updated background
      final Avatar newAvatar = chat.avatar.copyWith(background: background);

      // Update avatar
      return avatarRepository.updateAvatar(chatId, newAvatar);
    } catch (e) {
      return Left<Exception, void>(
        Exception('Failed to set avatar background: $e'),
      );
    }
  }

  @override
  Future<Either<Exception, String>> getCurrentChatId() async {
    try {
      final Either<Exception, Chat> chatResult = await chatRepository
          .getCurrentChat();
      if (chatResult.isLeft()) {
        return Left<Exception, String>(Exception('No current chat'));
      }
      final Chat chat = chatResult.getOrElse(
        (Exception _) => throw Exception('Unreachable'),
      );
      return Right<Exception, String>(chat.id);
    } catch (e) {
      return Left<Exception, String>(
        Exception('Failed to get current chat: $e'),
      );
    }
  }

  @override
  Future<Either<Exception, void>> updateChatForDemo(String chatId) async {
    // This can be used for any demo-specific chat updates
    return const Right<Exception, void>(null);
  }
}
