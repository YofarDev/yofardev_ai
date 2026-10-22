// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'avatar_animation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AvatarAnimation {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvatarAnimation);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AvatarAnimation()';
}


}

/// @nodoc
class $AvatarAnimationCopyWith<$Res>  {
$AvatarAnimationCopyWith(AvatarAnimation _, $Res Function(AvatarAnimation) __);
}


/// Adds pattern-matching-related methods to [AvatarAnimation].
extension AvatarAnimationPatterns on AvatarAnimation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AvatarAnimationClothes value)?  clothes,TResult Function( AvatarAnimationBackground value)?  background,TResult Function( AvatarAnimationUpdateConfig value)?  updateConfig,TResult Function( AvatarAnimationGesture value)?  gesture,TResult Function( AvatarAnimationSceneEvent value)?  sceneEvent,TResult Function( AvatarAnimationMood value)?  mood,TResult Function( AvatarAnimationPresence value)?  presence,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AvatarAnimationClothes() when clothes != null:
return clothes(_that);case AvatarAnimationBackground() when background != null:
return background(_that);case AvatarAnimationUpdateConfig() when updateConfig != null:
return updateConfig(_that);case AvatarAnimationGesture() when gesture != null:
return gesture(_that);case AvatarAnimationSceneEvent() when sceneEvent != null:
return sceneEvent(_that);case AvatarAnimationMood() when mood != null:
return mood(_that);case AvatarAnimationPresence() when presence != null:
return presence(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AvatarAnimationClothes value)  clothes,required TResult Function( AvatarAnimationBackground value)  background,required TResult Function( AvatarAnimationUpdateConfig value)  updateConfig,required TResult Function( AvatarAnimationGesture value)  gesture,required TResult Function( AvatarAnimationSceneEvent value)  sceneEvent,required TResult Function( AvatarAnimationMood value)  mood,required TResult Function( AvatarAnimationPresence value)  presence,}){
final _that = this;
switch (_that) {
case AvatarAnimationClothes():
return clothes(_that);case AvatarAnimationBackground():
return background(_that);case AvatarAnimationUpdateConfig():
return updateConfig(_that);case AvatarAnimationGesture():
return gesture(_that);case AvatarAnimationSceneEvent():
return sceneEvent(_that);case AvatarAnimationMood():
return mood(_that);case AvatarAnimationPresence():
return presence(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AvatarAnimationClothes value)?  clothes,TResult? Function( AvatarAnimationBackground value)?  background,TResult? Function( AvatarAnimationUpdateConfig value)?  updateConfig,TResult? Function( AvatarAnimationGesture value)?  gesture,TResult? Function( AvatarAnimationSceneEvent value)?  sceneEvent,TResult? Function( AvatarAnimationMood value)?  mood,TResult? Function( AvatarAnimationPresence value)?  presence,}){
final _that = this;
switch (_that) {
case AvatarAnimationClothes() when clothes != null:
return clothes(_that);case AvatarAnimationBackground() when background != null:
return background(_that);case AvatarAnimationUpdateConfig() when updateConfig != null:
return updateConfig(_that);case AvatarAnimationGesture() when gesture != null:
return gesture(_that);case AvatarAnimationSceneEvent() when sceneEvent != null:
return sceneEvent(_that);case AvatarAnimationMood() when mood != null:
return mood(_that);case AvatarAnimationPresence() when presence != null:
return presence(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( bool goingDown)?  clothes,TResult Function( BackgroundTransition transition)?  background,TResult Function( String chatId,  AvatarConfig avatarConfig)?  updateConfig,TResult Function( AvatarGesture gesture)?  gesture,TResult Function( SceneEvent sceneEvent)?  sceneEvent,TResult Function( AvatarMood mood)?  mood,TResult Function( AvatarSpecials presence)?  presence,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AvatarAnimationClothes() when clothes != null:
return clothes(_that.goingDown);case AvatarAnimationBackground() when background != null:
return background(_that.transition);case AvatarAnimationUpdateConfig() when updateConfig != null:
return updateConfig(_that.chatId,_that.avatarConfig);case AvatarAnimationGesture() when gesture != null:
return gesture(_that.gesture);case AvatarAnimationSceneEvent() when sceneEvent != null:
return sceneEvent(_that.sceneEvent);case AvatarAnimationMood() when mood != null:
return mood(_that.mood);case AvatarAnimationPresence() when presence != null:
return presence(_that.presence);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( bool goingDown)  clothes,required TResult Function( BackgroundTransition transition)  background,required TResult Function( String chatId,  AvatarConfig avatarConfig)  updateConfig,required TResult Function( AvatarGesture gesture)  gesture,required TResult Function( SceneEvent sceneEvent)  sceneEvent,required TResult Function( AvatarMood mood)  mood,required TResult Function( AvatarSpecials presence)  presence,}) {final _that = this;
switch (_that) {
case AvatarAnimationClothes():
return clothes(_that.goingDown);case AvatarAnimationBackground():
return background(_that.transition);case AvatarAnimationUpdateConfig():
return updateConfig(_that.chatId,_that.avatarConfig);case AvatarAnimationGesture():
return gesture(_that.gesture);case AvatarAnimationSceneEvent():
return sceneEvent(_that.sceneEvent);case AvatarAnimationMood():
return mood(_that.mood);case AvatarAnimationPresence():
return presence(_that.presence);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( bool goingDown)?  clothes,TResult? Function( BackgroundTransition transition)?  background,TResult? Function( String chatId,  AvatarConfig avatarConfig)?  updateConfig,TResult? Function( AvatarGesture gesture)?  gesture,TResult? Function( SceneEvent sceneEvent)?  sceneEvent,TResult? Function( AvatarMood mood)?  mood,TResult? Function( AvatarSpecials presence)?  presence,}) {final _that = this;
switch (_that) {
case AvatarAnimationClothes() when clothes != null:
return clothes(_that.goingDown);case AvatarAnimationBackground() when background != null:
return background(_that.transition);case AvatarAnimationUpdateConfig() when updateConfig != null:
return updateConfig(_that.chatId,_that.avatarConfig);case AvatarAnimationGesture() when gesture != null:
return gesture(_that.gesture);case AvatarAnimationSceneEvent() when sceneEvent != null:
return sceneEvent(_that.sceneEvent);case AvatarAnimationMood() when mood != null:
return mood(_that.mood);case AvatarAnimationPresence() when presence != null:
return presence(_that.presence);case _:
  return null;

}
}

}

/// @nodoc


class AvatarAnimationClothes implements AvatarAnimation {
  const AvatarAnimationClothes(this.goingDown);
  

 final  bool goingDown;

/// Create a copy of AvatarAnimation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvatarAnimationClothesCopyWith<AvatarAnimationClothes> get copyWith => _$AvatarAnimationClothesCopyWithImpl<AvatarAnimationClothes>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvatarAnimationClothes&&(identical(other.goingDown, goingDown) || other.goingDown == goingDown));
}


@override
int get hashCode => Object.hash(runtimeType,goingDown);

@override
String toString() {
  return 'AvatarAnimation.clothes(goingDown: $goingDown)';
}


}

/// @nodoc
abstract mixin class $AvatarAnimationClothesCopyWith<$Res> implements $AvatarAnimationCopyWith<$Res> {
  factory $AvatarAnimationClothesCopyWith(AvatarAnimationClothes value, $Res Function(AvatarAnimationClothes) _then) = _$AvatarAnimationClothesCopyWithImpl;
@useResult
$Res call({
 bool goingDown
});




}
/// @nodoc
class _$AvatarAnimationClothesCopyWithImpl<$Res>
    implements $AvatarAnimationClothesCopyWith<$Res> {
  _$AvatarAnimationClothesCopyWithImpl(this._self, this._then);

  final AvatarAnimationClothes _self;
  final $Res Function(AvatarAnimationClothes) _then;

/// Create a copy of AvatarAnimation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? goingDown = null,}) {
  return _then(AvatarAnimationClothes(
null == goingDown ? _self.goingDown : goingDown // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class AvatarAnimationBackground implements AvatarAnimation {
  const AvatarAnimationBackground(this.transition);
  

 final  BackgroundTransition transition;

/// Create a copy of AvatarAnimation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvatarAnimationBackgroundCopyWith<AvatarAnimationBackground> get copyWith => _$AvatarAnimationBackgroundCopyWithImpl<AvatarAnimationBackground>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvatarAnimationBackground&&(identical(other.transition, transition) || other.transition == transition));
}


@override
int get hashCode => Object.hash(runtimeType,transition);

@override
String toString() {
  return 'AvatarAnimation.background(transition: $transition)';
}


}

/// @nodoc
abstract mixin class $AvatarAnimationBackgroundCopyWith<$Res> implements $AvatarAnimationCopyWith<$Res> {
  factory $AvatarAnimationBackgroundCopyWith(AvatarAnimationBackground value, $Res Function(AvatarAnimationBackground) _then) = _$AvatarAnimationBackgroundCopyWithImpl;
@useResult
$Res call({
 BackgroundTransition transition
});




}
/// @nodoc
class _$AvatarAnimationBackgroundCopyWithImpl<$Res>
    implements $AvatarAnimationBackgroundCopyWith<$Res> {
  _$AvatarAnimationBackgroundCopyWithImpl(this._self, this._then);

  final AvatarAnimationBackground _self;
  final $Res Function(AvatarAnimationBackground) _then;

/// Create a copy of AvatarAnimation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? transition = null,}) {
  return _then(AvatarAnimationBackground(
null == transition ? _self.transition : transition // ignore: cast_nullable_to_non_nullable
as BackgroundTransition,
  ));
}


}

/// @nodoc


class AvatarAnimationUpdateConfig implements AvatarAnimation {
  const AvatarAnimationUpdateConfig(this.chatId, this.avatarConfig);
  

 final  String chatId;
 final  AvatarConfig avatarConfig;

/// Create a copy of AvatarAnimation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvatarAnimationUpdateConfigCopyWith<AvatarAnimationUpdateConfig> get copyWith => _$AvatarAnimationUpdateConfigCopyWithImpl<AvatarAnimationUpdateConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvatarAnimationUpdateConfig&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.avatarConfig, avatarConfig) || other.avatarConfig == avatarConfig));
}


@override
int get hashCode => Object.hash(runtimeType,chatId,avatarConfig);

@override
String toString() {
  return 'AvatarAnimation.updateConfig(chatId: $chatId, avatarConfig: $avatarConfig)';
}


}

/// @nodoc
abstract mixin class $AvatarAnimationUpdateConfigCopyWith<$Res> implements $AvatarAnimationCopyWith<$Res> {
  factory $AvatarAnimationUpdateConfigCopyWith(AvatarAnimationUpdateConfig value, $Res Function(AvatarAnimationUpdateConfig) _then) = _$AvatarAnimationUpdateConfigCopyWithImpl;
@useResult
$Res call({
 String chatId, AvatarConfig avatarConfig
});


$AvatarConfigCopyWith<$Res> get avatarConfig;

}
/// @nodoc
class _$AvatarAnimationUpdateConfigCopyWithImpl<$Res>
    implements $AvatarAnimationUpdateConfigCopyWith<$Res> {
  _$AvatarAnimationUpdateConfigCopyWithImpl(this._self, this._then);

  final AvatarAnimationUpdateConfig _self;
  final $Res Function(AvatarAnimationUpdateConfig) _then;

/// Create a copy of AvatarAnimation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? chatId = null,Object? avatarConfig = null,}) {
  return _then(AvatarAnimationUpdateConfig(
null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,null == avatarConfig ? _self.avatarConfig : avatarConfig // ignore: cast_nullable_to_non_nullable
as AvatarConfig,
  ));
}

/// Create a copy of AvatarAnimation
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AvatarConfigCopyWith<$Res> get avatarConfig {
  
  return $AvatarConfigCopyWith<$Res>(_self.avatarConfig, (value) {
    return _then(_self.copyWith(avatarConfig: value));
  });
}
}

/// @nodoc


class AvatarAnimationGesture implements AvatarAnimation {
  const AvatarAnimationGesture(this.gesture);
  

 final  AvatarGesture gesture;

/// Create a copy of AvatarAnimation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvatarAnimationGestureCopyWith<AvatarAnimationGesture> get copyWith => _$AvatarAnimationGestureCopyWithImpl<AvatarAnimationGesture>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvatarAnimationGesture&&(identical(other.gesture, gesture) || other.gesture == gesture));
}


@override
int get hashCode => Object.hash(runtimeType,gesture);

@override
String toString() {
  return 'AvatarAnimation.gesture(gesture: $gesture)';
}


}

/// @nodoc
abstract mixin class $AvatarAnimationGestureCopyWith<$Res> implements $AvatarAnimationCopyWith<$Res> {
  factory $AvatarAnimationGestureCopyWith(AvatarAnimationGesture value, $Res Function(AvatarAnimationGesture) _then) = _$AvatarAnimationGestureCopyWithImpl;
@useResult
$Res call({
 AvatarGesture gesture
});




}
/// @nodoc
class _$AvatarAnimationGestureCopyWithImpl<$Res>
    implements $AvatarAnimationGestureCopyWith<$Res> {
  _$AvatarAnimationGestureCopyWithImpl(this._self, this._then);

  final AvatarAnimationGesture _self;
  final $Res Function(AvatarAnimationGesture) _then;

/// Create a copy of AvatarAnimation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? gesture = null,}) {
  return _then(AvatarAnimationGesture(
null == gesture ? _self.gesture : gesture // ignore: cast_nullable_to_non_nullable
as AvatarGesture,
  ));
}


}

/// @nodoc


class AvatarAnimationSceneEvent implements AvatarAnimation {
  const AvatarAnimationSceneEvent(this.sceneEvent);
  

 final  SceneEvent sceneEvent;

/// Create a copy of AvatarAnimation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvatarAnimationSceneEventCopyWith<AvatarAnimationSceneEvent> get copyWith => _$AvatarAnimationSceneEventCopyWithImpl<AvatarAnimationSceneEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvatarAnimationSceneEvent&&(identical(other.sceneEvent, sceneEvent) || other.sceneEvent == sceneEvent));
}


@override
int get hashCode => Object.hash(runtimeType,sceneEvent);

@override
String toString() {
  return 'AvatarAnimation.sceneEvent(sceneEvent: $sceneEvent)';
}


}

/// @nodoc
abstract mixin class $AvatarAnimationSceneEventCopyWith<$Res> implements $AvatarAnimationCopyWith<$Res> {
  factory $AvatarAnimationSceneEventCopyWith(AvatarAnimationSceneEvent value, $Res Function(AvatarAnimationSceneEvent) _then) = _$AvatarAnimationSceneEventCopyWithImpl;
@useResult
$Res call({
 SceneEvent sceneEvent
});




}
/// @nodoc
class _$AvatarAnimationSceneEventCopyWithImpl<$Res>
    implements $AvatarAnimationSceneEventCopyWith<$Res> {
  _$AvatarAnimationSceneEventCopyWithImpl(this._self, this._then);

  final AvatarAnimationSceneEvent _self;
  final $Res Function(AvatarAnimationSceneEvent) _then;

/// Create a copy of AvatarAnimation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sceneEvent = null,}) {
  return _then(AvatarAnimationSceneEvent(
null == sceneEvent ? _self.sceneEvent : sceneEvent // ignore: cast_nullable_to_non_nullable
as SceneEvent,
  ));
}


}

/// @nodoc


class AvatarAnimationMood implements AvatarAnimation {
  const AvatarAnimationMood(this.mood);
  

 final  AvatarMood mood;

/// Create a copy of AvatarAnimation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvatarAnimationMoodCopyWith<AvatarAnimationMood> get copyWith => _$AvatarAnimationMoodCopyWithImpl<AvatarAnimationMood>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvatarAnimationMood&&(identical(other.mood, mood) || other.mood == mood));
}


@override
int get hashCode => Object.hash(runtimeType,mood);

@override
String toString() {
  return 'AvatarAnimation.mood(mood: $mood)';
}


}

/// @nodoc
abstract mixin class $AvatarAnimationMoodCopyWith<$Res> implements $AvatarAnimationCopyWith<$Res> {
  factory $AvatarAnimationMoodCopyWith(AvatarAnimationMood value, $Res Function(AvatarAnimationMood) _then) = _$AvatarAnimationMoodCopyWithImpl;
@useResult
$Res call({
 AvatarMood mood
});




}
/// @nodoc
class _$AvatarAnimationMoodCopyWithImpl<$Res>
    implements $AvatarAnimationMoodCopyWith<$Res> {
  _$AvatarAnimationMoodCopyWithImpl(this._self, this._then);

  final AvatarAnimationMood _self;
  final $Res Function(AvatarAnimationMood) _then;

/// Create a copy of AvatarAnimation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mood = null,}) {
  return _then(AvatarAnimationMood(
null == mood ? _self.mood : mood // ignore: cast_nullable_to_non_nullable
as AvatarMood,
  ));
}


}

/// @nodoc


class AvatarAnimationPresence implements AvatarAnimation {
  const AvatarAnimationPresence(this.presence);
  

 final  AvatarSpecials presence;

/// Create a copy of AvatarAnimation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvatarAnimationPresenceCopyWith<AvatarAnimationPresence> get copyWith => _$AvatarAnimationPresenceCopyWithImpl<AvatarAnimationPresence>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvatarAnimationPresence&&(identical(other.presence, presence) || other.presence == presence));
}


@override
int get hashCode => Object.hash(runtimeType,presence);

@override
String toString() {
  return 'AvatarAnimation.presence(presence: $presence)';
}


}

/// @nodoc
abstract mixin class $AvatarAnimationPresenceCopyWith<$Res> implements $AvatarAnimationCopyWith<$Res> {
  factory $AvatarAnimationPresenceCopyWith(AvatarAnimationPresence value, $Res Function(AvatarAnimationPresence) _then) = _$AvatarAnimationPresenceCopyWithImpl;
@useResult
$Res call({
 AvatarSpecials presence
});




}
/// @nodoc
class _$AvatarAnimationPresenceCopyWithImpl<$Res>
    implements $AvatarAnimationPresenceCopyWith<$Res> {
  _$AvatarAnimationPresenceCopyWithImpl(this._self, this._then);

  final AvatarAnimationPresence _self;
  final $Res Function(AvatarAnimationPresence) _then;

/// Create a copy of AvatarAnimation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? presence = null,}) {
  return _then(AvatarAnimationPresence(
null == presence ? _self.presence : presence // ignore: cast_nullable_to_non_nullable
as AvatarSpecials,
  ));
}


}

// dart format on
