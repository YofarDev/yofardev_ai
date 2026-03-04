// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_llm_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TaskLlmConfig {

/// LLM config ID to use for assistant responses
 String? get assistantLlmId;/// LLM config ID to use for title generation
 String? get titleGenerationLlmId;/// LLM config ID to use for function calling
 String? get functionCallingLlmId;
/// Create a copy of TaskLlmConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskLlmConfigCopyWith<TaskLlmConfig> get copyWith => _$TaskLlmConfigCopyWithImpl<TaskLlmConfig>(this as TaskLlmConfig, _$identity);

  /// Serializes this TaskLlmConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskLlmConfig&&(identical(other.assistantLlmId, assistantLlmId) || other.assistantLlmId == assistantLlmId)&&(identical(other.titleGenerationLlmId, titleGenerationLlmId) || other.titleGenerationLlmId == titleGenerationLlmId)&&(identical(other.functionCallingLlmId, functionCallingLlmId) || other.functionCallingLlmId == functionCallingLlmId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,assistantLlmId,titleGenerationLlmId,functionCallingLlmId);

@override
String toString() {
  return 'TaskLlmConfig(assistantLlmId: $assistantLlmId, titleGenerationLlmId: $titleGenerationLlmId, functionCallingLlmId: $functionCallingLlmId)';
}


}

/// @nodoc
abstract mixin class $TaskLlmConfigCopyWith<$Res>  {
  factory $TaskLlmConfigCopyWith(TaskLlmConfig value, $Res Function(TaskLlmConfig) _then) = _$TaskLlmConfigCopyWithImpl;
@useResult
$Res call({
 String? assistantLlmId, String? titleGenerationLlmId, String? functionCallingLlmId
});




}
/// @nodoc
class _$TaskLlmConfigCopyWithImpl<$Res>
    implements $TaskLlmConfigCopyWith<$Res> {
  _$TaskLlmConfigCopyWithImpl(this._self, this._then);

  final TaskLlmConfig _self;
  final $Res Function(TaskLlmConfig) _then;

/// Create a copy of TaskLlmConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? assistantLlmId = freezed,Object? titleGenerationLlmId = freezed,Object? functionCallingLlmId = freezed,}) {
  return _then(_self.copyWith(
assistantLlmId: freezed == assistantLlmId ? _self.assistantLlmId : assistantLlmId // ignore: cast_nullable_to_non_nullable
as String?,titleGenerationLlmId: freezed == titleGenerationLlmId ? _self.titleGenerationLlmId : titleGenerationLlmId // ignore: cast_nullable_to_non_nullable
as String?,functionCallingLlmId: freezed == functionCallingLlmId ? _self.functionCallingLlmId : functionCallingLlmId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskLlmConfig].
extension TaskLlmConfigPatterns on TaskLlmConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskLlmConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskLlmConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskLlmConfig value)  $default,){
final _that = this;
switch (_that) {
case _TaskLlmConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskLlmConfig value)?  $default,){
final _that = this;
switch (_that) {
case _TaskLlmConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? assistantLlmId,  String? titleGenerationLlmId,  String? functionCallingLlmId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskLlmConfig() when $default != null:
return $default(_that.assistantLlmId,_that.titleGenerationLlmId,_that.functionCallingLlmId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? assistantLlmId,  String? titleGenerationLlmId,  String? functionCallingLlmId)  $default,) {final _that = this;
switch (_that) {
case _TaskLlmConfig():
return $default(_that.assistantLlmId,_that.titleGenerationLlmId,_that.functionCallingLlmId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? assistantLlmId,  String? titleGenerationLlmId,  String? functionCallingLlmId)?  $default,) {final _that = this;
switch (_that) {
case _TaskLlmConfig() when $default != null:
return $default(_that.assistantLlmId,_that.titleGenerationLlmId,_that.functionCallingLlmId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskLlmConfig implements TaskLlmConfig {
  const _TaskLlmConfig({this.assistantLlmId = null, this.titleGenerationLlmId = null, this.functionCallingLlmId = null});
  factory _TaskLlmConfig.fromJson(Map<String, dynamic> json) => _$TaskLlmConfigFromJson(json);

/// LLM config ID to use for assistant responses
@override@JsonKey() final  String? assistantLlmId;
/// LLM config ID to use for title generation
@override@JsonKey() final  String? titleGenerationLlmId;
/// LLM config ID to use for function calling
@override@JsonKey() final  String? functionCallingLlmId;

/// Create a copy of TaskLlmConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskLlmConfigCopyWith<_TaskLlmConfig> get copyWith => __$TaskLlmConfigCopyWithImpl<_TaskLlmConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskLlmConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskLlmConfig&&(identical(other.assistantLlmId, assistantLlmId) || other.assistantLlmId == assistantLlmId)&&(identical(other.titleGenerationLlmId, titleGenerationLlmId) || other.titleGenerationLlmId == titleGenerationLlmId)&&(identical(other.functionCallingLlmId, functionCallingLlmId) || other.functionCallingLlmId == functionCallingLlmId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,assistantLlmId,titleGenerationLlmId,functionCallingLlmId);

@override
String toString() {
  return 'TaskLlmConfig(assistantLlmId: $assistantLlmId, titleGenerationLlmId: $titleGenerationLlmId, functionCallingLlmId: $functionCallingLlmId)';
}


}

/// @nodoc
abstract mixin class _$TaskLlmConfigCopyWith<$Res> implements $TaskLlmConfigCopyWith<$Res> {
  factory _$TaskLlmConfigCopyWith(_TaskLlmConfig value, $Res Function(_TaskLlmConfig) _then) = __$TaskLlmConfigCopyWithImpl;
@override @useResult
$Res call({
 String? assistantLlmId, String? titleGenerationLlmId, String? functionCallingLlmId
});




}
/// @nodoc
class __$TaskLlmConfigCopyWithImpl<$Res>
    implements _$TaskLlmConfigCopyWith<$Res> {
  __$TaskLlmConfigCopyWithImpl(this._self, this._then);

  final _TaskLlmConfig _self;
  final $Res Function(_TaskLlmConfig) _then;

/// Create a copy of TaskLlmConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? assistantLlmId = freezed,Object? titleGenerationLlmId = freezed,Object? functionCallingLlmId = freezed,}) {
  return _then(_TaskLlmConfig(
assistantLlmId: freezed == assistantLlmId ? _self.assistantLlmId : assistantLlmId // ignore: cast_nullable_to_non_nullable
as String?,titleGenerationLlmId: freezed == titleGenerationLlmId ? _self.titleGenerationLlmId : titleGenerationLlmId // ignore: cast_nullable_to_non_nullable
as String?,functionCallingLlmId: freezed == functionCallingLlmId ? _self.functionCallingLlmId : functionCallingLlmId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
