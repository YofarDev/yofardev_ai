import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/models/avatar_config.dart';
import '../../../../core/models/chat.dart';
import 'chat_entry.dart';
import '../../../../core/models/llm_message.dart';

// Export ChatPersona from core for convenience
export '../../../../core/models/chat.dart' show ChatPersona;

part 'chat.freezed.dart';
part 'chat.g.dart';

// JsonConverter for Avatar to handle custom serialization
class AvatarJsonConverter
    implements JsonConverter<Avatar, Map<String, dynamic>> {
  const AvatarJsonConverter();

  @override
  Avatar fromJson(Map<String, dynamic> json) => Avatar.fromMap(json);

  @override
  Map<String, dynamic> toJson(Avatar object) => object.toMap();
}

@freezed
sealed class Chat with _$Chat {
  const Chat._();

  const factory Chat({
    @Default('') String id,
    @Default(<ChatEntry>[]) List<ChatEntry> entries,
    @AvatarJsonConverter() @Default(Avatar()) Avatar avatar,
    @Default('en') String language,
    @Default('') String systemPrompt,
    @Default(ChatPersona.normal) ChatPersona persona,
    // NEW FIELDS:
    @Default('') String title,
    @Default(false) bool titleGenerated,
  }) = _Chat;

  factory Chat.fromJson(Map<String, dynamic> json) => Chat.fromMap(json);

  // Backward compatibility: keep toMap/fromMap for existing code
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'entries': entries.map((ChatEntry x) => x.toJson()).toList(),
      'avatar': avatar.toMap(),
      'language': language,
      'systemPrompt': systemPrompt,
      'persona': persona.name,
      // NEW FIELDS:
      'title': title,
      'titleGenerated': titleGenerated,
    };
  }

  factory Chat.fromMap(Map<String, dynamic> map) {
    return Chat(
      id: map['id'] as String? ?? '',
      entries: List<ChatEntry>.from(
        (map['entries'] as List<dynamic>? ?? <String>[]).map(
          (dynamic x) => ChatEntry.fromJson(x as Map<String, dynamic>),
        ),
      ),
      avatar: Avatar.fromMap(
        map['avatar'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      language: map['language'] as String? ?? 'en',
      systemPrompt: map['systemPrompt'] as String? ?? '',
      persona: ChatPersona.values.byName(map['persona'] as String? ?? 'normal'),
      // NEW FIELDS (with defaults for backward compatibility):
      title: map['title'] as String? ?? '',
      titleGenerated: map['titleGenerated'] as bool? ?? false,
    );
  }
}

extension ChatExtension on Chat {
  List<LlmMessage> get llmMessages {
    final List<LlmMessage> messages = <LlmMessage>[];
    for (final ChatEntry entry in entries) {
      if (entry.entryType == EntryType.functionCalling) continue;
      messages.add(
        LlmMessage(
          role: entry.entryType == EntryType.user
              ? LlmMessageRole.user
              : LlmMessageRole.assistant,
          body: entry.body,
          attachedFile: entry.attachedImage,
        ),
      );
    }
    return messages;
  }
}
