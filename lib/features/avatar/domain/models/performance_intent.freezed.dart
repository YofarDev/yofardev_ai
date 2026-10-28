// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'performance_intent.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PerformanceIntent {

 EmotionVector get emotion; ActionUnits get face; GazeTarget get gaze; bool get speaking; AvatarGesture? get pendingGesture; int get gestureSerial; String? get activeTool;
/// Create a copy of PerformanceIntent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PerformanceIntentCopyWith<PerformanceIntent> get copyWith => _$PerformanceIntentCopyWithImpl<PerformanceIntent>(this as PerformanceIntent, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PerformanceIntent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PerformanceIntent&&(identical(other.emotion, _this.emotion) || other.emotion == _this.emotion)&&(identical(other.face, _this.face) || other.face == _this.face)&&(identical(other.gaze, _this.gaze) || other.gaze == _this.gaze)&&(identical(other.speaking, _this.speaking) || other.speaking == _this.speaking)&&(identical(other.pendingGesture, _this.pendingGesture) || other.pendingGesture == _this.pendingGesture)&&(identical(other.gestureSerial, _this.gestureSerial) || other.gestureSerial == _this.gestureSerial)&&(identical(other.activeTool, _this.activeTool) || other.activeTool == _this.activeTool));
}


@override
int get hashCode {
  final _this = this as PerformanceIntent;
  return Object.hash(runtimeType,_this.emotion,_this.face,_this.gaze,_this.speaking,_this.pendingGesture,_this.gestureSerial,_this.activeTool);
}

@override
String toString() {
  final _this = this as PerformanceIntent;
  return 'PerformanceIntent(emotion: ${_this.emotion}, face: ${_this.face}, gaze: ${_this.gaze}, speaking: ${_this.speaking}, pendingGesture: ${_this.pendingGesture}, gestureSerial: ${_this.gestureSerial}, activeTool: ${_this.activeTool})';
}


}

/// @nodoc
abstract mixin class $PerformanceIntentCopyWith<$Res>  {
  factory $PerformanceIntentCopyWith(PerformanceIntent value, $Res Function(PerformanceIntent) _then) = _$PerformanceIntentCopyWithImpl;
@useResult
$Res call({
 EmotionVector emotion, ActionUnits face, GazeTarget gaze, bool speaking, AvatarGesture? pendingGesture, int gestureSerial, String? activeTool
});


$EmotionVectorCopyWith<$Res> get emotion;$ActionUnitsCopyWith<$Res> get face;$GazeTargetCopyWith<$Res> get gaze;

}
/// @nodoc
class _$PerformanceIntentCopyWithImpl<$Res>
    implements $PerformanceIntentCopyWith<$Res> {
  _$PerformanceIntentCopyWithImpl(this._self, this._then);

  final PerformanceIntent _self;
  final $Res Function(PerformanceIntent) _then;

/// Create a copy of PerformanceIntent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? emotion = null,Object? face = null,Object? gaze = null,Object? speaking = null,Object? pendingGesture = freezed,Object? gestureSerial = null,Object? activeTool = freezed,}) {
  return _then(PerformanceIntent(
emotion: null == emotion ? _self.emotion : emotion // ignore: cast_nullable_to_non_nullable
as EmotionVector,face: null == face ? _self.face : face // ignore: cast_nullable_to_non_nullable
as ActionUnits,gaze: null == gaze ? _self.gaze : gaze // ignore: cast_nullable_to_non_nullable
as GazeTarget,speaking: null == speaking ? _self.speaking : speaking // ignore: cast_nullable_to_non_nullable
as bool,pendingGesture: freezed == pendingGesture ? _self.pendingGesture : pendingGesture // ignore: cast_nullable_to_non_nullable
as AvatarGesture?,gestureSerial: null == gestureSerial ? _self.gestureSerial : gestureSerial // ignore: cast_nullable_to_non_nullable
as int,activeTool: freezed == activeTool ? _self.activeTool : activeTool // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of PerformanceIntent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EmotionVectorCopyWith<$Res> get emotion {
  
  return $EmotionVectorCopyWith<$Res>(_self.emotion, (value) {
    return _then(_self.copyWith(emotion: value));
  });
}/// Create a copy of PerformanceIntent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActionUnitsCopyWith<$Res> get face {
  
  return $ActionUnitsCopyWith<$Res>(_self.face, (value) {
    return _then(_self.copyWith(face: value));
  });
}/// Create a copy of PerformanceIntent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GazeTargetCopyWith<$Res> get gaze {
  
  return $GazeTargetCopyWith<$Res>(_self.gaze, (value) {
    return _then(_self.copyWith(gaze: value));
  });
}
}


/// Adds pattern-matching-related methods to [PerformanceIntent].
extension PerformanceIntentPatterns on PerformanceIntent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PerformanceIntent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PerformanceIntent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PerformanceIntent value)  $default,){
final _that = this;
switch (_that) {
case _PerformanceIntent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PerformanceIntent value)?  $default,){
final _that = this;
switch (_that) {
case _PerformanceIntent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( EmotionVector emotion,  ActionUnits face,  GazeTarget gaze,  bool speaking,  AvatarGesture? pendingGesture,  int gestureSerial,  String? activeTool)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PerformanceIntent() when $default != null:
return $default(_that.emotion,_that.face,_that.gaze,_that.speaking,_that.pendingGesture,_that.gestureSerial,_that.activeTool);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( EmotionVector emotion,  ActionUnits face,  GazeTarget gaze,  bool speaking,  AvatarGesture? pendingGesture,  int gestureSerial,  String? activeTool)  $default,) {final _that = this;
switch (_that) {
case _PerformanceIntent():
return $default(_that.emotion,_that.face,_that.gaze,_that.speaking,_that.pendingGesture,_that.gestureSerial,_that.activeTool);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( EmotionVector emotion,  ActionUnits face,  GazeTarget gaze,  bool speaking,  AvatarGesture? pendingGesture,  int gestureSerial,  String? activeTool)?  $default,) {final _that = this;
switch (_that) {
case _PerformanceIntent() when $default != null:
return $default(_that.emotion,_that.face,_that.gaze,_that.speaking,_that.pendingGesture,_that.gestureSerial,_that.activeTool);case _:
  return null;

}
}

}

/// @nodoc


class _PerformanceIntent implements PerformanceIntent {
  const _PerformanceIntent({this.emotion = const EmotionVector(), this.face = ActionUnits.neutral, this.gaze = const GazeTarget.user(), this.speaking = false, this.pendingGesture, this.gestureSerial = 0, this.activeTool});
  

@override@JsonKey() final  EmotionVector emotion;
@override@JsonKey() final  ActionUnits face;
@override@JsonKey() final  GazeTarget gaze;
@override@JsonKey() final  bool speaking;
@override final  AvatarGesture? pendingGesture;
@override@JsonKey() final  int gestureSerial;
@override final  String? activeTool;

/// Create a copy of PerformanceIntent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PerformanceIntentCopyWith<_PerformanceIntent> get copyWith => __$PerformanceIntentCopyWithImpl<_PerformanceIntent>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PerformanceIntent&&(identical(other.emotion, emotion) || other.emotion == emotion)&&(identical(other.face, face) || other.face == face)&&(identical(other.gaze, gaze) || other.gaze == gaze)&&(identical(other.speaking, speaking) || other.speaking == speaking)&&(identical(other.pendingGesture, pendingGesture) || other.pendingGesture == pendingGesture)&&(identical(other.gestureSerial, gestureSerial) || other.gestureSerial == gestureSerial)&&(identical(other.activeTool, activeTool) || other.activeTool == activeTool));
}


@override
int get hashCode {
    return Object.hash(runtimeType,emotion,face,gaze,speaking,pendingGesture,gestureSerial,activeTool);
}

@override
String toString() {
    return 'PerformanceIntent(emotion: $emotion, face: $face, gaze: $gaze, speaking: $speaking, pendingGesture: $pendingGesture, gestureSerial: $gestureSerial, activeTool: $activeTool)';
}


}

/// @nodoc
abstract mixin class _$PerformanceIntentCopyWith<$Res> implements $PerformanceIntentCopyWith<$Res> {
  factory _$PerformanceIntentCopyWith(_PerformanceIntent value, $Res Function(_PerformanceIntent) _then) = __$PerformanceIntentCopyWithImpl;
@override @useResult
$Res call({
 EmotionVector emotion, ActionUnits face, GazeTarget gaze, bool speaking, AvatarGesture? pendingGesture, int gestureSerial, String? activeTool
});


@override $EmotionVectorCopyWith<$Res> get emotion;@override $ActionUnitsCopyWith<$Res> get face;@override $GazeTargetCopyWith<$Res> get gaze;

}
/// @nodoc
class __$PerformanceIntentCopyWithImpl<$Res>
    implements _$PerformanceIntentCopyWith<$Res> {
  __$PerformanceIntentCopyWithImpl(this._self, this._then);

  final _PerformanceIntent _self;
  final $Res Function(_PerformanceIntent) _then;

/// Create a copy of PerformanceIntent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? emotion = null,Object? face = null,Object? gaze = null,Object? speaking = null,Object? pendingGesture = freezed,Object? gestureSerial = null,Object? activeTool = freezed,}) {
  return _then(_PerformanceIntent(
emotion: null == emotion ? _self.emotion : emotion // ignore: cast_nullable_to_non_nullable
as EmotionVector,face: null == face ? _self.face : face // ignore: cast_nullable_to_non_nullable
as ActionUnits,gaze: null == gaze ? _self.gaze : gaze // ignore: cast_nullable_to_non_nullable
as GazeTarget,speaking: null == speaking ? _self.speaking : speaking // ignore: cast_nullable_to_non_nullable
as bool,pendingGesture: freezed == pendingGesture ? _self.pendingGesture : pendingGesture // ignore: cast_nullable_to_non_nullable
as AvatarGesture?,gestureSerial: null == gestureSerial ? _self.gestureSerial : gestureSerial // ignore: cast_nullable_to_non_nullable
as int,activeTool: freezed == activeTool ? _self.activeTool : activeTool // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of PerformanceIntent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EmotionVectorCopyWith<$Res> get emotion {
  
  return $EmotionVectorCopyWith<$Res>(_self.emotion, (value) {
    return _then(_self.copyWith(emotion: value));
  });
}/// Create a copy of PerformanceIntent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActionUnitsCopyWith<$Res> get face {
  
  return $ActionUnitsCopyWith<$Res>(_self.face, (value) {
    return _then(_self.copyWith(face: value));
  });
}/// Create a copy of PerformanceIntent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GazeTargetCopyWith<$Res> get gaze {
  
  return $GazeTargetCopyWith<$Res>(_self.gaze, (value) {
    return _then(_self.copyWith(gaze: value));
  });
}
}

// dart format on
