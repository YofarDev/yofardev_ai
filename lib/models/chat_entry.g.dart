// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatEntry _$ChatEntryFromJson(Map<String, dynamic> json) => _ChatEntry(
  id: json['id'] as String,
  entryType: $enumDecode(_$EntryTypeEnumMap, json['entryType']),
  body: json['body'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  attachedImage: json['attachedImage'] as String?,
);

Map<String, dynamic> _$ChatEntryToJson(_ChatEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'entryType': _$EntryTypeEnumMap[instance.entryType]!,
      'body': instance.body,
      'timestamp': instance.timestamp.toIso8601String(),
      'attachedImage': instance.attachedImage,
    };

const _$EntryTypeEnumMap = {
  EntryType.user: 'user',
  EntryType.yofardev: 'yofardev',
  EntryType.functionCalling: 'functionCalling',
};
