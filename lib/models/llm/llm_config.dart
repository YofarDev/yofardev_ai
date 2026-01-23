import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class LlmConfig extends Equatable {
  final String id;
  final String label;
  final String baseUrl;
  final String apiKey;
  final String model;
  final double temperature;

  const LlmConfig({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.temperature = 0.7,
  });

  factory LlmConfig.create({
    required String label,
    required String baseUrl,
    required String apiKey,
    required String model,
    double temperature = 0.7,
  }) {
    return LlmConfig(
      id: const Uuid().v4(),
      label: label,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      temperature: temperature,
    );
  }

  LlmConfig copyWith({
    String? id,
    String? label,
    String? baseUrl,
    String? apiKey,
    String? model,
    double? temperature,
  }) {
    return LlmConfig(
      id: id ?? this.id,
      label: label ?? this.label,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
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
    );
  }

  String toJson() => json.encode(toMap());

  factory LlmConfig.fromJson(String source) =>
      LlmConfig.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  List<Object> get props =>
      <Object>[id, label, baseUrl, apiKey, model, temperature];
}
