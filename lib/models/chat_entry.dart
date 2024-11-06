import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../utils/extensions.dart';
import 'avatar.dart';

class ChatEntry extends Equatable {
  final bool isFromUser;
  final String body;
  final DateTime timestamp;
  final String attachedImage;

  const ChatEntry({
    required this.isFromUser,
    required this.body,
    required this.timestamp,
    this.attachedImage = '',
  });

  @override
  List<Object> get props =>
      <Object>[isFromUser, body, timestamp, attachedImage];

  ChatEntry copyWith({
    bool? isFromUser,
    String? body,
    DateTime? timestamp,
    String? attachedImage,
  }) {
    return ChatEntry(
      isFromUser: isFromUser ?? this.isFromUser,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      attachedImage: attachedImage ?? this.attachedImage,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'fromUser': isFromUser,
      'body': body,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'attachedImage': attachedImage,
    };
  }

  factory ChatEntry.fromMap(Map<String, dynamic> map) {
    return ChatEntry(
      isFromUser: map['fromUser'] as bool? ?? false,
      body: map['body'] as String? ?? '',
      timestamp:
          DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int? ?? 0),
      attachedImage: map['attachedImage'] as String? ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory ChatEntry.fromJson(String source) =>
      ChatEntry.fromMap(json.decode(source) as Map<String, dynamic>);

  String getMessage({bool isFromUser = false}) {
    if (isFromUser) return body.getVisiblePrompt();
    final Map<String, dynamic> map = json.decode(body) as Map<String, dynamic>;
    return map['message'] as String? ?? '';
  }
}

extension ListChatEntryExtension on List<ChatEntry> {
  Future<List<Content>> getGeminiHistory() async {
    final List<Content> history = <Content>[];
    for (final ChatEntry entry in this) {
      if (entry.isFromUser) {
        history.add(Content.text(entry.body));
      } else {
        history.add(Content.model(<Part>[TextPart(entry.body)]));
      }
    }
    return history;
  }
}

extension ChatEntryExtension on ChatEntry {
  AvatarConfig getAvatarConfig() {
    try {
      final String body = this.body;
      if (body.isEmpty) return const AvatarConfig();
      final Map<String, dynamic> map = jsonDecode(body) as Map<String, dynamic>;
      return AvatarConfig.fromMap(map);
    } catch (e) {
      debugPrint('getAvatarConfig(): Error parsing avatar config: $e');
      return const AvatarConfig();
    }
  }
}
