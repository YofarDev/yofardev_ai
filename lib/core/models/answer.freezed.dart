// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'answer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Answer {

 String get chatId; String get answerText; String get audioPath; List<int> get amplitudes; AvatarConfig get avatarConfig;
/// Create a copy of Answer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnswerCopyWith<Answer> get copyWith => _$AnswerCopyWithImpl<Answer>(this as Answer, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Answer&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.answerText, answerText) || other.answerText == answerText)&&(identical(other.audioPath, audioPath) || other.audioPath == audioPath)&&const DeepCollectionEquality().equals(other.amplitudes, amplitudes)&&(identical(other.avatarConfig, avatarConfig) || other.avatarConfig == avatarConfig));
}


@override
int get hashCode => Object.hash(runtimeType,chatId,answerText,audioPath,const DeepCollectionEquality().hash(amplitudes),avatarConfig);

@override
String toString() {
  return 'Answer(chatId: $chatId, answerText: $answerText, audioPath: $audioPath, amplitudes: $amplitudes, avatarConfig: $avatarConfig)';
}


}

/// @nodoc
abstract mixin class $AnswerCopyWith<$Res>  {
  factory $AnswerCopyWith(Answer value, $Res Function(Answer) _then) = _$AnswerCopyWithImpl;
@useResult
$Res call({
 String chatId, String answerText, String audioPath, List<int> amplitudes, AvatarConfig avatarConfig
});


$AvatarConfigCopyWith<$Res> get avatarConfig;

}
/// @nodoc
class _$AnswerCopyWithImpl<$Res>
    implements $AnswerCopyWith<$Res> {
  _$AnswerCopyWithImpl(this._self, this._then);

  final Answer _self;
  final $Res Function(Answer) _then;

/// Create a copy of Answer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chatId = null,Object? answerText = null,Object? audioPath = null,Object? amplitudes = null,Object? avatarConfig = null,}) {
  return _then(_self.copyWith(
chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,answerText: null == answerText ? _self.answerText : answerText // ignore: cast_nullable_to_non_nullable
as String,audioPath: null == audioPath ? _self.audioPath : audioPath // ignore: cast_nullable_to_non_nullable
as String,amplitudes: null == amplitudes ? _self.amplitudes : amplitudes // ignore: cast_nullable_to_non_nullable
as List<int>,avatarConfig: null == avatarConfig ? _self.avatarConfig : avatarConfig // ignore: cast_nullable_to_non_nullable
as AvatarConfig,
  ));
}
/// Create a copy of Answer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AvatarConfigCopyWith<$Res> get avatarConfig {
  
  return $AvatarConfigCopyWith<$Res>(_self.avatarConfig, (value) {
    return _then(_self.copyWith(avatarConfig: value));
  });
}
}


/// Adds pattern-matching-related methods to [Answer].
extension AnswerPatterns on Answer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Answer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Answer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Answer value)  $default,){
final _that = this;
switch (_that) {
case _Answer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Answer value)?  $default,){
final _that = this;
switch (_that) {
case _Answer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String chatId,  String answerText,  String audioPath,  List<int> amplitudes,  AvatarConfig avatarConfig)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Answer() when $default != null:
return $default(_that.chatId,_that.answerText,_that.audioPath,_that.amplitudes,_that.avatarConfig);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String chatId,  String answerText,  String audioPath,  List<int> amplitudes,  AvatarConfig avatarConfig)  $default,) {final _that = this;
switch (_that) {
case _Answer():
return $default(_that.chatId,_that.answerText,_that.audioPath,_that.amplitudes,_that.avatarConfig);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String chatId,  String answerText,  String audioPath,  List<int> amplitudes,  AvatarConfig avatarConfig)?  $default,) {final _that = this;
switch (_that) {
case _Answer() when $default != null:
return $default(_that.chatId,_that.answerText,_that.audioPath,_that.amplitudes,_that.avatarConfig);case _:
  return null;

}
}

}

/// @nodoc


class _Answer implements Answer {
  const _Answer({this.chatId = '', this.answerText = '', this.audioPath = '', final  List<int> amplitudes = const <int>[], this.avatarConfig = const AvatarConfig()}): _amplitudes = amplitudes;
  

@override@JsonKey() final  String chatId;
@override@JsonKey() final  String answerText;
@override@JsonKey() final  String audioPath;
 final  List<int> _amplitudes;
@override@JsonKey() List<int> get amplitudes {
  if (_amplitudes is EqualUnmodifiableListView) return _amplitudes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_amplitudes);
}

@override@JsonKey() final  AvatarConfig avatarConfig;

/// Create a copy of Answer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AnswerCopyWith<_Answer> get copyWith => __$AnswerCopyWithImpl<_Answer>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Answer&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.answerText, answerText) || other.answerText == answerText)&&(identical(other.audioPath, audioPath) || other.audioPath == audioPath)&&const DeepCollectionEquality().equals(other._amplitudes, _amplitudes)&&(identical(other.avatarConfig, avatarConfig) || other.avatarConfig == avatarConfig));
}


@override
int get hashCode => Object.hash(runtimeType,chatId,answerText,audioPath,const DeepCollectionEquality().hash(_amplitudes),avatarConfig);

@override
String toString() {
  return 'Answer(chatId: $chatId, answerText: $answerText, audioPath: $audioPath, amplitudes: $amplitudes, avatarConfig: $avatarConfig)';
}


}

/// @nodoc
abstract mixin class _$AnswerCopyWith<$Res> implements $AnswerCopyWith<$Res> {
  factory _$AnswerCopyWith(_Answer value, $Res Function(_Answer) _then) = __$AnswerCopyWithImpl;
@override @useResult
$Res call({
 String chatId, String answerText, String audioPath, List<int> amplitudes, AvatarConfig avatarConfig
});


@override $AvatarConfigCopyWith<$Res> get avatarConfig;

}
/// @nodoc
class __$AnswerCopyWithImpl<$Res>
    implements _$AnswerCopyWith<$Res> {
  __$AnswerCopyWithImpl(this._self, this._then);

  final _Answer _self;
  final $Res Function(_Answer) _then;

/// Create a copy of Answer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chatId = null,Object? answerText = null,Object? audioPath = null,Object? amplitudes = null,Object? avatarConfig = null,}) {
  return _then(_Answer(
chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,answerText: null == answerText ? _self.answerText : answerText // ignore: cast_nullable_to_non_nullable
as String,audioPath: null == audioPath ? _self.audioPath : audioPath // ignore: cast_nullable_to_non_nullable
as String,amplitudes: null == amplitudes ? _self._amplitudes : amplitudes // ignore: cast_nullable_to_non_nullable
as List<int>,avatarConfig: null == avatarConfig ? _self.avatarConfig : avatarConfig // ignore: cast_nullable_to_non_nullable
as AvatarConfig,
  ));
}

/// Create a copy of Answer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AvatarConfigCopyWith<$Res> get avatarConfig {
  
  return $AvatarConfigCopyWith<$Res>(_self.avatarConfig, (value) {
    return _then(_self.copyWith(avatarConfig: value));
  });
}
}

// dart format on
