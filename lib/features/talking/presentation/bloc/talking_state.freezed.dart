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

 MouthState get mouthState;
/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TalkingStateCopyWith<TalkingState> get copyWith => _$TalkingStateCopyWithImpl<TalkingState>(this as TalkingState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TalkingState&&(identical(other.mouthState, mouthState) || other.mouthState == mouthState));
}


@override
int get hashCode => Object.hash(runtimeType,mouthState);

@override
String toString() {
  return 'TalkingState(mouthState: $mouthState)';
}


}

/// @nodoc
abstract mixin class $TalkingStateCopyWith<$Res>  {
  factory $TalkingStateCopyWith(TalkingState value, $Res Function(TalkingState) _then) = _$TalkingStateCopyWithImpl;
@useResult
$Res call({
 MouthState mouthState
});




}
/// @nodoc
class _$TalkingStateCopyWithImpl<$Res>
    implements $TalkingStateCopyWith<$Res> {
  _$TalkingStateCopyWithImpl(this._self, this._then);

  final TalkingState _self;
  final $Res Function(TalkingState) _then;

/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mouthState = null,}) {
  return _then(_self.copyWith(
mouthState: null == mouthState ? _self.mouthState : mouthState // ignore: cast_nullable_to_non_nullable
as MouthState,
  ));
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( IdleState value)?  idle,TResult Function( WaitingState value)?  waiting,TResult Function( GeneratingState value)?  generating,TResult Function( SpeakingState value)?  speaking,TResult Function( ErrorState value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case IdleState() when idle != null:
return idle(_that);case WaitingState() when waiting != null:
return waiting(_that);case GeneratingState() when generating != null:
return generating(_that);case SpeakingState() when speaking != null:
return speaking(_that);case ErrorState() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( IdleState value)  idle,required TResult Function( WaitingState value)  waiting,required TResult Function( GeneratingState value)  generating,required TResult Function( SpeakingState value)  speaking,required TResult Function( ErrorState value)  error,}){
final _that = this;
switch (_that) {
case IdleState():
return idle(_that);case WaitingState():
return waiting(_that);case GeneratingState():
return generating(_that);case SpeakingState():
return speaking(_that);case ErrorState():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( IdleState value)?  idle,TResult? Function( WaitingState value)?  waiting,TResult? Function( GeneratingState value)?  generating,TResult? Function( SpeakingState value)?  speaking,TResult? Function( ErrorState value)?  error,}){
final _that = this;
switch (_that) {
case IdleState() when idle != null:
return idle(_that);case WaitingState() when waiting != null:
return waiting(_that);case GeneratingState() when generating != null:
return generating(_that);case SpeakingState() when speaking != null:
return speaking(_that);case ErrorState() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( MouthState mouthState)?  idle,TResult Function( MouthState mouthState)?  waiting,TResult Function( MouthState mouthState)?  generating,TResult Function( MouthState mouthState)?  speaking,TResult Function( String message,  MouthState mouthState)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case IdleState() when idle != null:
return idle(_that.mouthState);case WaitingState() when waiting != null:
return waiting(_that.mouthState);case GeneratingState() when generating != null:
return generating(_that.mouthState);case SpeakingState() when speaking != null:
return speaking(_that.mouthState);case ErrorState() when error != null:
return error(_that.message,_that.mouthState);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( MouthState mouthState)  idle,required TResult Function( MouthState mouthState)  waiting,required TResult Function( MouthState mouthState)  generating,required TResult Function( MouthState mouthState)  speaking,required TResult Function( String message,  MouthState mouthState)  error,}) {final _that = this;
switch (_that) {
case IdleState():
return idle(_that.mouthState);case WaitingState():
return waiting(_that.mouthState);case GeneratingState():
return generating(_that.mouthState);case SpeakingState():
return speaking(_that.mouthState);case ErrorState():
return error(_that.message,_that.mouthState);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( MouthState mouthState)?  idle,TResult? Function( MouthState mouthState)?  waiting,TResult? Function( MouthState mouthState)?  generating,TResult? Function( MouthState mouthState)?  speaking,TResult? Function( String message,  MouthState mouthState)?  error,}) {final _that = this;
switch (_that) {
case IdleState() when idle != null:
return idle(_that.mouthState);case WaitingState() when waiting != null:
return waiting(_that.mouthState);case GeneratingState() when generating != null:
return generating(_that.mouthState);case SpeakingState() when speaking != null:
return speaking(_that.mouthState);case ErrorState() when error != null:
return error(_that.message,_that.mouthState);case _:
  return null;

}
}

}

/// @nodoc


class IdleState implements TalkingState {
  const IdleState([this.mouthState = MouthState.closed]);
  

@override@JsonKey() final  MouthState mouthState;

/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IdleStateCopyWith<IdleState> get copyWith => _$IdleStateCopyWithImpl<IdleState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IdleState&&(identical(other.mouthState, mouthState) || other.mouthState == mouthState));
}


@override
int get hashCode => Object.hash(runtimeType,mouthState);

@override
String toString() {
  return 'TalkingState.idle(mouthState: $mouthState)';
}


}

/// @nodoc
abstract mixin class $IdleStateCopyWith<$Res> implements $TalkingStateCopyWith<$Res> {
  factory $IdleStateCopyWith(IdleState value, $Res Function(IdleState) _then) = _$IdleStateCopyWithImpl;
@override @useResult
$Res call({
 MouthState mouthState
});




}
/// @nodoc
class _$IdleStateCopyWithImpl<$Res>
    implements $IdleStateCopyWith<$Res> {
  _$IdleStateCopyWithImpl(this._self, this._then);

  final IdleState _self;
  final $Res Function(IdleState) _then;

/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mouthState = null,}) {
  return _then(IdleState(
null == mouthState ? _self.mouthState : mouthState // ignore: cast_nullable_to_non_nullable
as MouthState,
  ));
}


}

/// @nodoc


class WaitingState implements TalkingState {
  const WaitingState([this.mouthState = MouthState.closed]);
  

@override@JsonKey() final  MouthState mouthState;

/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WaitingStateCopyWith<WaitingState> get copyWith => _$WaitingStateCopyWithImpl<WaitingState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WaitingState&&(identical(other.mouthState, mouthState) || other.mouthState == mouthState));
}


@override
int get hashCode => Object.hash(runtimeType,mouthState);

@override
String toString() {
  return 'TalkingState.waiting(mouthState: $mouthState)';
}


}

/// @nodoc
abstract mixin class $WaitingStateCopyWith<$Res> implements $TalkingStateCopyWith<$Res> {
  factory $WaitingStateCopyWith(WaitingState value, $Res Function(WaitingState) _then) = _$WaitingStateCopyWithImpl;
@override @useResult
$Res call({
 MouthState mouthState
});




}
/// @nodoc
class _$WaitingStateCopyWithImpl<$Res>
    implements $WaitingStateCopyWith<$Res> {
  _$WaitingStateCopyWithImpl(this._self, this._then);

  final WaitingState _self;
  final $Res Function(WaitingState) _then;

/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mouthState = null,}) {
  return _then(WaitingState(
null == mouthState ? _self.mouthState : mouthState // ignore: cast_nullable_to_non_nullable
as MouthState,
  ));
}


}

/// @nodoc


class GeneratingState implements TalkingState {
  const GeneratingState([this.mouthState = MouthState.closed]);
  

@override@JsonKey() final  MouthState mouthState;

/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GeneratingStateCopyWith<GeneratingState> get copyWith => _$GeneratingStateCopyWithImpl<GeneratingState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GeneratingState&&(identical(other.mouthState, mouthState) || other.mouthState == mouthState));
}


@override
int get hashCode => Object.hash(runtimeType,mouthState);

@override
String toString() {
  return 'TalkingState.generating(mouthState: $mouthState)';
}


}

/// @nodoc
abstract mixin class $GeneratingStateCopyWith<$Res> implements $TalkingStateCopyWith<$Res> {
  factory $GeneratingStateCopyWith(GeneratingState value, $Res Function(GeneratingState) _then) = _$GeneratingStateCopyWithImpl;
@override @useResult
$Res call({
 MouthState mouthState
});




}
/// @nodoc
class _$GeneratingStateCopyWithImpl<$Res>
    implements $GeneratingStateCopyWith<$Res> {
  _$GeneratingStateCopyWithImpl(this._self, this._then);

  final GeneratingState _self;
  final $Res Function(GeneratingState) _then;

/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mouthState = null,}) {
  return _then(GeneratingState(
null == mouthState ? _self.mouthState : mouthState // ignore: cast_nullable_to_non_nullable
as MouthState,
  ));
}


}

/// @nodoc


class SpeakingState implements TalkingState {
  const SpeakingState([this.mouthState = MouthState.closed]);
  

@override@JsonKey() final  MouthState mouthState;

/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpeakingStateCopyWith<SpeakingState> get copyWith => _$SpeakingStateCopyWithImpl<SpeakingState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpeakingState&&(identical(other.mouthState, mouthState) || other.mouthState == mouthState));
}


@override
int get hashCode => Object.hash(runtimeType,mouthState);

@override
String toString() {
  return 'TalkingState.speaking(mouthState: $mouthState)';
}


}

/// @nodoc
abstract mixin class $SpeakingStateCopyWith<$Res> implements $TalkingStateCopyWith<$Res> {
  factory $SpeakingStateCopyWith(SpeakingState value, $Res Function(SpeakingState) _then) = _$SpeakingStateCopyWithImpl;
@override @useResult
$Res call({
 MouthState mouthState
});




}
/// @nodoc
class _$SpeakingStateCopyWithImpl<$Res>
    implements $SpeakingStateCopyWith<$Res> {
  _$SpeakingStateCopyWithImpl(this._self, this._then);

  final SpeakingState _self;
  final $Res Function(SpeakingState) _then;

/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mouthState = null,}) {
  return _then(SpeakingState(
null == mouthState ? _self.mouthState : mouthState // ignore: cast_nullable_to_non_nullable
as MouthState,
  ));
}


}

/// @nodoc


class ErrorState implements TalkingState {
  const ErrorState(this.message, [this.mouthState = MouthState.closed]);
  

 final  String message;
@override@JsonKey() final  MouthState mouthState;

/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ErrorStateCopyWith<ErrorState> get copyWith => _$ErrorStateCopyWithImpl<ErrorState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ErrorState&&(identical(other.message, message) || other.message == message)&&(identical(other.mouthState, mouthState) || other.mouthState == mouthState));
}


@override
int get hashCode => Object.hash(runtimeType,message,mouthState);

@override
String toString() {
  return 'TalkingState.error(message: $message, mouthState: $mouthState)';
}


}

/// @nodoc
abstract mixin class $ErrorStateCopyWith<$Res> implements $TalkingStateCopyWith<$Res> {
  factory $ErrorStateCopyWith(ErrorState value, $Res Function(ErrorState) _then) = _$ErrorStateCopyWithImpl;
@override @useResult
$Res call({
 String message, MouthState mouthState
});




}
/// @nodoc
class _$ErrorStateCopyWithImpl<$Res>
    implements $ErrorStateCopyWith<$Res> {
  _$ErrorStateCopyWithImpl(this._self, this._then);

  final ErrorState _self;
  final $Res Function(ErrorState) _then;

/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? mouthState = null,}) {
  return _then(ErrorState(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,null == mouthState ? _self.mouthState : mouthState // ignore: cast_nullable_to_non_nullable
as MouthState,
  ));
}


}

// dart format on
