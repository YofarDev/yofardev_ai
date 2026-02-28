import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../utils/extensions.dart';
import '../utils/logger.dart';
import 'avatar.dart';

part 'chat_entry.freezed.dart';
part 'chat_entry.g.dart';

enum EntryType { user, yofardev, functionCalling }

@freezed
sealed class ChatEntry with _$ChatEntry {
  const factory ChatEntry({
    required String id,
    required EntryType entryType,
    required String body,
    required DateTime timestamp,
    String? attachedImage,
  }) = _ChatEntry;
  const ChatEntry._();

  factory ChatEntry.fromJson(Map<String, dynamic> json) =>
      _$ChatEntryFromJson(json);
}

extension ChatEntryExtension on ChatEntry {
  String getMessage({bool isFromUser = false}) {
    if (isFromUser) return body.getVisiblePrompt();
    try {
      // Try to extract valid JSON if the response contains extra text
      String cleanedBody = body.trim();
      final int jsonStart = cleanedBody.indexOf('{');
      final int jsonEnd = cleanedBody.lastIndexOf('}');

      if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
        cleanedBody = cleanedBody.substring(jsonStart, jsonEnd + 1);
      }

      final Map<String, dynamic> map =
          json.decode(cleanedBody) as Map<String, dynamic>;
      final String message = map['message'] as String? ?? '';
      return message;
    } catch (e) {
      AppLogger.error(
        'Error parsing JSON, using body as-is',
        tag: 'ChatEntry',
        error: e,
      );
      return body.getVisiblePrompt();
    }
  }

  AvatarConfig getAvatarConfig() {
    try {
      String body = this.body;
      if (body.isEmpty) return const AvatarConfig();

      // Try to extract valid JSON if the response contains extra text
      body = body.trim();
      final int jsonStart = body.indexOf('{');
      final int jsonEnd = body.lastIndexOf('}');

      if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
        body = body.substring(jsonStart, jsonEnd + 1);
      }

      final Map<String, dynamic> map = jsonDecode(body) as Map<String, dynamic>;
      return AvatarConfig.fromMap(map);
    } catch (e) {
      AppLogger.error(
        'Error parsing avatar config',
        tag: 'ChatEntry',
        error: e,
      );
      final String bodyPreview = body.length > 200
          ? '${body.substring(0, 200)}...'
          : body;
      AppLogger.debug('Body was: $bodyPreview', tag: 'ChatEntry');
      return const AvatarConfig();
    }
  }
}
