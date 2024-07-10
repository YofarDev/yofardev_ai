import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'bg_images.dart';
import 'chat_entry.dart';

class Chat extends Equatable {
  final String id;
  final List<ChatEntry> entries;
  final BgImages bgImages;

  const Chat({
    this.id = '',
    this.entries = const <ChatEntry>[],
    this.bgImages = BgImages.lake,
  });

  Chat copyWith({
    String? id,
    List<ChatEntry>? entries,
    BgImages? bgImages,
  }) {
    return Chat(
      id: id ?? this.id,
      entries: entries ?? this.entries,
      bgImages: bgImages ?? this.bgImages,
    );
  }

  @override
  List<Object> get props => <Object>[id, entries];

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'entries': entries.map((ChatEntry x) => x.toMap()).toList(),
      'bgImages': bgImages.name,
    };
  }

  factory Chat.fromMap(Map<String, dynamic> map) {
    return Chat(
      id: map['id'] as String? ?? '',
      entries: List<ChatEntry>.from((map['entries'] as List<dynamic>? ??
              <String>[])
          .map((dynamic x) => ChatEntry.fromMap(x as Map<String, dynamic>)),),
      bgImages: (map['bgImages'] as String? ?? '').getBgImageFromString() ??
          BgImages.lake,
    );
  }

  String toJson() => json.encode(toMap());

  factory Chat.fromJson(String source) =>
      Chat.fromMap(json.decode(source) as Map<String, dynamic>);
}
