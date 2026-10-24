import 'package:freezed_annotation/freezed_annotation.dart';

import 'avatar_config.dart';
import 'chat_entry.dart';
import 'llm_message.dart';

part 'chat.freezed.dart';
part 'chat.g.dart';

/// Chat persona enum defining different personality types
enum ChatPersona {
  assistant,
  normal,
  doomer,
  conservative,
  philosopher,
  geek,
  coach,
  psychologist,
}

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
    @Default('fr') String language,
    @Default('') String systemPrompt,
    @Default(ChatPersona.normal) ChatPersona persona,
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
  /// Maximum number of messages sent to the LLM. Capping the history keeps
  /// the prompt (and therefore time-to-first-token) bounded instead of
  /// growing every turn; only the count is capped, entry bodies are untouched.
  static const int maxLlmMessages = 40;

  List<LlmMessage> get llmMessages {
    final List<LlmMessage> messages = <LlmMessage>[];
    int lastImageIndex = -1;
    for (final ChatEntry entry in entries) {
      if (entry.entryType == EntryType.functionCalling) continue;
      final bool isUser = entry.entryType == EntryType.user;
      messages.add(
        LlmMessage(
          role: isUser ? LlmMessageRole.user : LlmMessageRole.assistant,
          // Requests carry the visible text only: user wrappers and
          // assistant JSON envelopes are re-sent-token waste. The current
          // avatar config + date ride a transient context message instead
          // (see ChatStreamingService).
          body: entry.getMessage(isFromUser: isUser),
          attachedFile: entry.attachedImage,
        ),
      );
      if (entry.attachedImage != null) {
        lastImageIndex = messages.length - 1;
      }
    }
    // Only the latest attached image is sent: re-sending every history
    // image each turn would dominate request cost once images actually
    // travel to the provider.
    for (int i = 0; i < messages.length; i++) {
      if (i != lastImageIndex && messages[i].attachedFile != null) {
        final LlmMessage m = messages[i];
        messages[i] = LlmMessage(role: m.role, body: m.body);
      }
    }
    if (messages.length > maxLlmMessages) {
      // Trim in blocks so the kept-prefix start stays constant across
      // consecutive turns (a shifting start would invalidate provider
      // prompt caches every turn). Even block size keeps the
      // user/assistant role alternation stable too.
      const int trimBlockSize = 8;
      final int neededStart = messages.length - maxLlmMessages;
      final int alignedStart =
          ((neededStart + trimBlockSize - 1) ~/ trimBlockSize) * trimBlockSize;
      return messages.sublist(alignedStart);
    }
    return messages;
  }
}
