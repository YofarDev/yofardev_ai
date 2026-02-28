// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatEntryText _$ChatEntryTextFromJson(Map<String, dynamic> json) =>
    ChatEntryText(
      id: json['id'] as String,
      content: json['content'] as String,
      role: json['role'] as String,
      timestamp: json['timestamp'] == null
          ? null
          : DateTime.parse(json['timestamp'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$ChatEntryTextToJson(ChatEntryText instance) =>
    <String, dynamic>{
      'id': instance.id,
      'content': instance.content,
      'role': instance.role,
      'timestamp': instance.timestamp?.toIso8601String(),
      'runtimeType': instance.$type,
    };

ChatEntryImage _$ChatEntryImageFromJson(Map<String, dynamic> json) =>
    ChatEntryImage(
      id: json['id'] as String,
      imageUrl: json['imageUrl'] as String,
      role: json['role'] as String,
      timestamp: json['timestamp'] == null
          ? null
          : DateTime.parse(json['timestamp'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$ChatEntryImageToJson(ChatEntryImage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'imageUrl': instance.imageUrl,
      'role': instance.role,
      'timestamp': instance.timestamp?.toIso8601String(),
      'runtimeType': instance.$type,
    };

ChatEntryToolCall _$ChatEntryToolCallFromJson(Map<String, dynamic> json) =>
    ChatEntryToolCall(
      id: json['id'] as String,
      toolName: json['toolName'] as String,
      arguments: json['arguments'] as Map<String, dynamic>,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$ChatEntryToolCallToJson(ChatEntryToolCall instance) =>
    <String, dynamic>{
      'id': instance.id,
      'toolName': instance.toolName,
      'arguments': instance.arguments,
      'runtimeType': instance.$type,
    };
