// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LlmConfigImpl _$$LlmConfigImplFromJson(Map<String, dynamic> json) =>
    _$LlmConfigImpl(
      id: json['id'] as String,
      label: json['label'] as String,
      baseUrl: json['baseUrl'] as String,
      apiKey: json['apiKey'] as String,
      model: json['model'] as String,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
    );

Map<String, dynamic> _$$LlmConfigImplToJson(_$LlmConfigImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'baseUrl': instance.baseUrl,
      'apiKey': instance.apiKey,
      'model': instance.model,
      'temperature': instance.temperature,
    };
