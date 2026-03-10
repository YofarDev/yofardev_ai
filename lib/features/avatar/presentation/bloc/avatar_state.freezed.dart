// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'avatar_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AvatarState {

 AvatarStatus get status; AvatarStatusAnimation get statusAnimation; double get baseOriginalWidth; double get baseOriginalHeight; double get scaleFactor; Avatar get avatar; AvatarConfig get avatarConfig; AvatarSpecials get previousSpecialsState; BackgroundTransition get backgroundTransition;
/// Create a copy of AvatarState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvatarStateCopyWith<AvatarState> get copyWith => _$AvatarStateCopyWithImpl<AvatarState>(this as AvatarState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvatarState&&(identical(other.status, status) || other.status == status)&&(identical(other.statusAnimation, statusAnimation) || other.statusAnimation == statusAnimation)&&(identical(other.baseOriginalWidth, baseOriginalWidth) || other.baseOriginalWidth == baseOriginalWidth)&&(identical(other.baseOriginalHeight, baseOriginalHeight) || other.baseOriginalHeight == baseOriginalHeight)&&(identical(other.scaleFactor, scaleFactor) || other.scaleFactor == scaleFactor)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.avatarConfig, avatarConfig) || other.avatarConfig == avatarConfig)&&(identical(other.previousSpecialsState, previousSpecialsState) || other.previousSpecialsState == previousSpecialsState)&&(identical(other.backgroundTransition, backgroundTransition) || other.backgroundTransition == backgroundTransition));
}


@override
int get hashCode => Object.hash(runtimeType,status,statusAnimation,baseOriginalWidth,baseOriginalHeight,scaleFactor,avatar,avatarConfig,previousSpecialsState,backgroundTransition);

@override
String toString() {
  return 'AvatarState(status: $status, statusAnimation: $statusAnimation, baseOriginalWidth: $baseOriginalWidth, baseOriginalHeight: $baseOriginalHeight, scaleFactor: $scaleFactor, avatar: $avatar, avatarConfig: $avatarConfig, previousSpecialsState: $previousSpecialsState, backgroundTransition: $backgroundTransition)';
}


}

/// @nodoc
abstract mixin class $AvatarStateCopyWith<$Res>  {
  factory $AvatarStateCopyWith(AvatarState value, $Res Function(AvatarState) _then) = _$AvatarStateCopyWithImpl;
@useResult
$Res call({
 AvatarStatus status, AvatarStatusAnimation statusAnimation, double baseOriginalWidth, double baseOriginalHeight, double scaleFactor, Avatar avatar, AvatarConfig avatarConfig, AvatarSpecials previousSpecialsState, BackgroundTransition backgroundTransition
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
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? statusAnimation = null,Object? baseOriginalWidth = null,Object? baseOriginalHeight = null,Object? scaleFactor = null,Object? avatar = null,Object? avatarConfig = null,Object? previousSpecialsState = null,Object? backgroundTransition = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AvatarStatus,statusAnimation: null == statusAnimation ? _self.statusAnimation : statusAnimation // ignore: cast_nullable_to_non_nullable
as AvatarStatusAnimation,baseOriginalWidth: null == baseOriginalWidth ? _self.baseOriginalWidth : baseOriginalWidth // ignore: cast_nullable_to_non_nullable
as double,baseOriginalHeight: null == baseOriginalHeight ? _self.baseOriginalHeight : baseOriginalHeight // ignore: cast_nullable_to_non_nullable
as double,scaleFactor: null == scaleFactor ? _self.scaleFactor : scaleFactor // ignore: cast_nullable_to_non_nullable
as double,avatar: null == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as Avatar,avatarConfig: null == avatarConfig ? _self.avatarConfig : avatarConfig // ignore: cast_nullable_to_non_nullable
as AvatarConfig,previousSpecialsState: null == previousSpecialsState ? _self.previousSpecialsState : previousSpecialsState // ignore: cast_nullable_to_non_nullable
as AvatarSpecials,backgroundTransition: null == backgroundTransition ? _self.backgroundTransition : backgroundTransition // ignore: cast_nullable_to_non_nullable
as BackgroundTransition,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AvatarStatus status,  AvatarStatusAnimation statusAnimation,  double baseOriginalWidth,  double baseOriginalHeight,  double scaleFactor,  Avatar avatar,  AvatarConfig avatarConfig,  AvatarSpecials previousSpecialsState,  BackgroundTransition backgroundTransition)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AvatarState() when $default != null:
return $default(_that.status,_that.statusAnimation,_that.baseOriginalWidth,_that.baseOriginalHeight,_that.scaleFactor,_that.avatar,_that.avatarConfig,_that.previousSpecialsState,_that.backgroundTransition);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AvatarStatus status,  AvatarStatusAnimation statusAnimation,  double baseOriginalWidth,  double baseOriginalHeight,  double scaleFactor,  Avatar avatar,  AvatarConfig avatarConfig,  AvatarSpecials previousSpecialsState,  BackgroundTransition backgroundTransition)  $default,) {final _that = this;
switch (_that) {
case _AvatarState():
return $default(_that.status,_that.statusAnimation,_that.baseOriginalWidth,_that.baseOriginalHeight,_that.scaleFactor,_that.avatar,_that.avatarConfig,_that.previousSpecialsState,_that.backgroundTransition);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AvatarStatus status,  AvatarStatusAnimation statusAnimation,  double baseOriginalWidth,  double baseOriginalHeight,  double scaleFactor,  Avatar avatar,  AvatarConfig avatarConfig,  AvatarSpecials previousSpecialsState,  BackgroundTransition backgroundTransition)?  $default,) {final _that = this;
switch (_that) {
case _AvatarState() when $default != null:
return $default(_that.status,_that.statusAnimation,_that.baseOriginalWidth,_that.baseOriginalHeight,_that.scaleFactor,_that.avatar,_that.avatarConfig,_that.previousSpecialsState,_that.backgroundTransition);case _:
  return null;

}
}

}

/// @nodoc


class _AvatarState extends AvatarState {
  const _AvatarState({this.status = AvatarStatus.initial, this.statusAnimation = AvatarStatusAnimation.initial, this.baseOriginalWidth = 0.0, this.baseOriginalHeight = 0.0, this.scaleFactor = 1.0, required this.avatar, required this.avatarConfig, this.previousSpecialsState = AvatarSpecials.onScreen, this.backgroundTransition = BackgroundTransition.none}): super._();
  

@override@JsonKey() final  AvatarStatus status;
@override@JsonKey() final  AvatarStatusAnimation statusAnimation;
@override@JsonKey() final  double baseOriginalWidth;
@override@JsonKey() final  double baseOriginalHeight;
@override@JsonKey() final  double scaleFactor;
@override final  Avatar avatar;
@override final  AvatarConfig avatarConfig;
@override@JsonKey() final  AvatarSpecials previousSpecialsState;
@override@JsonKey() final  BackgroundTransition backgroundTransition;

/// Create a copy of AvatarState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AvatarStateCopyWith<_AvatarState> get copyWith => __$AvatarStateCopyWithImpl<_AvatarState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AvatarState&&(identical(other.status, status) || other.status == status)&&(identical(other.statusAnimation, statusAnimation) || other.statusAnimation == statusAnimation)&&(identical(other.baseOriginalWidth, baseOriginalWidth) || other.baseOriginalWidth == baseOriginalWidth)&&(identical(other.baseOriginalHeight, baseOriginalHeight) || other.baseOriginalHeight == baseOriginalHeight)&&(identical(other.scaleFactor, scaleFactor) || other.scaleFactor == scaleFactor)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.avatarConfig, avatarConfig) || other.avatarConfig == avatarConfig)&&(identical(other.previousSpecialsState, previousSpecialsState) || other.previousSpecialsState == previousSpecialsState)&&(identical(other.backgroundTransition, backgroundTransition) || other.backgroundTransition == backgroundTransition));
}


@override
int get hashCode => Object.hash(runtimeType,status,statusAnimation,baseOriginalWidth,baseOriginalHeight,scaleFactor,avatar,avatarConfig,previousSpecialsState,backgroundTransition);

@override
String toString() {
  return 'AvatarState(status: $status, statusAnimation: $statusAnimation, baseOriginalWidth: $baseOriginalWidth, baseOriginalHeight: $baseOriginalHeight, scaleFactor: $scaleFactor, avatar: $avatar, avatarConfig: $avatarConfig, previousSpecialsState: $previousSpecialsState, backgroundTransition: $backgroundTransition)';
}


}

/// @nodoc
abstract mixin class _$AvatarStateCopyWith<$Res> implements $AvatarStateCopyWith<$Res> {
  factory _$AvatarStateCopyWith(_AvatarState value, $Res Function(_AvatarState) _then) = __$AvatarStateCopyWithImpl;
@override @useResult
$Res call({
 AvatarStatus status, AvatarStatusAnimation statusAnimation, double baseOriginalWidth, double baseOriginalHeight, double scaleFactor, Avatar avatar, AvatarConfig avatarConfig, AvatarSpecials previousSpecialsState, BackgroundTransition backgroundTransition
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
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? statusAnimation = null,Object? baseOriginalWidth = null,Object? baseOriginalHeight = null,Object? scaleFactor = null,Object? avatar = null,Object? avatarConfig = null,Object? previousSpecialsState = null,Object? backgroundTransition = null,}) {
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
as BackgroundTransition,
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
