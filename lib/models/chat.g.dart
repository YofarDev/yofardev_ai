// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Chat _$ChatFromJson(Map<String, dynamic> json) => _Chat(
  id: json['id'] as String? ?? '',
  entries:
      (json['entries'] as List<dynamic>?)
          ?.map((e) => ChatEntry.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ChatEntry>[],
  avatar: json['avatar'] == null
      ? const Avatar()
      : const AvatarJsonConverter().fromJson(
          json['avatar'] as Map<String, dynamic>,
        ),
  language: json['language'] as String? ?? 'en',
  systemPrompt: json['systemPrompt'] as String? ?? '',
  persona:
      $enumDecodeNullable(_$ChatPersonaEnumMap, json['persona']) ??
      ChatPersona.normal,
);

Map<String, dynamic> _$ChatToJson(_Chat instance) => <String, dynamic>{
  'id': instance.id,
  'entries': instance.entries,
  'avatar': const AvatarJsonConverter().toJson(instance.avatar),
  'language': instance.language,
  'systemPrompt': instance.systemPrompt,
  'persona': _$ChatPersonaEnumMap[instance.persona]!,
};

const _$ChatPersonaEnumMap = {
  ChatPersona.assistant: 'assistant',
  ChatPersona.normal: 'normal',
  ChatPersona.doomer: 'doomer',
  ChatPersona.conservative: 'conservative',
  ChatPersona.philosopher: 'philosopher',
  ChatPersona.geek: 'geek',
  ChatPersona.coach: 'coach',
  ChatPersona.psychologist: 'psychologist',
};
