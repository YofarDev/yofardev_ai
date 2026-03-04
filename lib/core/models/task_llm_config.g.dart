// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_llm_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TaskLlmConfig _$TaskLlmConfigFromJson(Map<String, dynamic> json) =>
    _TaskLlmConfig(
      assistantLlmId: json['assistantLlmId'] as String? ?? null,
      titleGenerationLlmId: json['titleGenerationLlmId'] as String? ?? null,
      functionCallingLlmId: json['functionCallingLlmId'] as String? ?? null,
    );

Map<String, dynamic> _$TaskLlmConfigToJson(_TaskLlmConfig instance) =>
    <String, dynamic>{
      'assistantLlmId': instance.assistantLlmId,
      'titleGenerationLlmId': instance.titleGenerationLlmId,
      'functionCallingLlmId': instance.functionCallingLlmId,
    };
