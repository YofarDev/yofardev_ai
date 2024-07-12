import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'avatar.dart';
import 'chat_entry.dart';

class Chat extends Equatable {
  final String id;
  final List<ChatEntry> entries;
  final Avatar avatar;

  const Chat({
    this.id = '',
    this.entries = const <ChatEntry>[],
    this.avatar = const Avatar(),
  });

  Chat copyWith({
    String? id,
    List<ChatEntry>? entries,
    Avatar? avatar,
  }) {
    return Chat(
      id: id ?? this.id,
      entries: entries ?? this.entries,
      avatar: avatar ?? this.avatar,
    );
  }

  @override
  List<Object> get props => <Object>[id, entries, avatar];

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'entries': entries.map((ChatEntry x) => x.toMap()).toList(),
      'avatar': avatar.toMap(),
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
    );
  }

  String toJson() => json.encode(toMap());

  factory Chat.fromJson(String source) =>
      Chat.fromMap(json.decode(source) as Map<String, dynamic>);
}
