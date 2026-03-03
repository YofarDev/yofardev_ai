import 'package:fpdart/fpdart.dart';

import '../../../chat/data/datasources/chat_local_datasource.dart';
import '../../../chat/domain/models/chat.dart';
import '../../domain/models/avatar_config.dart';
import '../../domain/repositories/avatar_repository.dart';

class AvatarRepositoryImpl implements AvatarRepository {
  final ChatLocalDatasource _chatDatasource = ChatLocalDatasource();

  @override
  Future<Either<Exception, Chat>> getChat(String id) async {
    try {
      final Chat? chat = await _chatDatasource.getChat(id);
      if (chat == null) {
        return Left(Exception('Chat not found'));
      }
      return Right(chat);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> updateAvatar(
    String chatId,
    Avatar avatar,
  ) async {
    try {
      await _chatDatasource.updateAvatar(chatId, avatar);
      return const Right(null);
    } catch (e) {
      return Left(Exception(e.toString()));
    }
  }
}
