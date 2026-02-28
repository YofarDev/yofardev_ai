// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'llm_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

LlmConfig _$LlmConfigFromJson(Map<String, dynamic> json) {
  return _LlmConfig.fromJson(json);
}

/// @nodoc
mixin _$LlmConfig {
  /// Unique identifier for this configuration
  String get id => throw _privateConstructorUsedError;

  /// User-friendly label (e.g., "My OpenAI", "Local Ollama")
  String get label => throw _privateConstructorUsedError;

  /// Base URL for the API endpoint (e.g., "https://api.openai.com/v1")
  String get baseUrl => throw _privateConstructorUsedError;

  /// API key for authentication
  String get apiKey => throw _privateConstructorUsedError;

  /// Model name to use (e.g., "gpt-4o", "llama3")
  String get model => throw _privateConstructorUsedError;

  /// Temperature for text generation (0.0 - 2.0)
  /// Lower = more focused, Higher = more creative
  double get temperature => throw _privateConstructorUsedError;

  /// Serializes this LlmConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LlmConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LlmConfigCopyWith<LlmConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LlmConfigCopyWith<$Res> {
  factory $LlmConfigCopyWith(LlmConfig value, $Res Function(LlmConfig) then) =
      _$LlmConfigCopyWithImpl<$Res, LlmConfig>;
  @useResult
  $Res call(
      {String id,
      String label,
      String baseUrl,
      String apiKey,
      String model,
      double temperature});
}

/// @nodoc
class _$LlmConfigCopyWithImpl<$Res, $Val extends LlmConfig>
    implements $LlmConfigCopyWith<$Res> {
  _$LlmConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LlmConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? baseUrl = null,
    Object? apiKey = null,
    Object? model = null,
    Object? temperature = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      baseUrl: null == baseUrl
          ? _value.baseUrl
          : baseUrl // ignore: cast_nullable_to_non_nullable
              as String,
      apiKey: null == apiKey
          ? _value.apiKey
          : apiKey // ignore: cast_nullable_to_non_nullable
              as String,
      model: null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      temperature: null == temperature
          ? _value.temperature
          : temperature // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LlmConfigImplCopyWith<$Res>
    implements $LlmConfigCopyWith<$Res> {
  factory _$$LlmConfigImplCopyWith(
          _$LlmConfigImpl value, $Res Function(_$LlmConfigImpl) then) =
      __$$LlmConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String label,
      String baseUrl,
      String apiKey,
      String model,
      double temperature});
}

/// @nodoc
class __$$LlmConfigImplCopyWithImpl<$Res>
    extends _$LlmConfigCopyWithImpl<$Res, _$LlmConfigImpl>
    implements _$$LlmConfigImplCopyWith<$Res> {
  __$$LlmConfigImplCopyWithImpl(
      _$LlmConfigImpl _value, $Res Function(_$LlmConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of LlmConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? baseUrl = null,
    Object? apiKey = null,
    Object? model = null,
    Object? temperature = null,
  }) {
    return _then(_$LlmConfigImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      baseUrl: null == baseUrl
          ? _value.baseUrl
          : baseUrl // ignore: cast_nullable_to_non_nullable
              as String,
      apiKey: null == apiKey
          ? _value.apiKey
          : apiKey // ignore: cast_nullable_to_non_nullable
              as String,
      model: null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      temperature: null == temperature
          ? _value.temperature
          : temperature // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$LlmConfigImpl implements _LlmConfig {
  const _$LlmConfigImpl(
      {required this.id,
      required this.label,
      required this.baseUrl,
      required this.apiKey,
      required this.model,
      this.temperature = 0.7});

  factory _$LlmConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$LlmConfigImplFromJson(json);

  /// Unique identifier for this configuration
  @override
  final String id;

  /// User-friendly label (e.g., "My OpenAI", "Local Ollama")
  @override
  final String label;

  /// Base URL for the API endpoint (e.g., "https://api.openai.com/v1")
  @override
  final String baseUrl;

  /// API key for authentication
  @override
  final String apiKey;

  /// Model name to use (e.g., "gpt-4o", "llama3")
  @override
  final String model;

  /// Temperature for text generation (0.0 - 2.0)
  /// Lower = more focused, Higher = more creative
  @override
  @JsonKey()
  final double temperature;

  @override
  String toString() {
    return 'LlmConfig(id: $id, label: $label, baseUrl: $baseUrl, apiKey: $apiKey, model: $model, temperature: $temperature)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LlmConfigImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl) &&
            (identical(other.apiKey, apiKey) || other.apiKey == apiKey) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.temperature, temperature) ||
                other.temperature == temperature));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, label, baseUrl, apiKey, model, temperature);

  /// Create a copy of LlmConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LlmConfigImplCopyWith<_$LlmConfigImpl> get copyWith =>
      __$$LlmConfigImplCopyWithImpl<_$LlmConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LlmConfigImplToJson(
      this,
    );
  }
}

abstract class _LlmConfig implements LlmConfig {
  const factory _LlmConfig(
      {required final String id,
      required final String label,
      required final String baseUrl,
      required final String apiKey,
      required final String model,
      final double temperature}) = _$LlmConfigImpl;

  factory _LlmConfig.fromJson(Map<String, dynamic> json) =
      _$LlmConfigImpl.fromJson;

  /// Unique identifier for this configuration
  @override
  String get id;

  /// User-friendly label (e.g., "My OpenAI", "Local Ollama")
  @override
  String get label;

  /// Base URL for the API endpoint (e.g., "https://api.openai.com/v1")
  @override
  String get baseUrl;

  /// API key for authentication
  @override
  String get apiKey;

  /// Model name to use (e.g., "gpt-4o", "llama3")
  @override
  String get model;

  /// Temperature for text generation (0.0 - 2.0)
  /// Lower = more focused, Higher = more creative
  @override
  double get temperature;

  /// Create a copy of LlmConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LlmConfigImplCopyWith<_$LlmConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
