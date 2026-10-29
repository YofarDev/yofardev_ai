// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'avatar_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AvatarState {

 AvatarStatus get status; AvatarStatusAnimation get statusAnimation; double get baseOriginalWidth; double get baseOriginalHeight; double get scaleFactor; Avatar get avatar; AvatarConfig get avatarConfig; AvatarSpecials get previousSpecialsState; BackgroundTransition get backgroundTransition; AvatarMood get mood; AvatarScene get scene; ({AvatarGesture gesture, int seq,}) get gestureEvent; ({SceneEvent sceneEvent, int seq,}) get sceneEvent; AvatarSpecials get presence;/// Where the head should look, from the director's gaze.
 HeadTarget get headTarget;/// The prop held, from the director's intent (written to Rive `prop`).
 AvatarProp get prop;
/// Create a copy of AvatarState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvatarStateCopyWith<AvatarState> get copyWith => _$AvatarStateCopyWithImpl<AvatarState>(this as AvatarState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AvatarState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvatarState&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.statusAnimation, _this.statusAnimation) || other.statusAnimation == _this.statusAnimation)&&(identical(other.baseOriginalWidth, _this.baseOriginalWidth) || other.baseOriginalWidth == _this.baseOriginalWidth)&&(identical(other.baseOriginalHeight, _this.baseOriginalHeight) || other.baseOriginalHeight == _this.baseOriginalHeight)&&(identical(other.scaleFactor, _this.scaleFactor) || other.scaleFactor == _this.scaleFactor)&&(identical(other.avatar, _this.avatar) || other.avatar == _this.avatar)&&(identical(other.avatarConfig, _this.avatarConfig) || other.avatarConfig == _this.avatarConfig)&&(identical(other.previousSpecialsState, _this.previousSpecialsState) || other.previousSpecialsState == _this.previousSpecialsState)&&(identical(other.backgroundTransition, _this.backgroundTransition) || other.backgroundTransition == _this.backgroundTransition)&&(identical(other.mood, _this.mood) || other.mood == _this.mood)&&(identical(other.scene, _this.scene) || other.scene == _this.scene)&&(identical(other.gestureEvent, _this.gestureEvent) || other.gestureEvent == _this.gestureEvent)&&(identical(other.sceneEvent, _this.sceneEvent) || other.sceneEvent == _this.sceneEvent)&&(identical(other.presence, _this.presence) || other.presence == _this.presence)&&(identical(other.headTarget, _this.headTarget) || other.headTarget == _this.headTarget)&&(identical(other.prop, _this.prop) || other.prop == _this.prop));
}


@override
int get hashCode {
  final _this = this as AvatarState;
  return Object.hash(runtimeType,_this.status,_this.statusAnimation,_this.baseOriginalWidth,_this.baseOriginalHeight,_this.scaleFactor,_this.avatar,_this.avatarConfig,_this.previousSpecialsState,_this.backgroundTransition,_this.mood,_this.scene,_this.gestureEvent,_this.sceneEvent,_this.presence,_this.headTarget,_this.prop);
}

@override
String toString() {
  final _this = this as AvatarState;
  return 'AvatarState(status: ${_this.status}, statusAnimation: ${_this.statusAnimation}, baseOriginalWidth: ${_this.baseOriginalWidth}, baseOriginalHeight: ${_this.baseOriginalHeight}, scaleFactor: ${_this.scaleFactor}, avatar: ${_this.avatar}, avatarConfig: ${_this.avatarConfig}, previousSpecialsState: ${_this.previousSpecialsState}, backgroundTransition: ${_this.backgroundTransition}, mood: ${_this.mood}, scene: ${_this.scene}, gestureEvent: ${_this.gestureEvent}, sceneEvent: ${_this.sceneEvent}, presence: ${_this.presence}, headTarget: ${_this.headTarget}, prop: ${_this.prop})';
}


}

/// @nodoc
abstract mixin class $AvatarStateCopyWith<$Res>  {
  factory $AvatarStateCopyWith(AvatarState value, $Res Function(AvatarState) _then) = _$AvatarStateCopyWithImpl;
@useResult
$Res call({
 AvatarStatus status, AvatarStatusAnimation statusAnimation, double baseOriginalWidth, double baseOriginalHeight, double scaleFactor, Avatar avatar, AvatarConfig avatarConfig, AvatarSpecials previousSpecialsState, BackgroundTransition backgroundTransition, AvatarMood mood, AvatarScene scene, ({AvatarGesture gesture, int seq,}) gestureEvent, ({SceneEvent sceneEvent, int seq,}) sceneEvent, AvatarSpecials presence, HeadTarget headTarget, AvatarProp prop
});


$AvatarCopyWith<$Res> get avatar;$AvatarConfigCopyWith<$Res> get avatarConfig;

}
/// @nodoc
class _$AvatarStateCopyWithImpl<$Res>
    implements $AvatarStateCopyWith<$Res> {
  _$AvatarStateCopyWithImpl(this._self, this._then);

  final AvatarState _self;
  final $Res Function(AvatarState) _then;

/// Create a copy of AvatarState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? statusAnimation = null,Object? baseOriginalWidth = null,Object? baseOriginalHeight = null,Object? scaleFactor = null,Object? avatar = null,Object? avatarConfig = null,Object? previousSpecialsState = null,Object? backgroundTransition = null,Object? mood = null,Object? scene = null,Object? gestureEvent = null,Object? sceneEvent = null,Object? presence = null,Object? headTarget = null,Object? prop = null,}) {
  return _then(AvatarState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AvatarStatus,statusAnimation: null == statusAnimation ? _self.statusAnimation : statusAnimation // ignore: cast_nullable_to_non_nullable
as AvatarStatusAnimation,baseOriginalWidth: null == baseOriginalWidth ? _self.baseOriginalWidth : baseOriginalWidth // ignore: cast_nullable_to_non_nullable
as double,baseOriginalHeight: null == baseOriginalHeight ? _self.baseOriginalHeight : baseOriginalHeight // ignore: cast_nullable_to_non_nullable
as double,scaleFactor: null == scaleFactor ? _self.scaleFactor : scaleFactor // ignore: cast_nullable_to_non_nullable
as double,avatar: null == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as Avatar,avatarConfig: null == avatarConfig ? _self.avatarConfig : avatarConfig // ignore: cast_nullable_to_non_nullable
as AvatarConfig,previousSpecialsState: null == previousSpecialsState ? _self.previousSpecialsState : previousSpecialsState // ignore: cast_nullable_to_non_nullable
as AvatarSpecials,backgroundTransition: null == backgroundTransition ? _self.backgroundTransition : backgroundTransition // ignore: cast_nullable_to_non_nullable
as BackgroundTransition,mood: null == mood ? _self.mood : mood // ignore: cast_nullable_to_non_nullable
as AvatarMood,scene: null == scene ? _self.scene : scene // ignore: cast_nullable_to_non_nullable
as AvatarScene,gestureEvent: null == gestureEvent ? _self.gestureEvent : gestureEvent // ignore: cast_nullable_to_non_nullable
as ({AvatarGesture gesture, int seq,}),sceneEvent: null == sceneEvent ? _self.sceneEvent : sceneEvent // ignore: cast_nullable_to_non_nullable
as ({SceneEvent sceneEvent, int seq,}),presence: null == presence ? _self.presence : presence // ignore: cast_nullable_to_non_nullable
as AvatarSpecials,headTarget: null == headTarget ? _self.headTarget : headTarget // ignore: cast_nullable_to_non_nullable
as HeadTarget,prop: null == prop ? _self.prop : prop // ignore: cast_nullable_to_non_nullable
as AvatarProp,
  ));
}
/// Create a copy of AvatarState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AvatarCopyWith<$Res> get avatar {
  
  return $AvatarCopyWith<$Res>(_self.avatar, (value) {
    return _then(_self.copyWith(avatar: value));
  });
}/// Create a copy of AvatarState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AvatarConfigCopyWith<$Res> get avatarConfig {
  
  return $AvatarConfigCopyWith<$Res>(_self.avatarConfig, (value) {
    return _then(_self.copyWith(avatarConfig: value));
  });
}
}


/// Adds pattern-matching-related methods to [AvatarState].
extension AvatarStatePatterns on AvatarState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AvatarState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AvatarState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AvatarState value)  $default,){
final _that = this;
switch (_that) {
case _AvatarState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AvatarState value)?  $default,){
final _that = this;
switch (_that) {
case _AvatarState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AvatarStatus status,  AvatarStatusAnimation statusAnimation,  double baseOriginalWidth,  double baseOriginalHeight,  double scaleFactor,  Avatar avatar,  AvatarConfig avatarConfig,  AvatarSpecials previousSpecialsState,  BackgroundTransition backgroundTransition,  AvatarMood mood,  AvatarScene scene,  ({AvatarGesture gesture, int seq,}) gestureEvent,  ({SceneEvent sceneEvent, int seq,}) sceneEvent,  AvatarSpecials presence,  HeadTarget headTarget,  AvatarProp prop)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AvatarState() when $default != null:
return $default(_that.status,_that.statusAnimation,_that.baseOriginalWidth,_that.baseOriginalHeight,_that.scaleFactor,_that.avatar,_that.avatarConfig,_that.previousSpecialsState,_that.backgroundTransition,_that.mood,_that.scene,_that.gestureEvent,_that.sceneEvent,_that.presence,_that.headTarget,_that.prop);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AvatarStatus status,  AvatarStatusAnimation statusAnimation,  double baseOriginalWidth,  double baseOriginalHeight,  double scaleFactor,  Avatar avatar,  AvatarConfig avatarConfig,  AvatarSpecials previousSpecialsState,  BackgroundTransition backgroundTransition,  AvatarMood mood,  AvatarScene scene,  ({AvatarGesture gesture, int seq,}) gestureEvent,  ({SceneEvent sceneEvent, int seq,}) sceneEvent,  AvatarSpecials presence,  HeadTarget headTarget,  AvatarProp prop)  $default,) {final _that = this;
switch (_that) {
case _AvatarState():
return $default(_that.status,_that.statusAnimation,_that.baseOriginalWidth,_that.baseOriginalHeight,_that.scaleFactor,_that.avatar,_that.avatarConfig,_that.previousSpecialsState,_that.backgroundTransition,_that.mood,_that.scene,_that.gestureEvent,_that.sceneEvent,_that.presence,_that.headTarget,_that.prop);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AvatarStatus status,  AvatarStatusAnimation statusAnimation,  double baseOriginalWidth,  double baseOriginalHeight,  double scaleFactor,  Avatar avatar,  AvatarConfig avatarConfig,  AvatarSpecials previousSpecialsState,  BackgroundTransition backgroundTransition,  AvatarMood mood,  AvatarScene scene,  ({AvatarGesture gesture, int seq,}) gestureEvent,  ({SceneEvent sceneEvent, int seq,}) sceneEvent,  AvatarSpecials presence,  HeadTarget headTarget,  AvatarProp prop)?  $default,) {final _that = this;
switch (_that) {
case _AvatarState() when $default != null:
return $default(_that.status,_that.statusAnimation,_that.baseOriginalWidth,_that.baseOriginalHeight,_that.scaleFactor,_that.avatar,_that.avatarConfig,_that.previousSpecialsState,_that.backgroundTransition,_that.mood,_that.scene,_that.gestureEvent,_that.sceneEvent,_that.presence,_that.headTarget,_that.prop);case _:
  return null;

}
}

}

/// @nodoc


class _AvatarState extends AvatarState {
  const _AvatarState({this.status = AvatarStatus.initial, this.statusAnimation = AvatarStatusAnimation.initial, this.baseOriginalWidth = 0.0, this.baseOriginalHeight = 0.0, this.scaleFactor = 1.0, required this.avatar, required this.avatarConfig, this.previousSpecialsState = AvatarSpecials.onScreen, this.backgroundTransition = BackgroundTransition.none, this.mood = AvatarMood.neutral, this.scene = AvatarScene.defaultScene, this.gestureEvent = const (gesture: AvatarGesture.wave, seq: 0), this.sceneEvent = const (sceneEvent: SceneEvent.lightsOff, seq: 0), this.presence = AvatarSpecials.onScreen, this.headTarget = HeadTarget.zero, this.prop = AvatarProp.none}): super._();
  

@override@JsonKey() final  AvatarStatus status;
@override@JsonKey() final  AvatarStatusAnimation statusAnimation;
@override@JsonKey() final  double baseOriginalWidth;
@override@JsonKey() final  double baseOriginalHeight;
@override@JsonKey() final  double scaleFactor;
@override final  Avatar avatar;
@override final  AvatarConfig avatarConfig;
@override@JsonKey() final  AvatarSpecials previousSpecialsState;
@override@JsonKey() final  BackgroundTransition backgroundTransition;
@override@JsonKey() final  AvatarMood mood;
@override@JsonKey() final  AvatarScene scene;
@override@JsonKey() final  ({AvatarGesture gesture, int seq,}) gestureEvent;
@override@JsonKey() final  ({SceneEvent sceneEvent, int seq,}) sceneEvent;
@override@JsonKey() final  AvatarSpecials presence;
/// Where the head should look, from the director's gaze.
@override@JsonKey() final  HeadTarget headTarget;
/// The prop held, from the director's intent (written to Rive `prop`).
@override@JsonKey() final  AvatarProp prop;

/// Create a copy of AvatarState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AvatarStateCopyWith<_AvatarState> get copyWith => __$AvatarStateCopyWithImpl<_AvatarState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AvatarState&&(identical(other.status, status) || other.status == status)&&(identical(other.statusAnimation, statusAnimation) || other.statusAnimation == statusAnimation)&&(identical(other.baseOriginalWidth, baseOriginalWidth) || other.baseOriginalWidth == baseOriginalWidth)&&(identical(other.baseOriginalHeight, baseOriginalHeight) || other.baseOriginalHeight == baseOriginalHeight)&&(identical(other.scaleFactor, scaleFactor) || other.scaleFactor == scaleFactor)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.avatarConfig, avatarConfig) || other.avatarConfig == avatarConfig)&&(identical(other.previousSpecialsState, previousSpecialsState) || other.previousSpecialsState == previousSpecialsState)&&(identical(other.backgroundTransition, backgroundTransition) || other.backgroundTransition == backgroundTransition)&&(identical(other.mood, mood) || other.mood == mood)&&(identical(other.scene, scene) || other.scene == scene)&&(identical(other.gestureEvent, gestureEvent) || other.gestureEvent == gestureEvent)&&(identical(other.sceneEvent, sceneEvent) || other.sceneEvent == sceneEvent)&&(identical(other.presence, presence) || other.presence == presence)&&(identical(other.headTarget, headTarget) || other.headTarget == headTarget)&&(identical(other.prop, prop) || other.prop == prop));
}


@override
int get hashCode {
    return Object.hash(runtimeType,status,statusAnimation,baseOriginalWidth,baseOriginalHeight,scaleFactor,avatar,avatarConfig,previousSpecialsState,backgroundTransition,mood,scene,gestureEvent,sceneEvent,presence,headTarget,prop);
}

@override
String toString() {
    return 'AvatarState(status: $status, statusAnimation: $statusAnimation, baseOriginalWidth: $baseOriginalWidth, baseOriginalHeight: $baseOriginalHeight, scaleFactor: $scaleFactor, avatar: $avatar, avatarConfig: $avatarConfig, previousSpecialsState: $previousSpecialsState, backgroundTransition: $backgroundTransition, mood: $mood, scene: $scene, gestureEvent: $gestureEvent, sceneEvent: $sceneEvent, presence: $presence, headTarget: $headTarget, prop: $prop)';
}


}

/// @nodoc
abstract mixin class _$AvatarStateCopyWith<$Res> implements $AvatarStateCopyWith<$Res> {
  factory _$AvatarStateCopyWith(_AvatarState value, $Res Function(_AvatarState) _then) = __$AvatarStateCopyWithImpl;
@override @useResult
$Res call({
 AvatarStatus status, AvatarStatusAnimation statusAnimation, double baseOriginalWidth, double baseOriginalHeight, double scaleFactor, Avatar avatar, AvatarConfig avatarConfig, AvatarSpecials previousSpecialsState, BackgroundTransition backgroundTransition, AvatarMood mood, AvatarScene scene, ({AvatarGesture gesture, int seq,}) gestureEvent, ({SceneEvent sceneEvent, int seq,}) sceneEvent, AvatarSpecials presence, HeadTarget headTarget, AvatarProp prop
});


@override $AvatarCopyWith<$Res> get avatar;@override $AvatarConfigCopyWith<$Res> get avatarConfig;

}
/// @nodoc
class __$AvatarStateCopyWithImpl<$Res>
    implements _$AvatarStateCopyWith<$Res> {
  __$AvatarStateCopyWithImpl(this._self, this._then);

  final _AvatarState _self;
  final $Res Function(_AvatarState) _then;

/// Create a copy of AvatarState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? statusAnimation = null,Object? baseOriginalWidth = null,Object? baseOriginalHeight = null,Object? scaleFactor = null,Object? avatar = null,Object? avatarConfig = null,Object? previousSpecialsState = null,Object? backgroundTransition = null,Object? mood = null,Object? scene = null,Object? gestureEvent = null,Object? sceneEvent = null,Object? presence = null,Object? headTarget = null,Object? prop = null,}) {
  return _then(_AvatarState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AvatarStatus,statusAnimation: null == statusAnimation ? _self.statusAnimation : statusAnimation // ignore: cast_nullable_to_non_nullable
as AvatarStatusAnimation,baseOriginalWidth: null == baseOriginalWidth ? _self.baseOriginalWidth : baseOriginalWidth // ignore: cast_nullable_to_non_nullable
as double,baseOriginalHeight: null == baseOriginalHeight ? _self.baseOriginalHeight : baseOriginalHeight // ignore: cast_nullable_to_non_nullable
as double,scaleFactor: null == scaleFactor ? _self.scaleFactor : scaleFactor // ignore: cast_nullable_to_non_nullable
as double,avatar: null == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as Avatar,avatarConfig: null == avatarConfig ? _self.avatarConfig : avatarConfig // ignore: cast_nullable_to_non_nullable
as AvatarConfig,previousSpecialsState: null == previousSpecialsState ? _self.previousSpecialsState : previousSpecialsState // ignore: cast_nullable_to_non_nullable
as AvatarSpecials,backgroundTransition: null == backgroundTransition ? _self.backgroundTransition : backgroundTransition // ignore: cast_nullable_to_non_nullable
as BackgroundTransition,mood: null == mood ? _self.mood : mood // ignore: cast_nullable_to_non_nullable
as AvatarMood,scene: null == scene ? _self.scene : scene // ignore: cast_nullable_to_non_nullable
as AvatarScene,gestureEvent: null == gestureEvent ? _self.gestureEvent : gestureEvent // ignore: cast_nullable_to_non_nullable
as ({AvatarGesture gesture, int seq,}),sceneEvent: null == sceneEvent ? _self.sceneEvent : sceneEvent // ignore: cast_nullable_to_non_nullable
as ({SceneEvent sceneEvent, int seq,}),presence: null == presence ? _self.presence : presence // ignore: cast_nullable_to_non_nullable
as AvatarSpecials,headTarget: null == headTarget ? _self.headTarget : headTarget // ignore: cast_nullable_to_non_nullable
as HeadTarget,prop: null == prop ? _self.prop : prop // ignore: cast_nullable_to_non_nullable
as AvatarProp,
  ));
}

/// Create a copy of AvatarState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AvatarCopyWith<$Res> get avatar {
  
  return $AvatarCopyWith<$Res>(_self.avatar, (value) {
    return _then(_self.copyWith(avatar: value));
  });
}/// Create a copy of AvatarState
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
