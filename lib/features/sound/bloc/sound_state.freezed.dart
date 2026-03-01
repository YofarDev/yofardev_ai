// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sound_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SoundState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SoundState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SoundState()';
}


}

/// @nodoc
class $SoundStateCopyWith<$Res>  {
$SoundStateCopyWith(SoundState _, $Res Function(SoundState) __);
}


/// Adds pattern-matching-related methods to [SoundState].
extension SoundStatePatterns on SoundState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SoundInitial value)?  initial,TResult Function( SoundPlaying value)?  playing,TResult Function( SoundError value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SoundInitial() when initial != null:
return initial(_that);case SoundPlaying() when playing != null:
return playing(_that);case SoundError() when error != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SoundInitial value)  initial,required TResult Function( SoundPlaying value)  playing,required TResult Function( SoundError value)  error,}){
final _that = this;
switch (_that) {
case SoundInitial():
return initial(_that);case SoundPlaying():
return playing(_that);case SoundError():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SoundInitial value)?  initial,TResult? Function( SoundPlaying value)?  playing,TResult? Function( SoundError value)?  error,}){
final _that = this;
switch (_that) {
case SoundInitial() when initial != null:
return initial(_that);case SoundPlaying() when playing != null:
return playing(_that);case SoundError() when error != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  initial,TResult Function( String soundName)?  playing,TResult Function( String message)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SoundInitial() when initial != null:
return initial();case SoundPlaying() when playing != null:
return playing(_that.soundName);case SoundError() when error != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  initial,required TResult Function( String soundName)  playing,required TResult Function( String message)  error,}) {final _that = this;
switch (_that) {
case SoundInitial():
return initial();case SoundPlaying():
return playing(_that.soundName);case SoundError():
return error(_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  initial,TResult? Function( String soundName)?  playing,TResult? Function( String message)?  error,}) {final _that = this;
switch (_that) {
case SoundInitial() when initial != null:
return initial();case SoundPlaying() when playing != null:
return playing(_that.soundName);case SoundError() when error != null:
return error(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class SoundInitial implements SoundState {
  const SoundInitial();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SoundInitial);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SoundState.initial()';
}


}




/// @nodoc


class SoundPlaying implements SoundState {
  const SoundPlaying(this.soundName);
  

 final  String soundName;

/// Create a copy of SoundState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SoundPlayingCopyWith<SoundPlaying> get copyWith => _$SoundPlayingCopyWithImpl<SoundPlaying>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SoundPlaying&&(identical(other.soundName, soundName) || other.soundName == soundName));
}


@override
int get hashCode => Object.hash(runtimeType,soundName);

@override
String toString() {
  return 'SoundState.playing(soundName: $soundName)';
}


}

/// @nodoc
abstract mixin class $SoundPlayingCopyWith<$Res> implements $SoundStateCopyWith<$Res> {
  factory $SoundPlayingCopyWith(SoundPlaying value, $Res Function(SoundPlaying) _then) = _$SoundPlayingCopyWithImpl;
@useResult
$Res call({
 String soundName
});




}
/// @nodoc
class _$SoundPlayingCopyWithImpl<$Res>
    implements $SoundPlayingCopyWith<$Res> {
  _$SoundPlayingCopyWithImpl(this._self, this._then);

  final SoundPlaying _self;
  final $Res Function(SoundPlaying) _then;

/// Create a copy of SoundState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? soundName = null,}) {
  return _then(SoundPlaying(
null == soundName ? _self.soundName : soundName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class SoundError implements SoundState {
  const SoundError(this.message);
  

 final  String message;

/// Create a copy of SoundState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SoundErrorCopyWith<SoundError> get copyWith => _$SoundErrorCopyWithImpl<SoundError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SoundError&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'SoundState.error(message: $message)';
}


}

/// @nodoc
abstract mixin class $SoundErrorCopyWith<$Res> implements $SoundStateCopyWith<$Res> {
  factory $SoundErrorCopyWith(SoundError value, $Res Function(SoundError) _then) = _$SoundErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$SoundErrorCopyWithImpl<$Res>
    implements $SoundErrorCopyWith<$Res> {
  _$SoundErrorCopyWithImpl(this._self, this._then);

  final SoundError _self;
  final $Res Function(SoundError) _then;

/// Create a copy of SoundState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(SoundError(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
