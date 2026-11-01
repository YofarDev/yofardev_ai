// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'avatar_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Avatar {

 AvatarScene get background; AvatarHat get hat; AvatarTop get top; AvatarGlasses get glasses; AvatarSpecials get specials; AvatarCostume get costume;@JsonKey(unknownEnumValue: AvatarTint.none) AvatarTint get topTint;@JsonKey(unknownEnumValue: AvatarTint.none) AvatarTint get hatTint;
/// Create a copy of Avatar
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvatarCopyWith<Avatar> get copyWith => _$AvatarCopyWithImpl<Avatar>(this as Avatar, _$identity);

  /// Serializes this Avatar to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Avatar;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Avatar&&(identical(other.background, _this.background) || other.background == _this.background)&&(identical(other.hat, _this.hat) || other.hat == _this.hat)&&(identical(other.top, _this.top) || other.top == _this.top)&&(identical(other.glasses, _this.glasses) || other.glasses == _this.glasses)&&(identical(other.specials, _this.specials) || other.specials == _this.specials)&&(identical(other.costume, _this.costume) || other.costume == _this.costume)&&(identical(other.topTint, _this.topTint) || other.topTint == _this.topTint)&&(identical(other.hatTint, _this.hatTint) || other.hatTint == _this.hatTint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Avatar;
  return Object.hash(runtimeType,_this.background,_this.hat,_this.top,_this.glasses,_this.specials,_this.costume,_this.topTint,_this.hatTint);
}



}

/// @nodoc
abstract mixin class $AvatarCopyWith<$Res>  {
  factory $AvatarCopyWith(Avatar value, $Res Function(Avatar) _then) = _$AvatarCopyWithImpl;
@useResult
$Res call({
 AvatarScene background, AvatarHat hat, AvatarTop top, AvatarGlasses glasses, AvatarSpecials specials, AvatarCostume costume,@JsonKey(unknownEnumValue: AvatarTint.none) AvatarTint topTint,@JsonKey(unknownEnumValue: AvatarTint.none) AvatarTint hatTint
});




}
/// @nodoc
class _$AvatarCopyWithImpl<$Res>
    implements $AvatarCopyWith<$Res> {
  _$AvatarCopyWithImpl(this._self, this._then);

  final Avatar _self;
  final $Res Function(Avatar) _then;

/// Create a copy of Avatar
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? background = null,Object? hat = null,Object? top = null,Object? glasses = null,Object? specials = null,Object? costume = null,Object? topTint = null,Object? hatTint = null,}) {
  return _then(Avatar(
background: null == background ? _self.background : background // ignore: cast_nullable_to_non_nullable
as AvatarScene,hat: null == hat ? _self.hat : hat // ignore: cast_nullable_to_non_nullable
as AvatarHat,top: null == top ? _self.top : top // ignore: cast_nullable_to_non_nullable
as AvatarTop,glasses: null == glasses ? _self.glasses : glasses // ignore: cast_nullable_to_non_nullable
as AvatarGlasses,specials: null == specials ? _self.specials : specials // ignore: cast_nullable_to_non_nullable
as AvatarSpecials,costume: null == costume ? _self.costume : costume // ignore: cast_nullable_to_non_nullable
as AvatarCostume,topTint: null == topTint ? _self.topTint : topTint // ignore: cast_nullable_to_non_nullable
as AvatarTint,hatTint: null == hatTint ? _self.hatTint : hatTint // ignore: cast_nullable_to_non_nullable
as AvatarTint,
  ));
}

}


/// Adds pattern-matching-related methods to [Avatar].
extension AvatarPatterns on Avatar {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Avatar value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Avatar() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Avatar value)  $default,){
final _that = this;
switch (_that) {
case _Avatar():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Avatar value)?  $default,){
final _that = this;
switch (_that) {
case _Avatar() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AvatarScene background,  AvatarHat hat,  AvatarTop top,  AvatarGlasses glasses,  AvatarSpecials specials,  AvatarCostume costume, @JsonKey(unknownEnumValue: AvatarTint.none)  AvatarTint topTint, @JsonKey(unknownEnumValue: AvatarTint.none)  AvatarTint hatTint)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Avatar() when $default != null:
return $default(_that.background,_that.hat,_that.top,_that.glasses,_that.specials,_that.costume,_that.topTint,_that.hatTint);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AvatarScene background,  AvatarHat hat,  AvatarTop top,  AvatarGlasses glasses,  AvatarSpecials specials,  AvatarCostume costume, @JsonKey(unknownEnumValue: AvatarTint.none)  AvatarTint topTint, @JsonKey(unknownEnumValue: AvatarTint.none)  AvatarTint hatTint)  $default,) {final _that = this;
switch (_that) {
case _Avatar():
return $default(_that.background,_that.hat,_that.top,_that.glasses,_that.specials,_that.costume,_that.topTint,_that.hatTint);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AvatarScene background,  AvatarHat hat,  AvatarTop top,  AvatarGlasses glasses,  AvatarSpecials specials,  AvatarCostume costume, @JsonKey(unknownEnumValue: AvatarTint.none)  AvatarTint topTint, @JsonKey(unknownEnumValue: AvatarTint.none)  AvatarTint hatTint)?  $default,) {final _that = this;
switch (_that) {
case _Avatar() when $default != null:
return $default(_that.background,_that.hat,_that.top,_that.glasses,_that.specials,_that.costume,_that.topTint,_that.hatTint);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Avatar extends Avatar {
  const _Avatar({this.background = AvatarScene.defaultScene, this.hat = AvatarHat.noHat, this.top = AvatarTop.pinkHoodie, this.glasses = AvatarGlasses.glasses, this.specials = AvatarSpecials.onScreen, this.costume = AvatarCostume.none, @JsonKey(unknownEnumValue: AvatarTint.none) this.topTint = AvatarTint.none, @JsonKey(unknownEnumValue: AvatarTint.none) this.hatTint = AvatarTint.none}): super._();
  factory _Avatar.fromJson(Map<String, dynamic> json) => _$AvatarFromJson(json);

@override@JsonKey() final  AvatarScene background;
@override@JsonKey() final  AvatarHat hat;
@override@JsonKey() final  AvatarTop top;
@override@JsonKey() final  AvatarGlasses glasses;
@override@JsonKey() final  AvatarSpecials specials;
@override@JsonKey() final  AvatarCostume costume;
@override@JsonKey(unknownEnumValue: AvatarTint.none) final  AvatarTint topTint;
@override@JsonKey(unknownEnumValue: AvatarTint.none) final  AvatarTint hatTint;

/// Create a copy of Avatar
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AvatarCopyWith<_Avatar> get copyWith => __$AvatarCopyWithImpl<_Avatar>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AvatarToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Avatar&&(identical(other.background, background) || other.background == background)&&(identical(other.hat, hat) || other.hat == hat)&&(identical(other.top, top) || other.top == top)&&(identical(other.glasses, glasses) || other.glasses == glasses)&&(identical(other.specials, specials) || other.specials == specials)&&(identical(other.costume, costume) || other.costume == costume)&&(identical(other.topTint, topTint) || other.topTint == topTint)&&(identical(other.hatTint, hatTint) || other.hatTint == hatTint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,background,hat,top,glasses,specials,costume,topTint,hatTint);
}



}

/// @nodoc
abstract mixin class _$AvatarCopyWith<$Res> implements $AvatarCopyWith<$Res> {
  factory _$AvatarCopyWith(_Avatar value, $Res Function(_Avatar) _then) = __$AvatarCopyWithImpl;
@override @useResult
$Res call({
 AvatarScene background, AvatarHat hat, AvatarTop top, AvatarGlasses glasses, AvatarSpecials specials, AvatarCostume costume,@JsonKey(unknownEnumValue: AvatarTint.none) AvatarTint topTint,@JsonKey(unknownEnumValue: AvatarTint.none) AvatarTint hatTint
});




}
/// @nodoc
class __$AvatarCopyWithImpl<$Res>
    implements _$AvatarCopyWith<$Res> {
  __$AvatarCopyWithImpl(this._self, this._then);

  final _Avatar _self;
  final $Res Function(_Avatar) _then;

/// Create a copy of Avatar
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? background = null,Object? hat = null,Object? top = null,Object? glasses = null,Object? specials = null,Object? costume = null,Object? topTint = null,Object? hatTint = null,}) {
  return _then(_Avatar(
background: null == background ? _self.background : background // ignore: cast_nullable_to_non_nullable
as AvatarScene,hat: null == hat ? _self.hat : hat // ignore: cast_nullable_to_non_nullable
as AvatarHat,top: null == top ? _self.top : top // ignore: cast_nullable_to_non_nullable
as AvatarTop,glasses: null == glasses ? _self.glasses : glasses // ignore: cast_nullable_to_non_nullable
as AvatarGlasses,specials: null == specials ? _self.specials : specials // ignore: cast_nullable_to_non_nullable
as AvatarSpecials,costume: null == costume ? _self.costume : costume // ignore: cast_nullable_to_non_nullable
as AvatarCostume,topTint: null == topTint ? _self.topTint : topTint // ignore: cast_nullable_to_non_nullable
as AvatarTint,hatTint: null == hatTint ? _self.hatTint : hatTint // ignore: cast_nullable_to_non_nullable
as AvatarTint,
  ));
}


}


/// @nodoc
mixin _$AvatarConfig {

@SceneNameConverter() AvatarScene? get background; AvatarHat? get hat; AvatarTop? get top; AvatarGlasses? get glasses; AvatarSpecials? get specials; AvatarCostume? get costume;@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) AvatarTint? get topTint;@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) AvatarTint? get hatTint;@SoundEffectConverter() SoundEffects? get soundEffect;@MoodConverter() AvatarMood? get mood;
/// Create a copy of AvatarConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvatarConfigCopyWith<AvatarConfig> get copyWith => _$AvatarConfigCopyWithImpl<AvatarConfig>(this as AvatarConfig, _$identity);

  /// Serializes this AvatarConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AvatarConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvatarConfig&&(identical(other.background, _this.background) || other.background == _this.background)&&(identical(other.hat, _this.hat) || other.hat == _this.hat)&&(identical(other.top, _this.top) || other.top == _this.top)&&(identical(other.glasses, _this.glasses) || other.glasses == _this.glasses)&&(identical(other.specials, _this.specials) || other.specials == _this.specials)&&(identical(other.costume, _this.costume) || other.costume == _this.costume)&&(identical(other.topTint, _this.topTint) || other.topTint == _this.topTint)&&(identical(other.hatTint, _this.hatTint) || other.hatTint == _this.hatTint)&&(identical(other.soundEffect, _this.soundEffect) || other.soundEffect == _this.soundEffect)&&(identical(other.mood, _this.mood) || other.mood == _this.mood));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AvatarConfig;
  return Object.hash(runtimeType,_this.background,_this.hat,_this.top,_this.glasses,_this.specials,_this.costume,_this.topTint,_this.hatTint,_this.soundEffect,_this.mood);
}

@override
String toString() {
  final _this = this as AvatarConfig;
  return 'AvatarConfig(background: ${_this.background}, hat: ${_this.hat}, top: ${_this.top}, glasses: ${_this.glasses}, specials: ${_this.specials}, costume: ${_this.costume}, topTint: ${_this.topTint}, hatTint: ${_this.hatTint}, soundEffect: ${_this.soundEffect}, mood: ${_this.mood})';
}


}

/// @nodoc
abstract mixin class $AvatarConfigCopyWith<$Res>  {
  factory $AvatarConfigCopyWith(AvatarConfig value, $Res Function(AvatarConfig) _then) = _$AvatarConfigCopyWithImpl;
@useResult
$Res call({
@SceneNameConverter() AvatarScene? background, AvatarHat? hat, AvatarTop? top, AvatarGlasses? glasses, AvatarSpecials? specials, AvatarCostume? costume,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) AvatarTint? topTint,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) AvatarTint? hatTint,@SoundEffectConverter() SoundEffects? soundEffect,@MoodConverter() AvatarMood? mood
});




}
/// @nodoc
class _$AvatarConfigCopyWithImpl<$Res>
    implements $AvatarConfigCopyWith<$Res> {
  _$AvatarConfigCopyWithImpl(this._self, this._then);

  final AvatarConfig _self;
  final $Res Function(AvatarConfig) _then;

/// Create a copy of AvatarConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? background = freezed,Object? hat = freezed,Object? top = freezed,Object? glasses = freezed,Object? specials = freezed,Object? costume = freezed,Object? topTint = freezed,Object? hatTint = freezed,Object? soundEffect = freezed,Object? mood = freezed,}) {
  return _then(AvatarConfig(
background: freezed == background ? _self.background : background // ignore: cast_nullable_to_non_nullable
as AvatarScene?,hat: freezed == hat ? _self.hat : hat // ignore: cast_nullable_to_non_nullable
as AvatarHat?,top: freezed == top ? _self.top : top // ignore: cast_nullable_to_non_nullable
as AvatarTop?,glasses: freezed == glasses ? _self.glasses : glasses // ignore: cast_nullable_to_non_nullable
as AvatarGlasses?,specials: freezed == specials ? _self.specials : specials // ignore: cast_nullable_to_non_nullable
as AvatarSpecials?,costume: freezed == costume ? _self.costume : costume // ignore: cast_nullable_to_non_nullable
as AvatarCostume?,topTint: freezed == topTint ? _self.topTint : topTint // ignore: cast_nullable_to_non_nullable
as AvatarTint?,hatTint: freezed == hatTint ? _self.hatTint : hatTint // ignore: cast_nullable_to_non_nullable
as AvatarTint?,soundEffect: freezed == soundEffect ? _self.soundEffect : soundEffect // ignore: cast_nullable_to_non_nullable
as SoundEffects?,mood: freezed == mood ? _self.mood : mood // ignore: cast_nullable_to_non_nullable
as AvatarMood?,
  ));
}

}


/// Adds pattern-matching-related methods to [AvatarConfig].
extension AvatarConfigPatterns on AvatarConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AvatarConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AvatarConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AvatarConfig value)  $default,){
final _that = this;
switch (_that) {
case _AvatarConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AvatarConfig value)?  $default,){
final _that = this;
switch (_that) {
case _AvatarConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@SceneNameConverter()  AvatarScene? background,  AvatarHat? hat,  AvatarTop? top,  AvatarGlasses? glasses,  AvatarSpecials? specials,  AvatarCostume? costume, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  AvatarTint? topTint, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  AvatarTint? hatTint, @SoundEffectConverter()  SoundEffects? soundEffect, @MoodConverter()  AvatarMood? mood)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AvatarConfig() when $default != null:
return $default(_that.background,_that.hat,_that.top,_that.glasses,_that.specials,_that.costume,_that.topTint,_that.hatTint,_that.soundEffect,_that.mood);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@SceneNameConverter()  AvatarScene? background,  AvatarHat? hat,  AvatarTop? top,  AvatarGlasses? glasses,  AvatarSpecials? specials,  AvatarCostume? costume, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  AvatarTint? topTint, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  AvatarTint? hatTint, @SoundEffectConverter()  SoundEffects? soundEffect, @MoodConverter()  AvatarMood? mood)  $default,) {final _that = this;
switch (_that) {
case _AvatarConfig():
return $default(_that.background,_that.hat,_that.top,_that.glasses,_that.specials,_that.costume,_that.topTint,_that.hatTint,_that.soundEffect,_that.mood);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@SceneNameConverter()  AvatarScene? background,  AvatarHat? hat,  AvatarTop? top,  AvatarGlasses? glasses,  AvatarSpecials? specials,  AvatarCostume? costume, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  AvatarTint? topTint, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  AvatarTint? hatTint, @SoundEffectConverter()  SoundEffects? soundEffect, @MoodConverter()  AvatarMood? mood)?  $default,) {final _that = this;
switch (_that) {
case _AvatarConfig() when $default != null:
return $default(_that.background,_that.hat,_that.top,_that.glasses,_that.specials,_that.costume,_that.topTint,_that.hatTint,_that.soundEffect,_that.mood);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AvatarConfig extends AvatarConfig {
  const _AvatarConfig({@SceneNameConverter() this.background, this.hat, this.top, this.glasses, this.specials, this.costume, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) this.topTint, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) this.hatTint, @SoundEffectConverter() this.soundEffect, @MoodConverter() this.mood}): super._();
  factory _AvatarConfig.fromJson(Map<String, dynamic> json) => _$AvatarConfigFromJson(json);

@override@SceneNameConverter() final  AvatarScene? background;
@override final  AvatarHat? hat;
@override final  AvatarTop? top;
@override final  AvatarGlasses? glasses;
@override final  AvatarSpecials? specials;
@override final  AvatarCostume? costume;
@override@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) final  AvatarTint? topTint;
@override@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) final  AvatarTint? hatTint;
@override@SoundEffectConverter() final  SoundEffects? soundEffect;
@override@MoodConverter() final  AvatarMood? mood;

/// Create a copy of AvatarConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AvatarConfigCopyWith<_AvatarConfig> get copyWith => __$AvatarConfigCopyWithImpl<_AvatarConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AvatarConfigToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AvatarConfig&&(identical(other.background, background) || other.background == background)&&(identical(other.hat, hat) || other.hat == hat)&&(identical(other.top, top) || other.top == top)&&(identical(other.glasses, glasses) || other.glasses == glasses)&&(identical(other.specials, specials) || other.specials == specials)&&(identical(other.costume, costume) || other.costume == costume)&&(identical(other.topTint, topTint) || other.topTint == topTint)&&(identical(other.hatTint, hatTint) || other.hatTint == hatTint)&&(identical(other.soundEffect, soundEffect) || other.soundEffect == soundEffect)&&(identical(other.mood, mood) || other.mood == mood));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,background,hat,top,glasses,specials,costume,topTint,hatTint,soundEffect,mood);
}

@override
String toString() {
    return 'AvatarConfig(background: $background, hat: $hat, top: $top, glasses: $glasses, specials: $specials, costume: $costume, topTint: $topTint, hatTint: $hatTint, soundEffect: $soundEffect, mood: $mood)';
}


}

/// @nodoc
abstract mixin class _$AvatarConfigCopyWith<$Res> implements $AvatarConfigCopyWith<$Res> {
  factory _$AvatarConfigCopyWith(_AvatarConfig value, $Res Function(_AvatarConfig) _then) = __$AvatarConfigCopyWithImpl;
@override @useResult
$Res call({
@SceneNameConverter() AvatarScene? background, AvatarHat? hat, AvatarTop? top, AvatarGlasses? glasses, AvatarSpecials? specials, AvatarCostume? costume,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) AvatarTint? topTint,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) AvatarTint? hatTint,@SoundEffectConverter() SoundEffects? soundEffect,@MoodConverter() AvatarMood? mood
});




}
/// @nodoc
class __$AvatarConfigCopyWithImpl<$Res>
    implements _$AvatarConfigCopyWith<$Res> {
  __$AvatarConfigCopyWithImpl(this._self, this._then);

  final _AvatarConfig _self;
  final $Res Function(_AvatarConfig) _then;

/// Create a copy of AvatarConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? background = freezed,Object? hat = freezed,Object? top = freezed,Object? glasses = freezed,Object? specials = freezed,Object? costume = freezed,Object? topTint = freezed,Object? hatTint = freezed,Object? soundEffect = freezed,Object? mood = freezed,}) {
  return _then(_AvatarConfig(
background: freezed == background ? _self.background : background // ignore: cast_nullable_to_non_nullable
as AvatarScene?,hat: freezed == hat ? _self.hat : hat // ignore: cast_nullable_to_non_nullable
as AvatarHat?,top: freezed == top ? _self.top : top // ignore: cast_nullable_to_non_nullable
as AvatarTop?,glasses: freezed == glasses ? _self.glasses : glasses // ignore: cast_nullable_to_non_nullable
as AvatarGlasses?,specials: freezed == specials ? _self.specials : specials // ignore: cast_nullable_to_non_nullable
as AvatarSpecials?,costume: freezed == costume ? _self.costume : costume // ignore: cast_nullable_to_non_nullable
as AvatarCostume?,topTint: freezed == topTint ? _self.topTint : topTint // ignore: cast_nullable_to_non_nullable
as AvatarTint?,hatTint: freezed == hatTint ? _self.hatTint : hatTint // ignore: cast_nullable_to_non_nullable
as AvatarTint?,soundEffect: freezed == soundEffect ? _self.soundEffect : soundEffect // ignore: cast_nullable_to_non_nullable
as SoundEffects?,mood: freezed == mood ? _self.mood : mood // ignore: cast_nullable_to_non_nullable
as AvatarMood?,
  ));
}


}

// dart format on
