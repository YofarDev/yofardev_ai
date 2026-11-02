import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/models/chat.dart';
import '../../../../core/models/result.dart';
import '../../../../core/utils/logger.dart';

/// Local datasource for Avatar-specific operations.
///
/// This datasource provides avatar-specific data access without
/// depending on ChatLocalDatasource, breaking the cross-feature dependency.
class AvatarLocalDatasource {
  static const String _chatPrefix = 'chat_';

  /// Gets a chat by ID for avatar operations.
  ///
  /// An absent chat is `ok(null)` (a normal state for new chats); corrupt
  /// content comes back as `err` so callers can tell the two apart.
  Future<Result<Chat?>> getChat(String id) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? chatJson = prefs.getString('$_chatPrefix$id');
      if (chatJson == null) return Result<Chat?>.ok(null);

      final Map<String, dynamic> chatMap =
          json.decode(chatJson) as Map<String, dynamic>;
      return Result<Chat?>.ok(Chat.fromMap(chatMap));
    } on FormatException catch (e, st) {
      return _corruptChat(e, st);
    } on TypeError catch (e, st) {
      return _corruptChat(e, st);
    } on Object catch (e, st) {
      // Absence is handled above; anything reaching here is a real failure
      // (corrupt payload or storage error) — never report it as not-found.
      return _corruptChat(e, st);
    }
  }

  Result<Chat?> _corruptChat(Object e, StackTrace st) {
    AppLogger.error(
      'Corrupt chat payload for avatar',
      tag: 'AvatarLocalDatasource',
      error: e,
      stackTrace: st,
    );
    return Result<Chat?>.err(
      mapExceptionToFailure(e, stackTrace: st, tag: 'AvatarLocalDatasource'),
    );
  }
}
