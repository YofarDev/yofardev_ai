// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_stream_chunk.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LlmStreamChunkText _$LlmStreamChunkTextFromJson(Map<String, dynamic> json) =>
    _LlmStreamChunkText(
      content: json['content'] as String,
      isComplete: json['isComplete'] as bool,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$LlmStreamChunkTextToJson(_LlmStreamChunkText instance) =>
    <String, dynamic>{
      'content': instance.content,
      'isComplete': instance.isComplete,
      'runtimeType': instance.$type,
    };

_LlmStreamChunkError _$LlmStreamChunkErrorFromJson(Map<String, dynamic> json) =>
    _LlmStreamChunkError(
      json['message'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$LlmStreamChunkErrorToJson(
  _LlmStreamChunkError instance,
) => <String, dynamic>{
  'message': instance.message,
  'runtimeType': instance.$type,
};

_LlmStreamChunkReasoning _$LlmStreamChunkReasoningFromJson(
  Map<String, dynamic> json,
) => _LlmStreamChunkReasoning(
  content: json['content'] as String,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$LlmStreamChunkReasoningToJson(
  _LlmStreamChunkReasoning instance,
) => <String, dynamic>{
  'content': instance.content,
  'runtimeType': instance.$type,
};

_LlmStreamChunkToolCallDelta _$LlmStreamChunkToolCallDeltaFromJson(
  Map<String, dynamic> json,
) => _LlmStreamChunkToolCallDelta(
  index: (json['index'] as num).toInt(),
  id: json['id'] as String?,
  name: json['name'] as String?,
  argumentsDelta: json['argumentsDelta'] as String?,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$LlmStreamChunkToolCallDeltaToJson(
  _LlmStreamChunkToolCallDelta instance,
) => <String, dynamic>{
  'index': instance.index,
  'id': instance.id,
  'name': instance.name,
  'argumentsDelta': instance.argumentsDelta,
  'runtimeType': instance.$type,
};

_LlmStreamChunkComplete _$LlmStreamChunkCompleteFromJson(
  Map<String, dynamic> json,
) => _LlmStreamChunkComplete($type: json['runtimeType'] as String?);

Map<String, dynamic> _$LlmStreamChunkCompleteToJson(
  _LlmStreamChunkComplete instance,
) => <String, dynamic>{'runtimeType': instance.$type};
