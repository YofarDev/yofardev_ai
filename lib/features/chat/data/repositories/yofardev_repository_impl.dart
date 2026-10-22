// ignore_for_file: join_return_with_assignment

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/models/result.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/chat.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_local_datasource.dart';

class YofardevRepositoryImpl implements ChatRepository {
  final ChatLocalDatasource _chatDatasource;

  YofardevRepositoryImpl({required ChatLocalDatasource chatDatasource})
    : _chatDatasource = chatDatasource;

  @override
  Future<Result<Chat>> createNewChat({String? language}) async {
    try {
      final Chat chat = await _chatDatasource.createNewChat(language: language);
      return Result<Chat>.ok(chat);
    } catch (e, st) {
      return Result<Chat>.err(
        mapExceptionToFailure(e, stackTrace: st, tag: 'YofardevRepository'),
      );
    }
  }

  @override
  Future<Result<Chat?>> getChat(String id) async {
    try {
      final Chat? chat = await _chatDatasource.getChat(id);
      return Result<Chat?>.ok(chat);
    } catch (e, st) {
      return Result<Chat?>.err(
        mapExceptionToFailure(e, stackTrace: st, tag: 'YofardevRepository'),
      );
    }
  }

  @override
  Future<Result<List<Chat>>> getChatsList() async {
    try {
      final List<Chat> chats = await _chatDatasource.getChatsList();
      return Result<List<Chat>>.ok(chats);
    } catch (e, st) {
      return Result<List<Chat>>.err(
        mapExceptionToFailure(e, stackTrace: st, tag: 'YofardevRepository'),
      );
    }
  }

  @override
  Future<Result<void>> updateChat({
    required String id,
    required Chat updatedChat,
  }) async {
    try {
      await _chatDatasource.updateChat(chatId: id, updatedChat: updatedChat);
      return Result<void>.ok(null);
    } catch (e, st) {
      return Result<void>.err(
        mapExceptionToFailure(e, stackTrace: st, tag: 'YofardevRepository'),
      );
    }
  }

  @override
  Future<Result<void>> deleteChat(String id) async {
    try {
      await _chatDatasource.deleteChat(id);
      return Result<void>.ok(null);
    } catch (e, st) {
      return Result<void>.err(
        mapExceptionToFailure(e, stackTrace: st, tag: 'YofardevRepository'),
      );
    }
  }

  @override
  Future<Result<void>> setCurrentChatId(String id) async {
    try {
      await _chatDatasource.setCurrentChatId(id);
      return Result<void>.ok(null);
    } catch (e, st) {
      return Result<void>.err(
        mapExceptionToFailure(e, stackTrace: st, tag: 'YofardevRepository'),
      );
    }
  }

  @override
  Future<Result<Chat>> getCurrentChat() async {
    try {
      final Chat chat = await _chatDatasource.getCurrentChat();
      return Result<Chat>.ok(chat);
    } catch (e, st) {
      return Result<Chat>.err(
        mapExceptionToFailure(e, stackTrace: st, tag: 'YofardevRepository'),
      );
    }
  }

  @override
  Future<Result<void>> updateAvatar(String chatId, Avatar avatar) async {
    try {
      await _chatDatasource.updateAvatar(chatId, avatar);
      return Result<void>.ok(null);
    } catch (e, st) {
      return Result<void>.err(
        mapExceptionToFailure(e, stackTrace: st, tag: 'YofardevRepository'),
      );
    }
  }
}
