import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../../core/models/chat.dart';
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
}
