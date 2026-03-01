// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LlmConfig _$LlmConfigFromJson(Map<String, dynamic> json) => _LlmConfig(
  id: json['id'] as String,
  label: json['label'] as String,
  baseUrl: json['baseUrl'] as String,
  apiKey: json['apiKey'] as String,
  model: json['model'] as String,
  temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
  responseFormatType:
      $enumDecodeNullable(
        _$ResponseFormatTypeEnumMap,
        json['responseFormatType'],
      ) ??
      ResponseFormatType.jsonObject,
);

Map<String, dynamic> _$LlmConfigToJson(_LlmConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'baseUrl': instance.baseUrl,
      'apiKey': instance.apiKey,
      'model': instance.model,
      'temperature': instance.temperature,
      'responseFormatType':
          _$ResponseFormatTypeEnumMap[instance.responseFormatType]!,
    };

const _$ResponseFormatTypeEnumMap = {
  ResponseFormatType.none: 'none',
  ResponseFormatType.jsonObject: 'jsonObject',
  ResponseFormatType.jsonSchema: 'jsonSchema',
  ResponseFormatType.text: 'text',
};
