import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/models/chat.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/models/result.dart';
import '../../domain/repositories/avatar_repository.dart';
import '../datasources/avatar_local_datasource.dart';

class AvatarRepositoryImpl implements AvatarRepository {
  final AvatarLocalDatasource _datasource;

  AvatarRepositoryImpl({required AvatarLocalDatasource datasource})
    : _datasource = datasource;

  @override
  Future<Result<Chat>> getChat(String id) async {
    try {
      final Result<Chat?> result = await _datasource.getChat(id);
      final Result<Chat> mapped = result.when(
        err: (Failure failure) => Result<Chat>.err(failure),
        ok: (Chat? chat) {
          if (chat == null) {
            return Result<Chat>.err(StorageFailure('Chat not found'));
          }
          return Result<Chat>.ok(chat);
        },
      );
      return mapped;
    } catch (e, st) {
      return Result<Chat>.err(
        mapExceptionToFailure(e, stackTrace: st, tag: 'AvatarRepository'),
      );
    }
  }
}
