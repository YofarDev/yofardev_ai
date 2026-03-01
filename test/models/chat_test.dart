import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';
import 'package:yofardev_ai/core/models/llm_message.dart';

void main() {
  group('Chat', () {
    test('should create instance with default values', () {
      const Chat chat = Chat();
      expect(chat.id, '');
      expect(chat.entries, <ChatEntry>[]);
      expect(chat.avatar, Avatar());
      expect(chat.language, 'en');
      expect(chat.systemPrompt, '');
      expect(chat.persona, ChatPersona.normal);
    });

    test('should create instance with provided values', () {
      final List<ChatEntry> entries = <ChatEntry>[
        ChatEntry(
          id: 'entry1',
          entryType: EntryType.user,
          body: 'Hello',
          timestamp: DateTime.now(),
        ),
      ];
      final Chat chat = Chat(
        id: 'chat123',
        entries: entries,
        avatar: const Avatar(background: AvatarBackgrounds.beach),
        language: 'fr',
        systemPrompt: 'You are helpful',
        persona: ChatPersona.assistant,
      );
      expect(chat.id, 'chat123');
      expect(chat.entries.length, 1);
      expect(chat.avatar.background, AvatarBackgrounds.beach);
      expect(chat.language, 'fr');
      expect(chat.systemPrompt, 'You are helpful');
      expect(chat.persona, ChatPersona.assistant);
    });

    test('should support equality', () {
      const Chat chat1 = Chat(id: 'test');
      const Chat chat2 = Chat(id: 'test');
      const Chat chat3 = Chat(id: 'different');

      expect(chat1, equals(chat2));
      expect(chat1, isNot(equals(chat3)));
    });

    test('should copy with new values', () {
      const Chat original = Chat(id: 'chat1', language: 'en');

      final Chat copied = original.copyWith(id: 'chat2', language: 'fr');

      expect(copied.id, 'chat2');
      expect(copied.language, 'fr');
      // Other fields should remain the same
      expect(copied.avatar, original.avatar);
      expect(copied.persona, original.persona);
    });

    test('should copy with partial values', () {
      const Chat original = Chat(id: 'chat1', language: 'en');

      final Chat copied = original.copyWith(language: 'fr');

      expect(copied.id, original.id);
      expect(copied.language, 'fr');
      expect(copied.avatar, original.avatar);
    });

    test('should serialize to map with toMap', () {
      final List<ChatEntry> entries = <ChatEntry>[
        ChatEntry(
          id: 'entry1',
          entryType: EntryType.user,
          body: 'Hello',
          timestamp: DateTime.now(),
        ),
      ];
      final Chat chat = Chat(
        id: 'chat123',
        entries: entries,
        avatar: const Avatar(background: AvatarBackgrounds.beach),
        language: 'fr',
        systemPrompt: 'You are helpful',
        persona: ChatPersona.assistant,
      );

      final Map<String, dynamic> map = chat.toMap();

      expect(map['id'], 'chat123');
      expect(map['entries'] is List, true);
      expect(map['avatar'] is Map<String, dynamic>, true);
      expect(map['language'], 'fr');
      expect(map['systemPrompt'], 'You are helpful');
      expect(map['persona'], 'assistant');
    });

    test('should deserialize from map with fromMap', () {
      final List<ChatEntry> entries = <ChatEntry>[
        ChatEntry(
          id: 'entry1',
          entryType: EntryType.user,
          body: 'Hello',
          timestamp: DateTime.now(),
        ),
      ];
      final Map<String, dynamic> map = <String, dynamic>{
        'id': 'chat123',
        'entries': entries.map((ChatEntry e) => e.toJson()).toList(),
        'avatar': const Avatar().toMap(),
        'language': 'fr',
        'systemPrompt': 'You are helpful',
        'persona': 'assistant',
      };

      final Chat chat = Chat.fromMap(map);

      expect(chat.id, 'chat123');
      expect(chat.entries.length, 1);
      expect(chat.language, 'fr');
      expect(chat.systemPrompt, 'You are helpful');
      expect(chat.persona, ChatPersona.assistant);
    });

    test('should serialize to JSON string via toMap', () {
      const Chat chat = Chat(id: 'chat123', language: 'fr');

      final String jsonString = json.encode(chat.toMap());

      expect(jsonString, isA<String>());
      expect(jsonString.contains('chat123'), true);
    });

    test('should deserialize from JSON string via fromMap', () {
      const Chat chat = Chat(id: 'chat123', language: 'fr');
      final String jsonString = json.encode(chat.toMap());

      final Chat deserialized = Chat.fromMap(
        json.decode(jsonString) as Map<String, dynamic>,
      );

      expect(deserialized.id, 'chat123');
      expect(deserialized.language, 'fr');
    });

    test('should handle empty entries list', () {
      const Chat chat = Chat(id: 'chat123', entries: <ChatEntry>[]);

      expect(chat.entries, isEmpty);
      expect(chat.entries.length, 0);
    });

    test('ChatExtension.llmMessages should filter functionCalling entries', () {
      final List<ChatEntry> entries = <ChatEntry>[
        ChatEntry(
          id: 'entry1',
          entryType: EntryType.user,
          body: 'Hello',
          timestamp: DateTime.now(),
        ),
        ChatEntry(
          id: 'entry2',
          entryType: EntryType.yofardev,
          body: 'Hi there',
          timestamp: DateTime.now(),
        ),
        ChatEntry(
          id: 'entry3',
          entryType: EntryType.functionCalling,
          body: 'function call',
          timestamp: DateTime.now(),
        ),
      ];
      final Chat chat = Chat(entries: entries);

      final List<LlmMessage> llmMessages = chat.llmMessages;

      expect(llmMessages.length, 2);
      expect(llmMessages[0].role, LlmMessageRole.user);
      expect(
        llmMessages[1].role,
        LlmMessageRole.assistant,
      ); // yofardev is assistant
    });

    test('ChatExtension.llmMessages should handle attached images', () {
      final List<ChatEntry> entries = <ChatEntry>[
        ChatEntry(
          id: 'entry1',
          entryType: EntryType.user,
          body: 'Check this image',
          timestamp: DateTime.now(),
          attachedImage: 'image.jpg',
        ),
      ];
      final Chat chat = Chat(entries: entries);

      final List<LlmMessage> llmMessages = chat.llmMessages;

      expect(llmMessages.length, 1);
      expect(llmMessages[0].role, LlmMessageRole.user);
      expect(llmMessages[0].body, 'Check this image');
      expect(llmMessages[0].attachedFile, 'image.jpg');
    });

    test('should handle ChatPersona enum serialization', () {
      for (final ChatPersona persona in ChatPersona.values) {
        final Chat chat = Chat(persona: persona);
        final Map<String, dynamic> map = chat.toMap();
        final Chat deserialized = Chat.fromMap(map);

        expect(deserialized.persona, persona);
      }
    });
  });
}
