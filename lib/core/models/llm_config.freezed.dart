// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'llm_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LlmConfig {

/// Unique identifier for this configuration
 String get id;/// User-friendly label (e.g., "My OpenAI", "Local Ollama")
 String get label;/// Base URL for the API endpoint (e.g., "https://api.openai.com/v1")
 String get baseUrl;/// API key for authentication
 String get apiKey;/// Model name to use (e.g., "gpt-4o", "llama3")
 String get model;/// Temperature for text generation (0.0 - 2.0)
/// Lower = more focused, Higher = more creative
 double get temperature;/// Response format type for JSON mode
 ResponseFormatType get responseFormatType;
/// Create a copy of LlmConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LlmConfigCopyWith<LlmConfig> get copyWith => _$LlmConfigCopyWithImpl<LlmConfig>(this as LlmConfig, _$identity);

  /// Serializes this LlmConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LlmConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.model, model) || other.model == model)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.responseFormatType, responseFormatType) || other.responseFormatType == responseFormatType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,baseUrl,apiKey,model,temperature,responseFormatType);

@override
String toString() {
  return 'LlmConfig(id: $id, label: $label, baseUrl: $baseUrl, apiKey: $apiKey, model: $model, temperature: $temperature, responseFormatType: $responseFormatType)';
}


}

/// @nodoc
abstract mixin class $LlmConfigCopyWith<$Res>  {
  factory $LlmConfigCopyWith(LlmConfig value, $Res Function(LlmConfig) _then) = _$LlmConfigCopyWithImpl;
@useResult
$Res call({
 String id, String label, String baseUrl, String apiKey, String model, double temperature, ResponseFormatType responseFormatType
});




}
/// @nodoc
class _$LlmConfigCopyWithImpl<$Res>
    implements $LlmConfigCopyWith<$Res> {
  _$LlmConfigCopyWithImpl(this._self, this._then);

  final LlmConfig _self;
  final $Res Function(LlmConfig) _then;

/// Create a copy of LlmConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? baseUrl = null,Object? apiKey = null,Object? model = null,Object? temperature = null,Object? responseFormatType = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double,responseFormatType: null == responseFormatType ? _self.responseFormatType : responseFormatType // ignore: cast_nullable_to_non_nullable
as ResponseFormatType,
  ));
}

}


/// Adds pattern-matching-related methods to [LlmConfig].
extension LlmConfigPatterns on LlmConfig {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LlmConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LlmConfig() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LlmConfig value)  $default,){
final _that = this;
switch (_that) {
case _LlmConfig():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LlmConfig value)?  $default,){
final _that = this;
switch (_that) {
case _LlmConfig() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String label,  String baseUrl,  String apiKey,  String model,  double temperature,  ResponseFormatType responseFormatType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LlmConfig() when $default != null:
return $default(_that.id,_that.label,_that.baseUrl,_that.apiKey,_that.model,_that.temperature,_that.responseFormatType);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String label,  String baseUrl,  String apiKey,  String model,  double temperature,  ResponseFormatType responseFormatType)  $default,) {final _that = this;
switch (_that) {
case _LlmConfig():
return $default(_that.id,_that.label,_that.baseUrl,_that.apiKey,_that.model,_that.temperature,_that.responseFormatType);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String label,  String baseUrl,  String apiKey,  String model,  double temperature,  ResponseFormatType responseFormatType)?  $default,) {final _that = this;
switch (_that) {
case _LlmConfig() when $default != null:
return $default(_that.id,_that.label,_that.baseUrl,_that.apiKey,_that.model,_that.temperature,_that.responseFormatType);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LlmConfig implements LlmConfig {
  const _LlmConfig({required this.id, required this.label, required this.baseUrl, required this.apiKey, required this.model, this.temperature = 0.7, this.responseFormatType = ResponseFormatType.jsonObject});
  factory _LlmConfig.fromJson(Map<String, dynamic> json) => _$LlmConfigFromJson(json);

/// Unique identifier for this configuration
@override final  String id;
/// User-friendly label (e.g., "My OpenAI", "Local Ollama")
@override final  String label;
/// Base URL for the API endpoint (e.g., "https://api.openai.com/v1")
@override final  String baseUrl;
/// API key for authentication
@override final  String apiKey;
/// Model name to use (e.g., "gpt-4o", "llama3")
@override final  String model;
/// Temperature for text generation (0.0 - 2.0)
/// Lower = more focused, Higher = more creative
@override@JsonKey() final  double temperature;
/// Response format type for JSON mode
@override@JsonKey() final  ResponseFormatType responseFormatType;

/// Create a copy of LlmConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LlmConfigCopyWith<_LlmConfig> get copyWith => __$LlmConfigCopyWithImpl<_LlmConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LlmConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LlmConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.model, model) || other.model == model)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.responseFormatType, responseFormatType) || other.responseFormatType == responseFormatType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,baseUrl,apiKey,model,temperature,responseFormatType);

@override
String toString() {
  return 'LlmConfig(id: $id, label: $label, baseUrl: $baseUrl, apiKey: $apiKey, model: $model, temperature: $temperature, responseFormatType: $responseFormatType)';
}


}

/// @nodoc
abstract mixin class _$LlmConfigCopyWith<$Res> implements $LlmConfigCopyWith<$Res> {
  factory _$LlmConfigCopyWith(_LlmConfig value, $Res Function(_LlmConfig) _then) = __$LlmConfigCopyWithImpl;
@override @useResult
$Res call({
 String id, String label, String baseUrl, String apiKey, String model, double temperature, ResponseFormatType responseFormatType
});




}
/// @nodoc
class __$LlmConfigCopyWithImpl<$Res>
    implements _$LlmConfigCopyWith<$Res> {
  __$LlmConfigCopyWithImpl(this._self, this._then);

  final _LlmConfig _self;
  final $Res Function(_LlmConfig) _then;

/// Create a copy of LlmConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? baseUrl = null,Object? apiKey = null,Object? model = null,Object? temperature = null,Object? responseFormatType = null,}) {
  return _then(_LlmConfig(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double,responseFormatType: null == responseFormatType ? _self.responseFormatType : responseFormatType // ignore: cast_nullable_to_non_nullable
as ResponseFormatType,
  ));
}


}

// dart format on
