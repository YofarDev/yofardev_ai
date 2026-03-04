import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../chat/domain/models/chat.dart';
import '../../../../core/models/avatar_config.dart';
import '../../../../core/utils/logger.dart';

/// Local datasource for Avatar-specific operations.
///
/// This datasource provides avatar-specific data access without
/// depending on ChatLocalDatasource, breaking the cross-feature dependency.
class AvatarLocalDatasource {
  static const String _chatPrefix = 'chat_';

  /// Gets a chat by ID for avatar operations.
  Future<Chat?> getChat(String id) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? chatJson = prefs.getString('$_chatPrefix$id');
      if (chatJson == null) return null;

      final Map<String, dynamic> chatMap =
          json.decode(chatJson) as Map<String, dynamic>;
      return Chat.fromMap(chatMap);
    } catch (e) {
      AppLogger.error(
        'Failed to get chat for avatar',
        tag: 'AvatarLocalDatasource',
        error: e,
      );
      return null;
    }
  }

  /// Updates the avatar configuration for a specific chat.
  Future<Either<Exception, void>> updateAvatar(
    String chatId,
    Avatar avatar,
  ) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Chat? currentChat = await getChat(chatId);

      if (currentChat == null) {
        return Left(Exception('Chat not found: $chatId'));
      }

      final Chat updatedChat = currentChat.copyWith(avatar: avatar);
      await prefs.setString(
        '$_chatPrefix$chatId',
        json.encode(updatedChat.toMap()),
      );

      return const Right(null);
    } catch (e) {
      AppLogger.error(
        'Failed to update avatar',
        tag: 'AvatarLocalDatasource',
        error: e,
      );
      return Left(Exception('Failed to update avatar: $e'));
    }
  }
}
