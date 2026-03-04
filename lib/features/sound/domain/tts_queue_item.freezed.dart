// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tts_queue_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TtsQueueItem {

 String get id; String get text; String get language; VoiceEffect get voiceEffect; TtsPriority get priority; DateTime get timestamp; String? get audioPath; bool get isProcessing; bool get isCompleted;
/// Create a copy of TtsQueueItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TtsQueueItemCopyWith<TtsQueueItem> get copyWith => _$TtsQueueItemCopyWithImpl<TtsQueueItem>(this as TtsQueueItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TtsQueueItem&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&(identical(other.language, language) || other.language == language)&&(identical(other.voiceEffect, voiceEffect) || other.voiceEffect == voiceEffect)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.audioPath, audioPath) || other.audioPath == audioPath)&&(identical(other.isProcessing, isProcessing) || other.isProcessing == isProcessing)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted));
}


@override
int get hashCode => Object.hash(runtimeType,id,text,language,voiceEffect,priority,timestamp,audioPath,isProcessing,isCompleted);

@override
String toString() {
  return 'TtsQueueItem(id: $id, text: $text, language: $language, voiceEffect: $voiceEffect, priority: $priority, timestamp: $timestamp, audioPath: $audioPath, isProcessing: $isProcessing, isCompleted: $isCompleted)';
}


}

/// @nodoc
abstract mixin class $TtsQueueItemCopyWith<$Res>  {
  factory $TtsQueueItemCopyWith(TtsQueueItem value, $Res Function(TtsQueueItem) _then) = _$TtsQueueItemCopyWithImpl;
@useResult
$Res call({
 String id, String text, String language, VoiceEffect voiceEffect, TtsPriority priority, DateTime timestamp, String? audioPath, bool isProcessing, bool isCompleted
});




}
/// @nodoc
class _$TtsQueueItemCopyWithImpl<$Res>
    implements $TtsQueueItemCopyWith<$Res> {
  _$TtsQueueItemCopyWithImpl(this._self, this._then);

  final TtsQueueItem _self;
  final $Res Function(TtsQueueItem) _then;

/// Create a copy of TtsQueueItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? text = null,Object? language = null,Object? voiceEffect = null,Object? priority = null,Object? timestamp = null,Object? audioPath = freezed,Object? isProcessing = null,Object? isCompleted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,voiceEffect: null == voiceEffect ? _self.voiceEffect : voiceEffect // ignore: cast_nullable_to_non_nullable
as VoiceEffect,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as TtsPriority,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,audioPath: freezed == audioPath ? _self.audioPath : audioPath // ignore: cast_nullable_to_non_nullable
as String?,isProcessing: null == isProcessing ? _self.isProcessing : isProcessing // ignore: cast_nullable_to_non_nullable
as bool,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TtsQueueItem].
extension TtsQueueItemPatterns on TtsQueueItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TtsQueueItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TtsQueueItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TtsQueueItem value)  $default,){
final _that = this;
switch (_that) {
case _TtsQueueItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TtsQueueItem value)?  $default,){
final _that = this;
switch (_that) {
case _TtsQueueItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String text,  String language,  VoiceEffect voiceEffect,  TtsPriority priority,  DateTime timestamp,  String? audioPath,  bool isProcessing,  bool isCompleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TtsQueueItem() when $default != null:
return $default(_that.id,_that.text,_that.language,_that.voiceEffect,_that.priority,_that.timestamp,_that.audioPath,_that.isProcessing,_that.isCompleted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String text,  String language,  VoiceEffect voiceEffect,  TtsPriority priority,  DateTime timestamp,  String? audioPath,  bool isProcessing,  bool isCompleted)  $default,) {final _that = this;
switch (_that) {
case _TtsQueueItem():
return $default(_that.id,_that.text,_that.language,_that.voiceEffect,_that.priority,_that.timestamp,_that.audioPath,_that.isProcessing,_that.isCompleted);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String text,  String language,  VoiceEffect voiceEffect,  TtsPriority priority,  DateTime timestamp,  String? audioPath,  bool isProcessing,  bool isCompleted)?  $default,) {final _that = this;
switch (_that) {
case _TtsQueueItem() when $default != null:
return $default(_that.id,_that.text,_that.language,_that.voiceEffect,_that.priority,_that.timestamp,_that.audioPath,_that.isProcessing,_that.isCompleted);case _:
  return null;

}
}

}

/// @nodoc


class _TtsQueueItem implements TtsQueueItem {
  const _TtsQueueItem({required this.id, required this.text, required this.language, required this.voiceEffect, required this.priority, required this.timestamp, this.audioPath, this.isProcessing = false, this.isCompleted = false});
  

@override final  String id;
@override final  String text;
@override final  String language;
@override final  VoiceEffect voiceEffect;
@override final  TtsPriority priority;
@override final  DateTime timestamp;
@override final  String? audioPath;
@override@JsonKey() final  bool isProcessing;
@override@JsonKey() final  bool isCompleted;

/// Create a copy of TtsQueueItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TtsQueueItemCopyWith<_TtsQueueItem> get copyWith => __$TtsQueueItemCopyWithImpl<_TtsQueueItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TtsQueueItem&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&(identical(other.language, language) || other.language == language)&&(identical(other.voiceEffect, voiceEffect) || other.voiceEffect == voiceEffect)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.audioPath, audioPath) || other.audioPath == audioPath)&&(identical(other.isProcessing, isProcessing) || other.isProcessing == isProcessing)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted));
}


@override
int get hashCode => Object.hash(runtimeType,id,text,language,voiceEffect,priority,timestamp,audioPath,isProcessing,isCompleted);

@override
String toString() {
  return 'TtsQueueItem(id: $id, text: $text, language: $language, voiceEffect: $voiceEffect, priority: $priority, timestamp: $timestamp, audioPath: $audioPath, isProcessing: $isProcessing, isCompleted: $isCompleted)';
}


}

/// @nodoc
abstract mixin class _$TtsQueueItemCopyWith<$Res> implements $TtsQueueItemCopyWith<$Res> {
  factory _$TtsQueueItemCopyWith(_TtsQueueItem value, $Res Function(_TtsQueueItem) _then) = __$TtsQueueItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String text, String language, VoiceEffect voiceEffect, TtsPriority priority, DateTime timestamp, String? audioPath, bool isProcessing, bool isCompleted
});




}
/// @nodoc
class __$TtsQueueItemCopyWithImpl<$Res>
    implements _$TtsQueueItemCopyWith<$Res> {
  __$TtsQueueItemCopyWithImpl(this._self, this._then);

  final _TtsQueueItem _self;
  final $Res Function(_TtsQueueItem) _then;

/// Create a copy of TtsQueueItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? text = null,Object? language = null,Object? voiceEffect = null,Object? priority = null,Object? timestamp = null,Object? audioPath = freezed,Object? isProcessing = null,Object? isCompleted = null,}) {
  return _then(_TtsQueueItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,voiceEffect: null == voiceEffect ? _self.voiceEffect : voiceEffect // ignore: cast_nullable_to_non_nullable
as VoiceEffect,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as TtsPriority,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,audioPath: freezed == audioPath ? _self.audioPath : audioPath // ignore: cast_nullable_to_non_nullable
as String?,isProcessing: null == isProcessing ? _self.isProcessing : isProcessing // ignore: cast_nullable_to_non_nullable
as bool,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
