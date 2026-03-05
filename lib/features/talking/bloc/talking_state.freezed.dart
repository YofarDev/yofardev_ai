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





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TalkingState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TalkingState()';
}


}

/// @nodoc
class $TalkingStateCopyWith<$Res>  {
$TalkingStateCopyWith(TalkingState _, $Res Function(TalkingState) __);
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
return error(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function()?  waiting,TResult Function()?  generating,TResult Function()?  speaking,TResult Function( String message)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case IdleState() when idle != null:
return idle();case WaitingState() when waiting != null:
return waiting();case GeneratingState() when generating != null:
return generating();case SpeakingState() when speaking != null:
return speaking();case ErrorState() when error != null:
return error(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function()  waiting,required TResult Function()  generating,required TResult Function()  speaking,required TResult Function( String message)  error,}) {final _that = this;
switch (_that) {
case IdleState():
return idle();case WaitingState():
return waiting();case GeneratingState():
return generating();case SpeakingState():
return speaking();case ErrorState():
return error(_that.message);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function()?  waiting,TResult? Function()?  generating,TResult? Function()?  speaking,TResult? Function( String message)?  error,}) {final _that = this;
switch (_that) {
case IdleState() when idle != null:
return idle();case WaitingState() when waiting != null:
return waiting();case GeneratingState() when generating != null:
return generating();case SpeakingState() when speaking != null:
return speaking();case ErrorState() when error != null:
return error(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class IdleState implements TalkingState {
  const IdleState();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IdleState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TalkingState.idle()';
}


}




/// @nodoc


class WaitingState implements TalkingState {
  const WaitingState();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WaitingState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TalkingState.waiting()';
}


}




/// @nodoc


class GeneratingState implements TalkingState {
  const GeneratingState();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GeneratingState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TalkingState.generating()';
}


}




/// @nodoc


class SpeakingState implements TalkingState {
  const SpeakingState();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpeakingState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TalkingState.speaking()';
}


}




/// @nodoc


class ErrorState implements TalkingState {
  const ErrorState(this.message);
  

 final  String message;

/// Create a copy of TalkingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ErrorStateCopyWith<ErrorState> get copyWith => _$ErrorStateCopyWithImpl<ErrorState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ErrorState&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'TalkingState.error(message: $message)';
}


}

/// @nodoc
abstract mixin class $ErrorStateCopyWith<$Res> implements $TalkingStateCopyWith<$Res> {
  factory $ErrorStateCopyWith(ErrorState value, $Res Function(ErrorState) _then) = _$ErrorStateCopyWithImpl;
@useResult
$Res call({
 String message
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
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(ErrorState(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
