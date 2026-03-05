// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_tts_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatTtsState {

 List<Map<String, dynamic>> get audioPathsWaitingSentences; bool get isInitialized;
/// Create a copy of ChatTtsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatTtsStateCopyWith<ChatTtsState> get copyWith => _$ChatTtsStateCopyWithImpl<ChatTtsState>(this as ChatTtsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatTtsState&&const DeepCollectionEquality().equals(other.audioPathsWaitingSentences, audioPathsWaitingSentences)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(audioPathsWaitingSentences),isInitialized);

@override
String toString() {
  return 'ChatTtsState(audioPathsWaitingSentences: $audioPathsWaitingSentences, isInitialized: $isInitialized)';
}


}

/// @nodoc
abstract mixin class $ChatTtsStateCopyWith<$Res>  {
  factory $ChatTtsStateCopyWith(ChatTtsState value, $Res Function(ChatTtsState) _then) = _$ChatTtsStateCopyWithImpl;
@useResult
$Res call({
 List<Map<String, dynamic>> audioPathsWaitingSentences, bool isInitialized
});




}
/// @nodoc
class _$ChatTtsStateCopyWithImpl<$Res>
    implements $ChatTtsStateCopyWith<$Res> {
  _$ChatTtsStateCopyWithImpl(this._self, this._then);

  final ChatTtsState _self;
  final $Res Function(ChatTtsState) _then;

/// Create a copy of ChatTtsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? audioPathsWaitingSentences = null,Object? isInitialized = null,}) {
  return _then(_self.copyWith(
audioPathsWaitingSentences: null == audioPathsWaitingSentences ? _self.audioPathsWaitingSentences : audioPathsWaitingSentences // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatTtsState].
extension ChatTtsStatePatterns on ChatTtsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatTtsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatTtsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatTtsState value)  $default,){
final _that = this;
switch (_that) {
case _ChatTtsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatTtsState value)?  $default,){
final _that = this;
switch (_that) {
case _ChatTtsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Map<String, dynamic>> audioPathsWaitingSentences,  bool isInitialized)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatTtsState() when $default != null:
return $default(_that.audioPathsWaitingSentences,_that.isInitialized);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Map<String, dynamic>> audioPathsWaitingSentences,  bool isInitialized)  $default,) {final _that = this;
switch (_that) {
case _ChatTtsState():
return $default(_that.audioPathsWaitingSentences,_that.isInitialized);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Map<String, dynamic>> audioPathsWaitingSentences,  bool isInitialized)?  $default,) {final _that = this;
switch (_that) {
case _ChatTtsState() when $default != null:
return $default(_that.audioPathsWaitingSentences,_that.isInitialized);case _:
  return null;

}
}

}

/// @nodoc


class _ChatTtsState implements ChatTtsState {
  const _ChatTtsState({final  List<Map<String, dynamic>> audioPathsWaitingSentences = const <Map<String, dynamic>>[], this.isInitialized = false}): _audioPathsWaitingSentences = audioPathsWaitingSentences;
  

 final  List<Map<String, dynamic>> _audioPathsWaitingSentences;
@override@JsonKey() List<Map<String, dynamic>> get audioPathsWaitingSentences {
  if (_audioPathsWaitingSentences is EqualUnmodifiableListView) return _audioPathsWaitingSentences;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_audioPathsWaitingSentences);
}

@override@JsonKey() final  bool isInitialized;

/// Create a copy of ChatTtsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatTtsStateCopyWith<_ChatTtsState> get copyWith => __$ChatTtsStateCopyWithImpl<_ChatTtsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatTtsState&&const DeepCollectionEquality().equals(other._audioPathsWaitingSentences, _audioPathsWaitingSentences)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_audioPathsWaitingSentences),isInitialized);

@override
String toString() {
  return 'ChatTtsState(audioPathsWaitingSentences: $audioPathsWaitingSentences, isInitialized: $isInitialized)';
}


}

/// @nodoc
abstract mixin class _$ChatTtsStateCopyWith<$Res> implements $ChatTtsStateCopyWith<$Res> {
  factory _$ChatTtsStateCopyWith(_ChatTtsState value, $Res Function(_ChatTtsState) _then) = __$ChatTtsStateCopyWithImpl;
@override @useResult
$Res call({
 List<Map<String, dynamic>> audioPathsWaitingSentences, bool isInitialized
});




}
/// @nodoc
class __$ChatTtsStateCopyWithImpl<$Res>
    implements _$ChatTtsStateCopyWith<$Res> {
  __$ChatTtsStateCopyWithImpl(this._self, this._then);

  final _ChatTtsState _self;
  final $Res Function(_ChatTtsState) _then;

/// Create a copy of ChatTtsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? audioPathsWaitingSentences = null,Object? isInitialized = null,}) {
  return _then(_ChatTtsState(
audioPathsWaitingSentences: null == audioPathsWaitingSentences ? _self._audioPathsWaitingSentences : audioPathsWaitingSentences // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
