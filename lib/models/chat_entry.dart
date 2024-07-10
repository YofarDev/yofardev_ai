import 'dart:convert';

import 'package:equatable/equatable.dart';

class ChatEntry extends Equatable {
  final bool isFromUser;
  final String text;
  final DateTime timestamp;
  final String attachedImage;

  const ChatEntry({
    required this.isFromUser,
    required this.text,
    required this.timestamp,
    this.attachedImage = '',
  });

  @override
  List<Object> get props => <Object>[isFromUser, text, timestamp, attachedImage];

  ChatEntry copyWith({
    bool? isFromUser,
    String? text,
    DateTime? timestamp,
    String? attachedImage,
  }) {
    return ChatEntry(
      isFromUser: isFromUser ?? this.isFromUser,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      attachedImage: attachedImage ?? this.attachedImage,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'fromUser': isFromUser,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'attachedImage': attachedImage,
    };
  }

  factory ChatEntry.fromMap(Map<String, dynamic> map) {
    return ChatEntry(
      isFromUser: map['fromUser'] as bool? ?? false,
      text: map['text'] as String? ?? '',
      timestamp:
          DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int? ?? 0),
      attachedImage: map['attachedImage'] as String? ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory ChatEntry.fromJson(String source) =>
      ChatEntry.fromMap(json.decode(source) as Map<String, dynamic>);
}
