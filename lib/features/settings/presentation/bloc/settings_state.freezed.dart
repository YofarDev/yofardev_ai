// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SettingsState {

 TaskLlmConfig? get taskLlmConfig; List<LlmConfig> get availableLlmConfigs; String? get selectedLlmConfigId; String? get googleSearchKey; String? get googleSearchEngineId; bool get googleSearchEnabled; String? get openWeatherKey; bool get openWeatherEnabled; String? get newYorkTimesKey; bool get newYorkTimesEnabled; bool get memoryEnabled; List<GlobalMemoryItem> get memoryItems; String? get username; String? get systemPrompt; ChatPersona get persona; bool get soundEffectsEnabled; TtsEngineStatus get ttsEngineStatus; String get currentLanguage; bool get hasError; Failure? get error;
/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettingsStateCopyWith<SettingsState> get copyWith => _$SettingsStateCopyWithImpl<SettingsState>(this as SettingsState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SettingsState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SettingsState&&(identical(other.taskLlmConfig, _this.taskLlmConfig) || other.taskLlmConfig == _this.taskLlmConfig)&&const DeepCollectionEquality().equals(other.availableLlmConfigs, _this.availableLlmConfigs)&&(identical(other.selectedLlmConfigId, _this.selectedLlmConfigId) || other.selectedLlmConfigId == _this.selectedLlmConfigId)&&(identical(other.googleSearchKey, _this.googleSearchKey) || other.googleSearchKey == _this.googleSearchKey)&&(identical(other.googleSearchEngineId, _this.googleSearchEngineId) || other.googleSearchEngineId == _this.googleSearchEngineId)&&(identical(other.googleSearchEnabled, _this.googleSearchEnabled) || other.googleSearchEnabled == _this.googleSearchEnabled)&&(identical(other.openWeatherKey, _this.openWeatherKey) || other.openWeatherKey == _this.openWeatherKey)&&(identical(other.openWeatherEnabled, _this.openWeatherEnabled) || other.openWeatherEnabled == _this.openWeatherEnabled)&&(identical(other.newYorkTimesKey, _this.newYorkTimesKey) || other.newYorkTimesKey == _this.newYorkTimesKey)&&(identical(other.newYorkTimesEnabled, _this.newYorkTimesEnabled) || other.newYorkTimesEnabled == _this.newYorkTimesEnabled)&&(identical(other.memoryEnabled, _this.memoryEnabled) || other.memoryEnabled == _this.memoryEnabled)&&const DeepCollectionEquality().equals(other.memoryItems, _this.memoryItems)&&(identical(other.username, _this.username) || other.username == _this.username)&&(identical(other.systemPrompt, _this.systemPrompt) || other.systemPrompt == _this.systemPrompt)&&(identical(other.persona, _this.persona) || other.persona == _this.persona)&&(identical(other.soundEffectsEnabled, _this.soundEffectsEnabled) || other.soundEffectsEnabled == _this.soundEffectsEnabled)&&(identical(other.ttsEngineStatus, _this.ttsEngineStatus) || other.ttsEngineStatus == _this.ttsEngineStatus)&&(identical(other.currentLanguage, _this.currentLanguage) || other.currentLanguage == _this.currentLanguage)&&(identical(other.hasError, _this.hasError) || other.hasError == _this.hasError)&&(identical(other.error, _this.error) || other.error == _this.error));
}


@override
int get hashCode {
  final _this = this as SettingsState;
  return Object.hashAll([runtimeType,_this.taskLlmConfig,const DeepCollectionEquality().hash(_this.availableLlmConfigs),_this.selectedLlmConfigId,_this.googleSearchKey,_this.googleSearchEngineId,_this.googleSearchEnabled,_this.openWeatherKey,_this.openWeatherEnabled,_this.newYorkTimesKey,_this.newYorkTimesEnabled,_this.memoryEnabled,const DeepCollectionEquality().hash(_this.memoryItems),_this.username,_this.systemPrompt,_this.persona,_this.soundEffectsEnabled,_this.ttsEngineStatus,_this.currentLanguage,_this.hasError,_this.error]);
}

@override
String toString() {
  final _this = this as SettingsState;
  return 'SettingsState(taskLlmConfig: ${_this.taskLlmConfig}, availableLlmConfigs: ${_this.availableLlmConfigs}, selectedLlmConfigId: ${_this.selectedLlmConfigId}, googleSearchKey: ${_this.googleSearchKey}, googleSearchEngineId: ${_this.googleSearchEngineId}, googleSearchEnabled: ${_this.googleSearchEnabled}, openWeatherKey: ${_this.openWeatherKey}, openWeatherEnabled: ${_this.openWeatherEnabled}, newYorkTimesKey: ${_this.newYorkTimesKey}, newYorkTimesEnabled: ${_this.newYorkTimesEnabled}, memoryEnabled: ${_this.memoryEnabled}, memoryItems: ${_this.memoryItems}, username: ${_this.username}, systemPrompt: ${_this.systemPrompt}, persona: ${_this.persona}, soundEffectsEnabled: ${_this.soundEffectsEnabled}, ttsEngineStatus: ${_this.ttsEngineStatus}, currentLanguage: ${_this.currentLanguage}, hasError: ${_this.hasError}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $SettingsStateCopyWith<$Res>  {
  factory $SettingsStateCopyWith(SettingsState value, $Res Function(SettingsState) _then) = _$SettingsStateCopyWithImpl;
@useResult
$Res call({
 TaskLlmConfig? taskLlmConfig, List<LlmConfig> availableLlmConfigs, String? selectedLlmConfigId, String? googleSearchKey, String? googleSearchEngineId, bool googleSearchEnabled, String? openWeatherKey, bool openWeatherEnabled, String? newYorkTimesKey, bool newYorkTimesEnabled, bool memoryEnabled, List<GlobalMemoryItem> memoryItems, String? username, String? systemPrompt, ChatPersona persona, bool soundEffectsEnabled, TtsEngineStatus ttsEngineStatus, String currentLanguage, bool hasError, Failure? error
});


$TaskLlmConfigCopyWith<$Res>? get taskLlmConfig;$TtsEngineStatusCopyWith<$Res> get ttsEngineStatus;

}
/// @nodoc
class _$SettingsStateCopyWithImpl<$Res>
    implements $SettingsStateCopyWith<$Res> {
  _$SettingsStateCopyWithImpl(this._self, this._then);

  final SettingsState _self;
  final $Res Function(SettingsState) _then;

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? taskLlmConfig = freezed,Object? availableLlmConfigs = null,Object? selectedLlmConfigId = freezed,Object? googleSearchKey = freezed,Object? googleSearchEngineId = freezed,Object? googleSearchEnabled = null,Object? openWeatherKey = freezed,Object? openWeatherEnabled = null,Object? newYorkTimesKey = freezed,Object? newYorkTimesEnabled = null,Object? memoryEnabled = null,Object? memoryItems = null,Object? username = freezed,Object? systemPrompt = freezed,Object? persona = null,Object? soundEffectsEnabled = null,Object? ttsEngineStatus = null,Object? currentLanguage = null,Object? hasError = null,Object? error = freezed,}) {
  return _then(SettingsState(
taskLlmConfig: freezed == taskLlmConfig ? _self.taskLlmConfig : taskLlmConfig // ignore: cast_nullable_to_non_nullable
as TaskLlmConfig?,availableLlmConfigs: null == availableLlmConfigs ? _self.availableLlmConfigs : availableLlmConfigs // ignore: cast_nullable_to_non_nullable
as List<LlmConfig>,selectedLlmConfigId: freezed == selectedLlmConfigId ? _self.selectedLlmConfigId : selectedLlmConfigId // ignore: cast_nullable_to_non_nullable
as String?,googleSearchKey: freezed == googleSearchKey ? _self.googleSearchKey : googleSearchKey // ignore: cast_nullable_to_non_nullable
as String?,googleSearchEngineId: freezed == googleSearchEngineId ? _self.googleSearchEngineId : googleSearchEngineId // ignore: cast_nullable_to_non_nullable
as String?,googleSearchEnabled: null == googleSearchEnabled ? _self.googleSearchEnabled : googleSearchEnabled // ignore: cast_nullable_to_non_nullable
as bool,openWeatherKey: freezed == openWeatherKey ? _self.openWeatherKey : openWeatherKey // ignore: cast_nullable_to_non_nullable
as String?,openWeatherEnabled: null == openWeatherEnabled ? _self.openWeatherEnabled : openWeatherEnabled // ignore: cast_nullable_to_non_nullable
as bool,newYorkTimesKey: freezed == newYorkTimesKey ? _self.newYorkTimesKey : newYorkTimesKey // ignore: cast_nullable_to_non_nullable
as String?,newYorkTimesEnabled: null == newYorkTimesEnabled ? _self.newYorkTimesEnabled : newYorkTimesEnabled // ignore: cast_nullable_to_non_nullable
as bool,memoryEnabled: null == memoryEnabled ? _self.memoryEnabled : memoryEnabled // ignore: cast_nullable_to_non_nullable
as bool,memoryItems: null == memoryItems ? _self.memoryItems : memoryItems // ignore: cast_nullable_to_non_nullable
as List<GlobalMemoryItem>,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,systemPrompt: freezed == systemPrompt ? _self.systemPrompt : systemPrompt // ignore: cast_nullable_to_non_nullable
as String?,persona: null == persona ? _self.persona : persona // ignore: cast_nullable_to_non_nullable
as ChatPersona,soundEffectsEnabled: null == soundEffectsEnabled ? _self.soundEffectsEnabled : soundEffectsEnabled // ignore: cast_nullable_to_non_nullable
as bool,ttsEngineStatus: null == ttsEngineStatus ? _self.ttsEngineStatus : ttsEngineStatus // ignore: cast_nullable_to_non_nullable
as TtsEngineStatus,currentLanguage: null == currentLanguage ? _self.currentLanguage : currentLanguage // ignore: cast_nullable_to_non_nullable
as String,hasError: null == hasError ? _self.hasError : hasError // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as Failure?,
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
}/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TtsEngineStatusCopyWith<$Res> get ttsEngineStatus {
  
  return $TtsEngineStatusCopyWith<$Res>(_self.ttsEngineStatus, (value) {
    return _then(_self.copyWith(ttsEngineStatus: value));
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TaskLlmConfig? taskLlmConfig,  List<LlmConfig> availableLlmConfigs,  String? selectedLlmConfigId,  String? googleSearchKey,  String? googleSearchEngineId,  bool googleSearchEnabled,  String? openWeatherKey,  bool openWeatherEnabled,  String? newYorkTimesKey,  bool newYorkTimesEnabled,  bool memoryEnabled,  List<GlobalMemoryItem> memoryItems,  String? username,  String? systemPrompt,  ChatPersona persona,  bool soundEffectsEnabled,  TtsEngineStatus ttsEngineStatus,  String currentLanguage,  bool hasError,  Failure? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SettingsState() when $default != null:
return $default(_that.taskLlmConfig,_that.availableLlmConfigs,_that.selectedLlmConfigId,_that.googleSearchKey,_that.googleSearchEngineId,_that.googleSearchEnabled,_that.openWeatherKey,_that.openWeatherEnabled,_that.newYorkTimesKey,_that.newYorkTimesEnabled,_that.memoryEnabled,_that.memoryItems,_that.username,_that.systemPrompt,_that.persona,_that.soundEffectsEnabled,_that.ttsEngineStatus,_that.currentLanguage,_that.hasError,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TaskLlmConfig? taskLlmConfig,  List<LlmConfig> availableLlmConfigs,  String? selectedLlmConfigId,  String? googleSearchKey,  String? googleSearchEngineId,  bool googleSearchEnabled,  String? openWeatherKey,  bool openWeatherEnabled,  String? newYorkTimesKey,  bool newYorkTimesEnabled,  bool memoryEnabled,  List<GlobalMemoryItem> memoryItems,  String? username,  String? systemPrompt,  ChatPersona persona,  bool soundEffectsEnabled,  TtsEngineStatus ttsEngineStatus,  String currentLanguage,  bool hasError,  Failure? error)  $default,) {final _that = this;
switch (_that) {
case _SettingsState():
return $default(_that.taskLlmConfig,_that.availableLlmConfigs,_that.selectedLlmConfigId,_that.googleSearchKey,_that.googleSearchEngineId,_that.googleSearchEnabled,_that.openWeatherKey,_that.openWeatherEnabled,_that.newYorkTimesKey,_that.newYorkTimesEnabled,_that.memoryEnabled,_that.memoryItems,_that.username,_that.systemPrompt,_that.persona,_that.soundEffectsEnabled,_that.ttsEngineStatus,_that.currentLanguage,_that.hasError,_that.error);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TaskLlmConfig? taskLlmConfig,  List<LlmConfig> availableLlmConfigs,  String? selectedLlmConfigId,  String? googleSearchKey,  String? googleSearchEngineId,  bool googleSearchEnabled,  String? openWeatherKey,  bool openWeatherEnabled,  String? newYorkTimesKey,  bool newYorkTimesEnabled,  bool memoryEnabled,  List<GlobalMemoryItem> memoryItems,  String? username,  String? systemPrompt,  ChatPersona persona,  bool soundEffectsEnabled,  TtsEngineStatus ttsEngineStatus,  String currentLanguage,  bool hasError,  Failure? error)?  $default,) {final _that = this;
switch (_that) {
case _SettingsState() when $default != null:
return $default(_that.taskLlmConfig,_that.availableLlmConfigs,_that.selectedLlmConfigId,_that.googleSearchKey,_that.googleSearchEngineId,_that.googleSearchEnabled,_that.openWeatherKey,_that.openWeatherEnabled,_that.newYorkTimesKey,_that.newYorkTimesEnabled,_that.memoryEnabled,_that.memoryItems,_that.username,_that.systemPrompt,_that.persona,_that.soundEffectsEnabled,_that.ttsEngineStatus,_that.currentLanguage,_that.hasError,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _SettingsState implements SettingsState {
  const _SettingsState({this.taskLlmConfig = null,  List<LlmConfig> availableLlmConfigs = const <LlmConfig>[], this.selectedLlmConfigId = null, this.googleSearchKey = null, this.googleSearchEngineId = null, this.googleSearchEnabled = true, this.openWeatherKey = null, this.openWeatherEnabled = true, this.newYorkTimesKey = null, this.newYorkTimesEnabled = true, this.memoryEnabled = true,  List<GlobalMemoryItem> memoryItems = const <GlobalMemoryItem>[], this.username = null, this.systemPrompt = null, this.persona = ChatPersona.assistant, this.soundEffectsEnabled = true, this.ttsEngineStatus = const TtsEngineStatus.notInstalled(), this.currentLanguage = 'fr', this.hasError = false, this.error}): _availableLlmConfigs = availableLlmConfigs,_memoryItems = memoryItems;
  

@override@JsonKey() final  TaskLlmConfig? taskLlmConfig;
 final  List<LlmConfig> _availableLlmConfigs;
@override@JsonKey() List<LlmConfig> get availableLlmConfigs {
  if (_availableLlmConfigs is EqualUnmodifiableListView) return _availableLlmConfigs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableLlmConfigs);
}

@override@JsonKey() final  String? selectedLlmConfigId;
@override@JsonKey() final  String? googleSearchKey;
@override@JsonKey() final  String? googleSearchEngineId;
@override@JsonKey() final  bool googleSearchEnabled;
@override@JsonKey() final  String? openWeatherKey;
@override@JsonKey() final  bool openWeatherEnabled;
@override@JsonKey() final  String? newYorkTimesKey;
@override@JsonKey() final  bool newYorkTimesEnabled;
@override@JsonKey() final  bool memoryEnabled;
 final  List<GlobalMemoryItem> _memoryItems;
@override@JsonKey() List<GlobalMemoryItem> get memoryItems {
  if (_memoryItems is EqualUnmodifiableListView) return _memoryItems;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_memoryItems);
}

@override@JsonKey() final  String? username;
@override@JsonKey() final  String? systemPrompt;
@override@JsonKey() final  ChatPersona persona;
@override@JsonKey() final  bool soundEffectsEnabled;
@override@JsonKey() final  TtsEngineStatus ttsEngineStatus;
@override@JsonKey() final  String currentLanguage;
@override@JsonKey() final  bool hasError;
@override final  Failure? error;

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettingsStateCopyWith<_SettingsState> get copyWith => __$SettingsStateCopyWithImpl<_SettingsState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SettingsState&&(identical(other.taskLlmConfig, taskLlmConfig) || other.taskLlmConfig == taskLlmConfig)&&const DeepCollectionEquality().equals(other.availableLlmConfigs, _availableLlmConfigs)&&(identical(other.selectedLlmConfigId, selectedLlmConfigId) || other.selectedLlmConfigId == selectedLlmConfigId)&&(identical(other.googleSearchKey, googleSearchKey) || other.googleSearchKey == googleSearchKey)&&(identical(other.googleSearchEngineId, googleSearchEngineId) || other.googleSearchEngineId == googleSearchEngineId)&&(identical(other.googleSearchEnabled, googleSearchEnabled) || other.googleSearchEnabled == googleSearchEnabled)&&(identical(other.openWeatherKey, openWeatherKey) || other.openWeatherKey == openWeatherKey)&&(identical(other.openWeatherEnabled, openWeatherEnabled) || other.openWeatherEnabled == openWeatherEnabled)&&(identical(other.newYorkTimesKey, newYorkTimesKey) || other.newYorkTimesKey == newYorkTimesKey)&&(identical(other.newYorkTimesEnabled, newYorkTimesEnabled) || other.newYorkTimesEnabled == newYorkTimesEnabled)&&(identical(other.memoryEnabled, memoryEnabled) || other.memoryEnabled == memoryEnabled)&&const DeepCollectionEquality().equals(other.memoryItems, _memoryItems)&&(identical(other.username, username) || other.username == username)&&(identical(other.systemPrompt, systemPrompt) || other.systemPrompt == systemPrompt)&&(identical(other.persona, persona) || other.persona == persona)&&(identical(other.soundEffectsEnabled, soundEffectsEnabled) || other.soundEffectsEnabled == soundEffectsEnabled)&&(identical(other.ttsEngineStatus, ttsEngineStatus) || other.ttsEngineStatus == ttsEngineStatus)&&(identical(other.currentLanguage, currentLanguage) || other.currentLanguage == currentLanguage)&&(identical(other.hasError, hasError) || other.hasError == hasError)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,taskLlmConfig,const DeepCollectionEquality().hash(_availableLlmConfigs),selectedLlmConfigId,googleSearchKey,googleSearchEngineId,googleSearchEnabled,openWeatherKey,openWeatherEnabled,newYorkTimesKey,newYorkTimesEnabled,memoryEnabled,const DeepCollectionEquality().hash(_memoryItems),username,systemPrompt,persona,soundEffectsEnabled,ttsEngineStatus,currentLanguage,hasError,error]);
}

@override
String toString() {
    return 'SettingsState(taskLlmConfig: $taskLlmConfig, availableLlmConfigs: $availableLlmConfigs, selectedLlmConfigId: $selectedLlmConfigId, googleSearchKey: $googleSearchKey, googleSearchEngineId: $googleSearchEngineId, googleSearchEnabled: $googleSearchEnabled, openWeatherKey: $openWeatherKey, openWeatherEnabled: $openWeatherEnabled, newYorkTimesKey: $newYorkTimesKey, newYorkTimesEnabled: $newYorkTimesEnabled, memoryEnabled: $memoryEnabled, memoryItems: $memoryItems, username: $username, systemPrompt: $systemPrompt, persona: $persona, soundEffectsEnabled: $soundEffectsEnabled, ttsEngineStatus: $ttsEngineStatus, currentLanguage: $currentLanguage, hasError: $hasError, error: $error)';
}


}

/// @nodoc
abstract mixin class _$SettingsStateCopyWith<$Res> implements $SettingsStateCopyWith<$Res> {
  factory _$SettingsStateCopyWith(_SettingsState value, $Res Function(_SettingsState) _then) = __$SettingsStateCopyWithImpl;
@override @useResult
$Res call({
 TaskLlmConfig? taskLlmConfig, List<LlmConfig> availableLlmConfigs, String? selectedLlmConfigId, String? googleSearchKey, String? googleSearchEngineId, bool googleSearchEnabled, String? openWeatherKey, bool openWeatherEnabled, String? newYorkTimesKey, bool newYorkTimesEnabled, bool memoryEnabled, List<GlobalMemoryItem> memoryItems, String? username, String? systemPrompt, ChatPersona persona, bool soundEffectsEnabled, TtsEngineStatus ttsEngineStatus, String currentLanguage, bool hasError, Failure? error
});


@override $TaskLlmConfigCopyWith<$Res>? get taskLlmConfig;@override $TtsEngineStatusCopyWith<$Res> get ttsEngineStatus;

}
/// @nodoc
class __$SettingsStateCopyWithImpl<$Res>
    implements _$SettingsStateCopyWith<$Res> {
  __$SettingsStateCopyWithImpl(this._self, this._then);

  final _SettingsState _self;
  final $Res Function(_SettingsState) _then;

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? taskLlmConfig = freezed,Object? availableLlmConfigs = null,Object? selectedLlmConfigId = freezed,Object? googleSearchKey = freezed,Object? googleSearchEngineId = freezed,Object? googleSearchEnabled = null,Object? openWeatherKey = freezed,Object? openWeatherEnabled = null,Object? newYorkTimesKey = freezed,Object? newYorkTimesEnabled = null,Object? memoryEnabled = null,Object? memoryItems = null,Object? username = freezed,Object? systemPrompt = freezed,Object? persona = null,Object? soundEffectsEnabled = null,Object? ttsEngineStatus = null,Object? currentLanguage = null,Object? hasError = null,Object? error = freezed,}) {
  return _then(_SettingsState(
taskLlmConfig: freezed == taskLlmConfig ? _self.taskLlmConfig : taskLlmConfig // ignore: cast_nullable_to_non_nullable
as TaskLlmConfig?,availableLlmConfigs: null == availableLlmConfigs ? _self._availableLlmConfigs : availableLlmConfigs // ignore: cast_nullable_to_non_nullable
as List<LlmConfig>,selectedLlmConfigId: freezed == selectedLlmConfigId ? _self.selectedLlmConfigId : selectedLlmConfigId // ignore: cast_nullable_to_non_nullable
as String?,googleSearchKey: freezed == googleSearchKey ? _self.googleSearchKey : googleSearchKey // ignore: cast_nullable_to_non_nullable
as String?,googleSearchEngineId: freezed == googleSearchEngineId ? _self.googleSearchEngineId : googleSearchEngineId // ignore: cast_nullable_to_non_nullable
as String?,googleSearchEnabled: null == googleSearchEnabled ? _self.googleSearchEnabled : googleSearchEnabled // ignore: cast_nullable_to_non_nullable
as bool,openWeatherKey: freezed == openWeatherKey ? _self.openWeatherKey : openWeatherKey // ignore: cast_nullable_to_non_nullable
as String?,openWeatherEnabled: null == openWeatherEnabled ? _self.openWeatherEnabled : openWeatherEnabled // ignore: cast_nullable_to_non_nullable
as bool,newYorkTimesKey: freezed == newYorkTimesKey ? _self.newYorkTimesKey : newYorkTimesKey // ignore: cast_nullable_to_non_nullable
as String?,newYorkTimesEnabled: null == newYorkTimesEnabled ? _self.newYorkTimesEnabled : newYorkTimesEnabled // ignore: cast_nullable_to_non_nullable
as bool,memoryEnabled: null == memoryEnabled ? _self.memoryEnabled : memoryEnabled // ignore: cast_nullable_to_non_nullable
as bool,memoryItems: null == memoryItems ? _self._memoryItems : memoryItems // ignore: cast_nullable_to_non_nullable
as List<GlobalMemoryItem>,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,systemPrompt: freezed == systemPrompt ? _self.systemPrompt : systemPrompt // ignore: cast_nullable_to_non_nullable
as String?,persona: null == persona ? _self.persona : persona // ignore: cast_nullable_to_non_nullable
as ChatPersona,soundEffectsEnabled: null == soundEffectsEnabled ? _self.soundEffectsEnabled : soundEffectsEnabled // ignore: cast_nullable_to_non_nullable
as bool,ttsEngineStatus: null == ttsEngineStatus ? _self.ttsEngineStatus : ttsEngineStatus // ignore: cast_nullable_to_non_nullable
as TtsEngineStatus,currentLanguage: null == currentLanguage ? _self.currentLanguage : currentLanguage // ignore: cast_nullable_to_non_nullable
as String,hasError: null == hasError ? _self.hasError : hasError // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as Failure?,
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
}/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TtsEngineStatusCopyWith<$Res> get ttsEngineStatus {
  
  return $TtsEngineStatusCopyWith<$Res>(_self.ttsEngineStatus, (value) {
    return _then(_self.copyWith(ttsEngineStatus: value));
  });
}
}

// dart format on
