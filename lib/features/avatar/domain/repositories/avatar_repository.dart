import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/chat.dart';
import '../../../../core/models/result.dart';

abstract interface class AvatarRepository {
  Future<Result<Chat>> getChat(String id);
  Future<Result<void>> updateAvatar(String chatId, Avatar avatar);
}
