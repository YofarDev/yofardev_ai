import 'package:fpdart/fpdart.dart';

import '../../../chat/domain/models/chat.dart';
import '../../../../core/models/avatar_config.dart';
import '../datasources/avatar_local_datasource.dart';
import '../../domain/repositories/avatar_repository.dart';

class AvatarRepositoryImpl implements AvatarRepository {
  final AvatarLocalDatasource _datasource;

  AvatarRepositoryImpl({required AvatarLocalDatasource datasource})
    : _datasource = datasource;

  @override
  Future<Either<Exception, Chat>> getChat(String id) async {
    try {
      final Chat? chat = await _datasource.getChat(id);
      if (chat == null) {
        return Left<Exception, Chat>(Exception('Chat not found'));
      }
      return Right<Exception, Chat>(chat);
    } catch (e) {
      return Left<Exception, Chat>(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, void>> updateAvatar(
    String chatId,
    Avatar avatar,
  ) async {
    return _datasource.updateAvatar(chatId, avatar);
  }
}
