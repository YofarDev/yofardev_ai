// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_audio_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatAudioState {

 List<Map<String, dynamic>> get audioPathsWaitingSentences; bool get initializing;
/// Create a copy of ChatAudioState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatAudioStateCopyWith<ChatAudioState> get copyWith => _$ChatAudioStateCopyWithImpl<ChatAudioState>(this as ChatAudioState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatAudioState&&const DeepCollectionEquality().equals(other.audioPathsWaitingSentences, audioPathsWaitingSentences)&&(identical(other.initializing, initializing) || other.initializing == initializing));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(audioPathsWaitingSentences),initializing);

@override
String toString() {
  return 'ChatAudioState(audioPathsWaitingSentences: $audioPathsWaitingSentences, initializing: $initializing)';
}


}

/// @nodoc
abstract mixin class $ChatAudioStateCopyWith<$Res>  {
  factory $ChatAudioStateCopyWith(ChatAudioState value, $Res Function(ChatAudioState) _then) = _$ChatAudioStateCopyWithImpl;
@useResult
$Res call({
 List<Map<String, dynamic>> audioPathsWaitingSentences, bool initializing
});




}
/// @nodoc
class _$ChatAudioStateCopyWithImpl<$Res>
    implements $ChatAudioStateCopyWith<$Res> {
  _$ChatAudioStateCopyWithImpl(this._self, this._then);

  final ChatAudioState _self;
  final $Res Function(ChatAudioState) _then;

/// Create a copy of ChatAudioState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? audioPathsWaitingSentences = null,Object? initializing = null,}) {
  return _then(_self.copyWith(
audioPathsWaitingSentences: null == audioPathsWaitingSentences ? _self.audioPathsWaitingSentences : audioPathsWaitingSentences // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,initializing: null == initializing ? _self.initializing : initializing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatAudioState].
extension ChatAudioStatePatterns on ChatAudioState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatAudioState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatAudioState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatAudioState value)  $default,){
final _that = this;
switch (_that) {
case _ChatAudioState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatAudioState value)?  $default,){
final _that = this;
switch (_that) {
case _ChatAudioState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Map<String, dynamic>> audioPathsWaitingSentences,  bool initializing)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatAudioState() when $default != null:
return $default(_that.audioPathsWaitingSentences,_that.initializing);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Map<String, dynamic>> audioPathsWaitingSentences,  bool initializing)  $default,) {final _that = this;
switch (_that) {
case _ChatAudioState():
return $default(_that.audioPathsWaitingSentences,_that.initializing);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Map<String, dynamic>> audioPathsWaitingSentences,  bool initializing)?  $default,) {final _that = this;
switch (_that) {
case _ChatAudioState() when $default != null:
return $default(_that.audioPathsWaitingSentences,_that.initializing);case _:
  return null;

}
}

}

/// @nodoc


class _ChatAudioState implements ChatAudioState {
  const _ChatAudioState({final  List<Map<String, dynamic>> audioPathsWaitingSentences = const <Map<String, dynamic>>[], this.initializing = true}): _audioPathsWaitingSentences = audioPathsWaitingSentences;
  

 final  List<Map<String, dynamic>> _audioPathsWaitingSentences;
@override@JsonKey() List<Map<String, dynamic>> get audioPathsWaitingSentences {
  if (_audioPathsWaitingSentences is EqualUnmodifiableListView) return _audioPathsWaitingSentences;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_audioPathsWaitingSentences);
}

@override@JsonKey() final  bool initializing;

/// Create a copy of ChatAudioState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatAudioStateCopyWith<_ChatAudioState> get copyWith => __$ChatAudioStateCopyWithImpl<_ChatAudioState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatAudioState&&const DeepCollectionEquality().equals(other._audioPathsWaitingSentences, _audioPathsWaitingSentences)&&(identical(other.initializing, initializing) || other.initializing == initializing));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_audioPathsWaitingSentences),initializing);

@override
String toString() {
  return 'ChatAudioState(audioPathsWaitingSentences: $audioPathsWaitingSentences, initializing: $initializing)';
}


}

/// @nodoc
abstract mixin class _$ChatAudioStateCopyWith<$Res> implements $ChatAudioStateCopyWith<$Res> {
  factory _$ChatAudioStateCopyWith(_ChatAudioState value, $Res Function(_ChatAudioState) _then) = __$ChatAudioStateCopyWithImpl;
@override @useResult
$Res call({
 List<Map<String, dynamic>> audioPathsWaitingSentences, bool initializing
});




}
/// @nodoc
class __$ChatAudioStateCopyWithImpl<$Res>
    implements _$ChatAudioStateCopyWith<$Res> {
  __$ChatAudioStateCopyWithImpl(this._self, this._then);

  final _ChatAudioState _self;
  final $Res Function(_ChatAudioState) _then;

/// Create a copy of ChatAudioState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? audioPathsWaitingSentences = null,Object? initializing = null,}) {
  return _then(_ChatAudioState(
audioPathsWaitingSentences: null == audioPathsWaitingSentences ? _self._audioPathsWaitingSentences : audioPathsWaitingSentences // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,initializing: null == initializing ? _self.initializing : initializing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
