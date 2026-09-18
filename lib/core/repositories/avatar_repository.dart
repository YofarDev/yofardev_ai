import '../models/avatar_config.dart';
import '../models/chat.dart';
import '../models/result.dart';

abstract interface class AvatarRepository {
  Future<Result<Chat>> getChat(String id);
  Future<Result<void>> updateAvatar(String chatId, Avatar avatar);
}
