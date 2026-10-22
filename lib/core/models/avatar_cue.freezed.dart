// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'avatar_cue.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AvatarCue {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvatarCue);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AvatarCue()';
}


}

/// @nodoc
class $AvatarCueCopyWith<$Res>  {
$AvatarCueCopyWith(AvatarCue _, $Res Function(AvatarCue) __);
}


/// Adds pattern-matching-related methods to [AvatarCue].
extension AvatarCuePatterns on AvatarCue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AvatarCueGesture value)?  gesture,TResult Function( AvatarCueSceneEvent value)?  sceneEvent,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AvatarCueGesture() when gesture != null:
return gesture(_that);case AvatarCueSceneEvent() when sceneEvent != null:
return sceneEvent(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AvatarCueGesture value)  gesture,required TResult Function( AvatarCueSceneEvent value)  sceneEvent,}){
final _that = this;
switch (_that) {
case AvatarCueGesture():
return gesture(_that);case AvatarCueSceneEvent():
return sceneEvent(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AvatarCueGesture value)?  gesture,TResult? Function( AvatarCueSceneEvent value)?  sceneEvent,}){
final _that = this;
switch (_that) {
case AvatarCueGesture() when gesture != null:
return gesture(_that);case AvatarCueSceneEvent() when sceneEvent != null:
return sceneEvent(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( AvatarGesture gesture)?  gesture,TResult Function( SceneEvent sceneEvent)?  sceneEvent,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AvatarCueGesture() when gesture != null:
return gesture(_that.gesture);case AvatarCueSceneEvent() when sceneEvent != null:
return sceneEvent(_that.sceneEvent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( AvatarGesture gesture)  gesture,required TResult Function( SceneEvent sceneEvent)  sceneEvent,}) {final _that = this;
switch (_that) {
case AvatarCueGesture():
return gesture(_that.gesture);case AvatarCueSceneEvent():
return sceneEvent(_that.sceneEvent);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( AvatarGesture gesture)?  gesture,TResult? Function( SceneEvent sceneEvent)?  sceneEvent,}) {final _that = this;
switch (_that) {
case AvatarCueGesture() when gesture != null:
return gesture(_that.gesture);case AvatarCueSceneEvent() when sceneEvent != null:
return sceneEvent(_that.sceneEvent);case _:
  return null;

}
}

}

/// @nodoc


class AvatarCueGesture implements AvatarCue {
  const AvatarCueGesture(this.gesture);
  

 final  AvatarGesture gesture;

/// Create a copy of AvatarCue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvatarCueGestureCopyWith<AvatarCueGesture> get copyWith => _$AvatarCueGestureCopyWithImpl<AvatarCueGesture>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvatarCueGesture&&(identical(other.gesture, gesture) || other.gesture == gesture));
}


@override
int get hashCode => Object.hash(runtimeType,gesture);

@override
String toString() {
  return 'AvatarCue.gesture(gesture: $gesture)';
}


}

/// @nodoc
abstract mixin class $AvatarCueGestureCopyWith<$Res> implements $AvatarCueCopyWith<$Res> {
  factory $AvatarCueGestureCopyWith(AvatarCueGesture value, $Res Function(AvatarCueGesture) _then) = _$AvatarCueGestureCopyWithImpl;
@useResult
$Res call({
 AvatarGesture gesture
});




}
/// @nodoc
class _$AvatarCueGestureCopyWithImpl<$Res>
    implements $AvatarCueGestureCopyWith<$Res> {
  _$AvatarCueGestureCopyWithImpl(this._self, this._then);

  final AvatarCueGesture _self;
  final $Res Function(AvatarCueGesture) _then;

/// Create a copy of AvatarCue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? gesture = null,}) {
  return _then(AvatarCueGesture(
null == gesture ? _self.gesture : gesture // ignore: cast_nullable_to_non_nullable
as AvatarGesture,
  ));
}


}

/// @nodoc


class AvatarCueSceneEvent implements AvatarCue {
  const AvatarCueSceneEvent(this.sceneEvent);
  

 final  SceneEvent sceneEvent;

/// Create a copy of AvatarCue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvatarCueSceneEventCopyWith<AvatarCueSceneEvent> get copyWith => _$AvatarCueSceneEventCopyWithImpl<AvatarCueSceneEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvatarCueSceneEvent&&(identical(other.sceneEvent, sceneEvent) || other.sceneEvent == sceneEvent));
}


@override
int get hashCode => Object.hash(runtimeType,sceneEvent);

@override
String toString() {
  return 'AvatarCue.sceneEvent(sceneEvent: $sceneEvent)';
}


}

/// @nodoc
abstract mixin class $AvatarCueSceneEventCopyWith<$Res> implements $AvatarCueCopyWith<$Res> {
  factory $AvatarCueSceneEventCopyWith(AvatarCueSceneEvent value, $Res Function(AvatarCueSceneEvent) _then) = _$AvatarCueSceneEventCopyWithImpl;
@useResult
$Res call({
 SceneEvent sceneEvent
});




}
/// @nodoc
class _$AvatarCueSceneEventCopyWithImpl<$Res>
    implements $AvatarCueSceneEventCopyWith<$Res> {
  _$AvatarCueSceneEventCopyWithImpl(this._self, this._then);

  final AvatarCueSceneEvent _self;
  final $Res Function(AvatarCueSceneEvent) _then;

/// Create a copy of AvatarCue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sceneEvent = null,}) {
  return _then(AvatarCueSceneEvent(
null == sceneEvent ? _self.sceneEvent : sceneEvent // ignore: cast_nullable_to_non_nullable
as SceneEvent,
  ));
}


}

// dart format on
