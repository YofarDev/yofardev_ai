import '../../../../core/models/chat.dart';
import '../../../../core/models/result.dart';

abstract interface class AvatarRepository {
  Future<Result<Chat>> getChat(String id);
}
