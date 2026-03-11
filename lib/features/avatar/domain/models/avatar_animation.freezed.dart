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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AvatarAnimationClothes value)?  clothes,TResult Function( AvatarAnimationBackground value)?  background,TResult Function( AvatarAnimationUpdateConfig value)?  updateConfig,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AvatarAnimationClothes() when clothes != null:
return clothes(_that);case AvatarAnimationBackground() when background != null:
return background(_that);case AvatarAnimationUpdateConfig() when updateConfig != null:
return updateConfig(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AvatarAnimationClothes value)  clothes,required TResult Function( AvatarAnimationBackground value)  background,required TResult Function( AvatarAnimationUpdateConfig value)  updateConfig,}){
final _that = this;
switch (_that) {
case AvatarAnimationClothes():
return clothes(_that);case AvatarAnimationBackground():
return background(_that);case AvatarAnimationUpdateConfig():
return updateConfig(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AvatarAnimationClothes value)?  clothes,TResult? Function( AvatarAnimationBackground value)?  background,TResult? Function( AvatarAnimationUpdateConfig value)?  updateConfig,}){
final _that = this;
switch (_that) {
case AvatarAnimationClothes() when clothes != null:
return clothes(_that);case AvatarAnimationBackground() when background != null:
return background(_that);case AvatarAnimationUpdateConfig() when updateConfig != null:
return updateConfig(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( bool goingDown)?  clothes,TResult Function( BackgroundTransition transition)?  background,TResult Function( String chatId,  AvatarConfig avatarConfig)?  updateConfig,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AvatarAnimationClothes() when clothes != null:
return clothes(_that.goingDown);case AvatarAnimationBackground() when background != null:
return background(_that.transition);case AvatarAnimationUpdateConfig() when updateConfig != null:
return updateConfig(_that.chatId,_that.avatarConfig);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( bool goingDown)  clothes,required TResult Function( BackgroundTransition transition)  background,required TResult Function( String chatId,  AvatarConfig avatarConfig)  updateConfig,}) {final _that = this;
switch (_that) {
case AvatarAnimationClothes():
return clothes(_that.goingDown);case AvatarAnimationBackground():
return background(_that.transition);case AvatarAnimationUpdateConfig():
return updateConfig(_that.chatId,_that.avatarConfig);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( bool goingDown)?  clothes,TResult? Function( BackgroundTransition transition)?  background,TResult? Function( String chatId,  AvatarConfig avatarConfig)?  updateConfig,}) {final _that = this;
switch (_that) {
case AvatarAnimationClothes() when clothes != null:
return clothes(_that.goingDown);case AvatarAnimationBackground() when background != null:
return background(_that.transition);case AvatarAnimationUpdateConfig() when updateConfig != null:
return updateConfig(_that.chatId,_that.avatarConfig);case _:
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

// dart format on
