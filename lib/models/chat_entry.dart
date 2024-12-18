import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../utils/extensions.dart';
import 'avatar.dart';

enum EntryType { user, yofardev, functionCalling }

class ChatEntry extends Equatable {
  final String id;
  final EntryType entryType;
  final String body;
  final DateTime timestamp;
  final String? attachedImage;

  const ChatEntry({
    required this.id,
    required this.entryType,
    required this.body,
    required this.timestamp,
    this.attachedImage,
  });

  @override
  List<Object?> get props =>
      <Object?>[entryType, body, timestamp, attachedImage];

  ChatEntry copyWith({
    EntryType? entryType,
    String? body,
    DateTime? timestamp,
    String? attachedImage,
  }) {
    return ChatEntry(
      id: id,
      entryType: entryType ?? this.entryType,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      attachedImage: attachedImage ?? this.attachedImage,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'entryType': entryType.name,
      'body': body,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'attachedImage': attachedImage,
    };
  }

  factory ChatEntry.fromMap(Map<String, dynamic> map) {
    return ChatEntry(
      id: map['id'] as String? ?? const Uuid().v4(),
      entryType: EntryType.values.firstWhere(
        (EntryType e) => e.name == map['entryType'],
        orElse: () => EntryType.user,
      ),
      body: map['body'] as String? ?? '',
      timestamp:
          DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int? ?? 0),
      attachedImage: map['attachedImage'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory ChatEntry.fromJson(String source) =>
      ChatEntry.fromMap(json.decode(source) as Map<String, dynamic>);

  String getMessage({bool isFromUser = false}) {
    if (isFromUser) return body.getVisiblePrompt();
    final Map<String, dynamic> map = json.decode(body) as Map<String, dynamic>;
    final String message = map['message'] as String? ?? '';
    return message;
  }

  @override
  String toString() {
    return 'ChatEntry(entryType: $entryType, body: $body, timestamp: $timestamp, attachedImage: $attachedImage)';
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
