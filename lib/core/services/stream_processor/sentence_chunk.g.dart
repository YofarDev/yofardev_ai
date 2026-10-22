// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sentence_chunk.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SentenceChunkSentence _$SentenceChunkSentenceFromJson(
  Map<String, dynamic> json,
) => _SentenceChunkSentence(
  text: json['text'] as String,
  index: (json['index'] as num).toInt(),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$SentenceChunkSentenceToJson(
  _SentenceChunkSentence instance,
) => <String, dynamic>{
  'text': instance.text,
  'index': instance.index,
  'runtimeType': instance.$type,
};

_SentenceChunkMetadata _$SentenceChunkMetadataFromJson(
  Map<String, dynamic> json,
) => _SentenceChunkMetadata(
  json: json['json'] as Map<String, dynamic>,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$SentenceChunkMetadataToJson(
  _SentenceChunkMetadata instance,
) => <String, dynamic>{'json': instance.json, 'runtimeType': instance.$type};

_SentenceChunkComplete _$SentenceChunkCompleteFromJson(
  Map<String, dynamic> json,
) => _SentenceChunkComplete($type: json['runtimeType'] as String?);

Map<String, dynamic> _$SentenceChunkCompleteToJson(
  _SentenceChunkComplete instance,
) => <String, dynamic>{'runtimeType': instance.$type};

_SentenceChunkError _$SentenceChunkErrorFromJson(Map<String, dynamic> json) =>
    _SentenceChunkError(
      json['message'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SentenceChunkErrorToJson(_SentenceChunkError instance) =>
    <String, dynamic>{
      'message': instance.message,
      'runtimeType': instance.$type,
    };
