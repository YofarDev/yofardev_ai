import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'avatar.dart';
import 'chat_entry.dart';

class Chat extends Equatable {
  final String id;
  final List<ChatEntry> entries;
  final Avatar avatar;
  final String language;
  final String? systemPrompt;

  const Chat({
    this.id = '',
    this.entries = const <ChatEntry>[],
    this.avatar = const Avatar(),
    this.language = 'en',
    this.systemPrompt,
    
  });

  Chat copyWith({
    String? id,
    List<ChatEntry>? entries,
    Avatar? avatar,
    String? language,
    ValueGetter<String?>? systemPrompt,
  }) {
    return Chat(
      id: id ?? this.id,
      entries: entries ?? this.entries,
      avatar: avatar ?? this.avatar,
      language: language ?? this.language,
      systemPrompt: systemPrompt != null ? systemPrompt() : this.systemPrompt,
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
    ];
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'entries': entries.map((ChatEntry x) => x.toMap()).toList(),
      'avatar': avatar.toMap(),
      'language': language,
      'systemPrompt': systemPrompt,
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
      systemPrompt: map['systemPrompt'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory Chat.fromJson(String source) =>
      Chat.fromMap(json.decode(source) as Map<String, dynamic>);
}
