// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'talking_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TalkingState {

 TalkingStatus get status; Answer get answer; MouthState get mouthState; bool get isTalking;
/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TalkingStateCopyWith<TalkingState> get copyWith => _$TalkingStateCopyWithImpl<TalkingState>(this as TalkingState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TalkingState&&(identical(other.status, status) || other.status == status)&&(identical(other.answer, answer) || other.answer == answer)&&(identical(other.mouthState, mouthState) || other.mouthState == mouthState)&&(identical(other.isTalking, isTalking) || other.isTalking == isTalking));
}


@override
int get hashCode => Object.hash(runtimeType,status,answer,mouthState,isTalking);

@override
String toString() {
  return 'TalkingState(status: $status, answer: $answer, mouthState: $mouthState, isTalking: $isTalking)';
}


}

/// @nodoc
abstract mixin class $TalkingStateCopyWith<$Res>  {
  factory $TalkingStateCopyWith(TalkingState value, $Res Function(TalkingState) _then) = _$TalkingStateCopyWithImpl;
@useResult
$Res call({
 TalkingStatus status, Answer answer, MouthState mouthState, bool isTalking
});


$AnswerCopyWith<$Res> get answer;

}
/// @nodoc
class _$TalkingStateCopyWithImpl<$Res>
    implements $TalkingStateCopyWith<$Res> {
  _$TalkingStateCopyWithImpl(this._self, this._then);

  final TalkingState _self;
  final $Res Function(TalkingState) _then;

/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? answer = null,Object? mouthState = null,Object? isTalking = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TalkingStatus,answer: null == answer ? _self.answer : answer // ignore: cast_nullable_to_non_nullable
as Answer,mouthState: null == mouthState ? _self.mouthState : mouthState // ignore: cast_nullable_to_non_nullable
as MouthState,isTalking: null == isTalking ? _self.isTalking : isTalking // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AnswerCopyWith<$Res> get answer {
  
  return $AnswerCopyWith<$Res>(_self.answer, (value) {
    return _then(_self.copyWith(answer: value));
  });
}
}


/// Adds pattern-matching-related methods to [TalkingState].
extension TalkingStatePatterns on TalkingState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TalkingState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TalkingState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TalkingState value)  $default,){
final _that = this;
switch (_that) {
case _TalkingState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TalkingState value)?  $default,){
final _that = this;
switch (_that) {
case _TalkingState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TalkingStatus status,  Answer answer,  MouthState mouthState,  bool isTalking)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TalkingState() when $default != null:
return $default(_that.status,_that.answer,_that.mouthState,_that.isTalking);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TalkingStatus status,  Answer answer,  MouthState mouthState,  bool isTalking)  $default,) {final _that = this;
switch (_that) {
case _TalkingState():
return $default(_that.status,_that.answer,_that.mouthState,_that.isTalking);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TalkingStatus status,  Answer answer,  MouthState mouthState,  bool isTalking)?  $default,) {final _that = this;
switch (_that) {
case _TalkingState() when $default != null:
return $default(_that.status,_that.answer,_that.mouthState,_that.isTalking);case _:
  return null;

}
}

}

/// @nodoc


class _TalkingState extends TalkingState {
  const _TalkingState({this.status = TalkingStatus.initial, this.answer = const Answer(), this.mouthState = MouthState.closed, this.isTalking = false}): super._();
  

@override@JsonKey() final  TalkingStatus status;
@override@JsonKey() final  Answer answer;
@override@JsonKey() final  MouthState mouthState;
@override@JsonKey() final  bool isTalking;

/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TalkingStateCopyWith<_TalkingState> get copyWith => __$TalkingStateCopyWithImpl<_TalkingState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TalkingState&&(identical(other.status, status) || other.status == status)&&(identical(other.answer, answer) || other.answer == answer)&&(identical(other.mouthState, mouthState) || other.mouthState == mouthState)&&(identical(other.isTalking, isTalking) || other.isTalking == isTalking));
}


@override
int get hashCode => Object.hash(runtimeType,status,answer,mouthState,isTalking);

@override
String toString() {
  return 'TalkingState(status: $status, answer: $answer, mouthState: $mouthState, isTalking: $isTalking)';
}


}

/// @nodoc
abstract mixin class _$TalkingStateCopyWith<$Res> implements $TalkingStateCopyWith<$Res> {
  factory _$TalkingStateCopyWith(_TalkingState value, $Res Function(_TalkingState) _then) = __$TalkingStateCopyWithImpl;
@override @useResult
$Res call({
 TalkingStatus status, Answer answer, MouthState mouthState, bool isTalking
});


@override $AnswerCopyWith<$Res> get answer;

}
/// @nodoc
class __$TalkingStateCopyWithImpl<$Res>
    implements _$TalkingStateCopyWith<$Res> {
  __$TalkingStateCopyWithImpl(this._self, this._then);

  final _TalkingState _self;
  final $Res Function(_TalkingState) _then;

/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? answer = null,Object? mouthState = null,Object? isTalking = null,}) {
  return _then(_TalkingState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TalkingStatus,answer: null == answer ? _self.answer : answer // ignore: cast_nullable_to_non_nullable
as Answer,mouthState: null == mouthState ? _self.mouthState : mouthState // ignore: cast_nullable_to_non_nullable
as MouthState,isTalking: null == isTalking ? _self.isTalking : isTalking // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AnswerCopyWith<$Res> get answer {
  
  return $AnswerCopyWith<$Res>(_self.answer, (value) {
    return _then(_self.copyWith(answer: value));
  });
}
}

// dart format on
