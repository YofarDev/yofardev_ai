import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../../core/utils/extensions.dart';
import '../../../../../core/utils/logger.dart';
import '../../../../core/models/avatar_config.dart';

part 'chat_entry.freezed.dart';

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

  factory ChatEntry.fromJson(Map<String, dynamic> json) {
    // Handle timestamp format migration from int (milliseconds) to String (ISO8601)
    final Map<String, dynamic> processedJson = Map<String, dynamic>.from(json);
    if (processedJson['timestamp'] is int) {
      // Old format: timestamp as int (milliseconds since epoch)
      processedJson['timestamp'] = DateTime.fromMillisecondsSinceEpoch(
        processedJson['timestamp'] as int,
      ).toIso8601String();
    }
    return ChatEntry(
      id: processedJson['id'] as String,
      entryType: EnumUtils.deserialize(
        EntryType.values,
        processedJson['entryType'] as String,
      ),
      body: processedJson['body'] as String,
      timestamp: DateTime.parse(processedJson['timestamp'] as String),
      attachedImage: processedJson['attachedImage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'entryType': entryType.name,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'attachedImage': attachedImage,
    };
  }
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
