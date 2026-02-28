import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Response format type for JSON mode
enum ResponseFormatType {
  /// OpenAI-compatible: {"type": "json_object"}
  jsonObject,

  /// Some local providers: {"type": "json_schema"}
  jsonSchema,

  /// Fallback: no response_format sent, relies on prompt instructions
  text,

  /// Don't send response_format parameter at all
  none,
}

class LlmConfig extends Equatable {
  final String id;
  final String label;
  final String baseUrl;
  final String apiKey;
  final String model;
  final double temperature;
  final ResponseFormatType responseFormatType;

  const LlmConfig({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.temperature = 0.7,
    this.responseFormatType = ResponseFormatType.jsonObject,
  });

  factory LlmConfig.create({
    required String label,
    required String baseUrl,
    required String apiKey,
    required String model,
    double temperature = 0.7,
    ResponseFormatType responseFormatType = ResponseFormatType.jsonObject,
  }) {
    return LlmConfig(
      id: const Uuid().v4(),
      label: label,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      temperature: temperature,
      responseFormatType: responseFormatType,
    );
  }

  LlmConfig copyWith({
    String? id,
    String? label,
    String? baseUrl,
    String? apiKey,
    String? model,
    double? temperature,
    ResponseFormatType? responseFormatType,
  }) {
    return LlmConfig(
      id: id ?? this.id,
      label: label ?? this.label,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      responseFormatType: responseFormatType ?? this.responseFormatType,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'model': model,
      'temperature': temperature,
      'responseFormatType': responseFormatType.name,
    };
  }

  factory LlmConfig.fromMap(Map<String, dynamic> map) {
    return LlmConfig(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
      baseUrl: map['baseUrl'] as String? ?? '',
      apiKey: map['apiKey'] as String? ?? '',
      model: map['model'] as String? ?? '',
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.7,
      responseFormatType: map['responseFormatType'] != null
          ? ResponseFormatType.values.firstWhere(
              (ResponseFormatType e) => e.name == map['responseFormatType'],
              orElse: () => ResponseFormatType.jsonObject,
            )
          : ResponseFormatType.jsonObject,
    );
  }

  String toJson() => json.encode(toMap());

  factory LlmConfig.fromJson(String source) =>
      LlmConfig.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  List<Object?> get props =>
      <Object?>[id, label, baseUrl, apiKey, model, temperature, responseFormatType];
}
