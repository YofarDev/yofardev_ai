import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:llm_api_picker/llm_api_picker.dart' as llm;

import 'avatar.dart';
import 'chat_entry.dart';

enum ChatPersona {
  assistant,
  normal,
  doomer,
  conservative,
  philosopher,
  geek,
  coach,
  psychologist
}

class Chat extends Equatable {
  final String id;
  final List<ChatEntry> entries;
  final Avatar avatar;
  final String language;
  final String systemPrompt;
  final ChatPersona persona;

  const Chat({
    this.id = '',
    this.entries = const <ChatEntry>[],
    this.avatar = const Avatar(),
    this.language = 'en',
    this.systemPrompt = '',
    this.persona = ChatPersona.normal,
  });

  Chat copyWith({
    String? id,
    List<ChatEntry>? entries,
    Avatar? avatar,
    String? language,
    String? systemPrompt,
    ChatPersona? persona,
  }) {
    return Chat(
      id: id ?? this.id,
      entries: entries ?? this.entries,
      avatar: avatar ?? this.avatar,
      language: language ?? this.language,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      persona: persona ?? this.persona,
    );
  }

  @override
  List<Object?> get props {
    return <Object?>[
      id,
      entries,
      avatar,
      language,
      systemPrompt,
      persona,
    ];
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'entries': entries.map((ChatEntry x) => x.toMap()).toList(),
      'avatar': avatar.toMap(),
      'language': language,
      'systemPrompt': systemPrompt,
      'persona': persona.name,
    };
  }

  factory Chat.fromMap(Map<String, dynamic> map) {
    return Chat(
      id: map['id'] as String? ?? '',
      entries: List<ChatEntry>.from(
        (map['entries'] as List<dynamic>? ?? <String>[])
            .map((dynamic x) => ChatEntry.fromMap(x as Map<String, dynamic>)),
      ),
      avatar: Avatar.fromMap(map['avatar'] as Map<String, dynamic>),
      language: map['language'] as String,
      systemPrompt: map['systemPrompt'] as String? ?? '',
      persona: ChatPersona.values.byName(map['persona'] as String? ?? 'normal'),
    );
  }

  String toJson() => json.encode(toMap());

  factory Chat.fromJson(String source) =>
      Chat.fromMap(json.decode(source) as Map<String, dynamic>);
}

extension ChatExtension on Chat {
  List<llm.Message> get llmMessages {
    final List<llm.Message> messages = <llm.Message>[];
    for (final ChatEntry entry in entries) {
      if (entry.entryType == EntryType.functionCalling) continue;
      messages.add(
        llm.Message(
          role: entry.entryType == EntryType.user
              ? llm.MessageRole.user
              : llm.MessageRole.assistant,
          body: entry.body,
          attachedFile: entry.attachedImage,
        ),
      );
    }
    return messages;
  }
}
