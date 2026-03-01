import 'package:fpdart/fpdart.dart';
import '../models/avatar_config.dart';
import '../../../chat/domain/models/chat.dart';

abstract class AvatarRepository {
  Future<Either<Exception, Chat>> getChat(String id);
  Future<Either<Exception, void>> updateAvatar(String chatId, Avatar avatar);
}
