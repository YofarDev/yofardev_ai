// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SettingsState {

// NEW FIELDS:
 TaskLlmConfig? get taskLlmConfig; List<LlmConfig> get availableLlmConfigs;// Function Calling Configuration Fields:
 String? get googleSearchKey; String? get googleSearchEngineId; bool get googleSearchEnabled; String? get openWeatherKey; bool get openWeatherEnabled; String? get newYorkTimesKey; bool get newYorkTimesEnabled;
/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettingsStateCopyWith<SettingsState> get copyWith => _$SettingsStateCopyWithImpl<SettingsState>(this as SettingsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SettingsState&&(identical(other.taskLlmConfig, taskLlmConfig) || other.taskLlmConfig == taskLlmConfig)&&const DeepCollectionEquality().equals(other.availableLlmConfigs, availableLlmConfigs)&&(identical(other.googleSearchKey, googleSearchKey) || other.googleSearchKey == googleSearchKey)&&(identical(other.googleSearchEngineId, googleSearchEngineId) || other.googleSearchEngineId == googleSearchEngineId)&&(identical(other.googleSearchEnabled, googleSearchEnabled) || other.googleSearchEnabled == googleSearchEnabled)&&(identical(other.openWeatherKey, openWeatherKey) || other.openWeatherKey == openWeatherKey)&&(identical(other.openWeatherEnabled, openWeatherEnabled) || other.openWeatherEnabled == openWeatherEnabled)&&(identical(other.newYorkTimesKey, newYorkTimesKey) || other.newYorkTimesKey == newYorkTimesKey)&&(identical(other.newYorkTimesEnabled, newYorkTimesEnabled) || other.newYorkTimesEnabled == newYorkTimesEnabled));
}


@override
int get hashCode => Object.hash(runtimeType,taskLlmConfig,const DeepCollectionEquality().hash(availableLlmConfigs),googleSearchKey,googleSearchEngineId,googleSearchEnabled,openWeatherKey,openWeatherEnabled,newYorkTimesKey,newYorkTimesEnabled);

@override
String toString() {
  return 'SettingsState(taskLlmConfig: $taskLlmConfig, availableLlmConfigs: $availableLlmConfigs, googleSearchKey: $googleSearchKey, googleSearchEngineId: $googleSearchEngineId, googleSearchEnabled: $googleSearchEnabled, openWeatherKey: $openWeatherKey, openWeatherEnabled: $openWeatherEnabled, newYorkTimesKey: $newYorkTimesKey, newYorkTimesEnabled: $newYorkTimesEnabled)';
}


}

/// @nodoc
abstract mixin class $SettingsStateCopyWith<$Res>  {
  factory $SettingsStateCopyWith(SettingsState value, $Res Function(SettingsState) _then) = _$SettingsStateCopyWithImpl;
@useResult
$Res call({
 TaskLlmConfig? taskLlmConfig, List<LlmConfig> availableLlmConfigs, String? googleSearchKey, String? googleSearchEngineId, bool googleSearchEnabled, String? openWeatherKey, bool openWeatherEnabled, String? newYorkTimesKey, bool newYorkTimesEnabled
});


$TaskLlmConfigCopyWith<$Res>? get taskLlmConfig;

}
/// @nodoc
class _$SettingsStateCopyWithImpl<$Res>
    implements $SettingsStateCopyWith<$Res> {
  _$SettingsStateCopyWithImpl(this._self, this._then);

  final SettingsState _self;
  final $Res Function(SettingsState) _then;

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? taskLlmConfig = freezed,Object? availableLlmConfigs = null,Object? googleSearchKey = freezed,Object? googleSearchEngineId = freezed,Object? googleSearchEnabled = null,Object? openWeatherKey = freezed,Object? openWeatherEnabled = null,Object? newYorkTimesKey = freezed,Object? newYorkTimesEnabled = null,}) {
  return _then(_self.copyWith(
taskLlmConfig: freezed == taskLlmConfig ? _self.taskLlmConfig : taskLlmConfig // ignore: cast_nullable_to_non_nullable
as TaskLlmConfig?,availableLlmConfigs: null == availableLlmConfigs ? _self.availableLlmConfigs : availableLlmConfigs // ignore: cast_nullable_to_non_nullable
as List<LlmConfig>,googleSearchKey: freezed == googleSearchKey ? _self.googleSearchKey : googleSearchKey // ignore: cast_nullable_to_non_nullable
as String?,googleSearchEngineId: freezed == googleSearchEngineId ? _self.googleSearchEngineId : googleSearchEngineId // ignore: cast_nullable_to_non_nullable
as String?,googleSearchEnabled: null == googleSearchEnabled ? _self.googleSearchEnabled : googleSearchEnabled // ignore: cast_nullable_to_non_nullable
as bool,openWeatherKey: freezed == openWeatherKey ? _self.openWeatherKey : openWeatherKey // ignore: cast_nullable_to_non_nullable
as String?,openWeatherEnabled: null == openWeatherEnabled ? _self.openWeatherEnabled : openWeatherEnabled // ignore: cast_nullable_to_non_nullable
as bool,newYorkTimesKey: freezed == newYorkTimesKey ? _self.newYorkTimesKey : newYorkTimesKey // ignore: cast_nullable_to_non_nullable
as String?,newYorkTimesEnabled: null == newYorkTimesEnabled ? _self.newYorkTimesEnabled : newYorkTimesEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskLlmConfigCopyWith<$Res>? get taskLlmConfig {
    if (_self.taskLlmConfig == null) {
    return null;
  }

  return $TaskLlmConfigCopyWith<$Res>(_self.taskLlmConfig!, (value) {
    return _then(_self.copyWith(taskLlmConfig: value));
  });
}
}


/// Adds pattern-matching-related methods to [SettingsState].
extension SettingsStatePatterns on SettingsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SettingsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SettingsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SettingsState value)  $default,){
final _that = this;
switch (_that) {
case _SettingsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SettingsState value)?  $default,){
final _that = this;
switch (_that) {
case _SettingsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TaskLlmConfig? taskLlmConfig,  List<LlmConfig> availableLlmConfigs,  String? googleSearchKey,  String? googleSearchEngineId,  bool googleSearchEnabled,  String? openWeatherKey,  bool openWeatherEnabled,  String? newYorkTimesKey,  bool newYorkTimesEnabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SettingsState() when $default != null:
return $default(_that.taskLlmConfig,_that.availableLlmConfigs,_that.googleSearchKey,_that.googleSearchEngineId,_that.googleSearchEnabled,_that.openWeatherKey,_that.openWeatherEnabled,_that.newYorkTimesKey,_that.newYorkTimesEnabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TaskLlmConfig? taskLlmConfig,  List<LlmConfig> availableLlmConfigs,  String? googleSearchKey,  String? googleSearchEngineId,  bool googleSearchEnabled,  String? openWeatherKey,  bool openWeatherEnabled,  String? newYorkTimesKey,  bool newYorkTimesEnabled)  $default,) {final _that = this;
switch (_that) {
case _SettingsState():
return $default(_that.taskLlmConfig,_that.availableLlmConfigs,_that.googleSearchKey,_that.googleSearchEngineId,_that.googleSearchEnabled,_that.openWeatherKey,_that.openWeatherEnabled,_that.newYorkTimesKey,_that.newYorkTimesEnabled);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TaskLlmConfig? taskLlmConfig,  List<LlmConfig> availableLlmConfigs,  String? googleSearchKey,  String? googleSearchEngineId,  bool googleSearchEnabled,  String? openWeatherKey,  bool openWeatherEnabled,  String? newYorkTimesKey,  bool newYorkTimesEnabled)?  $default,) {final _that = this;
switch (_that) {
case _SettingsState() when $default != null:
return $default(_that.taskLlmConfig,_that.availableLlmConfigs,_that.googleSearchKey,_that.googleSearchEngineId,_that.googleSearchEnabled,_that.openWeatherKey,_that.openWeatherEnabled,_that.newYorkTimesKey,_that.newYorkTimesEnabled);case _:
  return null;

}
}

}

/// @nodoc


class _SettingsState implements SettingsState {
  const _SettingsState({this.taskLlmConfig = null, final  List<LlmConfig> availableLlmConfigs = const <LlmConfig>[], this.googleSearchKey = null, this.googleSearchEngineId = null, this.googleSearchEnabled = true, this.openWeatherKey = null, this.openWeatherEnabled = true, this.newYorkTimesKey = null, this.newYorkTimesEnabled = true}): _availableLlmConfigs = availableLlmConfigs;
  

// NEW FIELDS:
@override@JsonKey() final  TaskLlmConfig? taskLlmConfig;
 final  List<LlmConfig> _availableLlmConfigs;
@override@JsonKey() List<LlmConfig> get availableLlmConfigs {
  if (_availableLlmConfigs is EqualUnmodifiableListView) return _availableLlmConfigs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableLlmConfigs);
}

// Function Calling Configuration Fields:
@override@JsonKey() final  String? googleSearchKey;
@override@JsonKey() final  String? googleSearchEngineId;
@override@JsonKey() final  bool googleSearchEnabled;
@override@JsonKey() final  String? openWeatherKey;
@override@JsonKey() final  bool openWeatherEnabled;
@override@JsonKey() final  String? newYorkTimesKey;
@override@JsonKey() final  bool newYorkTimesEnabled;

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettingsStateCopyWith<_SettingsState> get copyWith => __$SettingsStateCopyWithImpl<_SettingsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SettingsState&&(identical(other.taskLlmConfig, taskLlmConfig) || other.taskLlmConfig == taskLlmConfig)&&const DeepCollectionEquality().equals(other._availableLlmConfigs, _availableLlmConfigs)&&(identical(other.googleSearchKey, googleSearchKey) || other.googleSearchKey == googleSearchKey)&&(identical(other.googleSearchEngineId, googleSearchEngineId) || other.googleSearchEngineId == googleSearchEngineId)&&(identical(other.googleSearchEnabled, googleSearchEnabled) || other.googleSearchEnabled == googleSearchEnabled)&&(identical(other.openWeatherKey, openWeatherKey) || other.openWeatherKey == openWeatherKey)&&(identical(other.openWeatherEnabled, openWeatherEnabled) || other.openWeatherEnabled == openWeatherEnabled)&&(identical(other.newYorkTimesKey, newYorkTimesKey) || other.newYorkTimesKey == newYorkTimesKey)&&(identical(other.newYorkTimesEnabled, newYorkTimesEnabled) || other.newYorkTimesEnabled == newYorkTimesEnabled));
}


@override
int get hashCode => Object.hash(runtimeType,taskLlmConfig,const DeepCollectionEquality().hash(_availableLlmConfigs),googleSearchKey,googleSearchEngineId,googleSearchEnabled,openWeatherKey,openWeatherEnabled,newYorkTimesKey,newYorkTimesEnabled);

@override
String toString() {
  return 'SettingsState(taskLlmConfig: $taskLlmConfig, availableLlmConfigs: $availableLlmConfigs, googleSearchKey: $googleSearchKey, googleSearchEngineId: $googleSearchEngineId, googleSearchEnabled: $googleSearchEnabled, openWeatherKey: $openWeatherKey, openWeatherEnabled: $openWeatherEnabled, newYorkTimesKey: $newYorkTimesKey, newYorkTimesEnabled: $newYorkTimesEnabled)';
}


}

/// @nodoc
abstract mixin class _$SettingsStateCopyWith<$Res> implements $SettingsStateCopyWith<$Res> {
  factory _$SettingsStateCopyWith(_SettingsState value, $Res Function(_SettingsState) _then) = __$SettingsStateCopyWithImpl;
@override @useResult
$Res call({
 TaskLlmConfig? taskLlmConfig, List<LlmConfig> availableLlmConfigs, String? googleSearchKey, String? googleSearchEngineId, bool googleSearchEnabled, String? openWeatherKey, bool openWeatherEnabled, String? newYorkTimesKey, bool newYorkTimesEnabled
});


@override $TaskLlmConfigCopyWith<$Res>? get taskLlmConfig;

}
/// @nodoc
class __$SettingsStateCopyWithImpl<$Res>
    implements _$SettingsStateCopyWith<$Res> {
  __$SettingsStateCopyWithImpl(this._self, this._then);

  final _SettingsState _self;
  final $Res Function(_SettingsState) _then;

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? taskLlmConfig = freezed,Object? availableLlmConfigs = null,Object? googleSearchKey = freezed,Object? googleSearchEngineId = freezed,Object? googleSearchEnabled = null,Object? openWeatherKey = freezed,Object? openWeatherEnabled = null,Object? newYorkTimesKey = freezed,Object? newYorkTimesEnabled = null,}) {
  return _then(_SettingsState(
taskLlmConfig: freezed == taskLlmConfig ? _self.taskLlmConfig : taskLlmConfig // ignore: cast_nullable_to_non_nullable
as TaskLlmConfig?,availableLlmConfigs: null == availableLlmConfigs ? _self._availableLlmConfigs : availableLlmConfigs // ignore: cast_nullable_to_non_nullable
as List<LlmConfig>,googleSearchKey: freezed == googleSearchKey ? _self.googleSearchKey : googleSearchKey // ignore: cast_nullable_to_non_nullable
as String?,googleSearchEngineId: freezed == googleSearchEngineId ? _self.googleSearchEngineId : googleSearchEngineId // ignore: cast_nullable_to_non_nullable
as String?,googleSearchEnabled: null == googleSearchEnabled ? _self.googleSearchEnabled : googleSearchEnabled // ignore: cast_nullable_to_non_nullable
as bool,openWeatherKey: freezed == openWeatherKey ? _self.openWeatherKey : openWeatherKey // ignore: cast_nullable_to_non_nullable
as String?,openWeatherEnabled: null == openWeatherEnabled ? _self.openWeatherEnabled : openWeatherEnabled // ignore: cast_nullable_to_non_nullable
as bool,newYorkTimesKey: freezed == newYorkTimesKey ? _self.newYorkTimesKey : newYorkTimesKey // ignore: cast_nullable_to_non_nullable
as String?,newYorkTimesEnabled: null == newYorkTimesEnabled ? _self.newYorkTimesEnabled : newYorkTimesEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskLlmConfigCopyWith<$Res>? get taskLlmConfig {
    if (_self.taskLlmConfig == null) {
    return null;
  }

  return $TaskLlmConfigCopyWith<$Res>(_self.taskLlmConfig!, (value) {
    return _then(_self.copyWith(taskLlmConfig: value));
  });
}
}

// dart format on
