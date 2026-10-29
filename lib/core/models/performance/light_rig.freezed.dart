// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'light_rig.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LightRig {

 int get keyColor; double get keyIntensity;/// Direction toward the key light, viewer space, −1..1 (`cos` of the angle).
 double get keyX;/// Direction toward the key light, viewer space, −1..1 (`sin` of the angle).
 double get keyY; int get rimColor; double get rimIntensity; int get ambientColor; double get ambientAmount; int get fogColor;/// 0 steady .. 1 full flame flicker (looped inside the Rive files).
 double get flicker;
/// Create a copy of LightRig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LightRigCopyWith<LightRig> get copyWith => _$LightRigCopyWithImpl<LightRig>(this as LightRig, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LightRig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LightRig&&(identical(other.keyColor, _this.keyColor) || other.keyColor == _this.keyColor)&&(identical(other.keyIntensity, _this.keyIntensity) || other.keyIntensity == _this.keyIntensity)&&(identical(other.keyX, _this.keyX) || other.keyX == _this.keyX)&&(identical(other.keyY, _this.keyY) || other.keyY == _this.keyY)&&(identical(other.rimColor, _this.rimColor) || other.rimColor == _this.rimColor)&&(identical(other.rimIntensity, _this.rimIntensity) || other.rimIntensity == _this.rimIntensity)&&(identical(other.ambientColor, _this.ambientColor) || other.ambientColor == _this.ambientColor)&&(identical(other.ambientAmount, _this.ambientAmount) || other.ambientAmount == _this.ambientAmount)&&(identical(other.fogColor, _this.fogColor) || other.fogColor == _this.fogColor)&&(identical(other.flicker, _this.flicker) || other.flicker == _this.flicker));
}


@override
int get hashCode {
  final _this = this as LightRig;
  return Object.hash(runtimeType,_this.keyColor,_this.keyIntensity,_this.keyX,_this.keyY,_this.rimColor,_this.rimIntensity,_this.ambientColor,_this.ambientAmount,_this.fogColor,_this.flicker);
}

@override
String toString() {
  final _this = this as LightRig;
  return 'LightRig(keyColor: ${_this.keyColor}, keyIntensity: ${_this.keyIntensity}, keyX: ${_this.keyX}, keyY: ${_this.keyY}, rimColor: ${_this.rimColor}, rimIntensity: ${_this.rimIntensity}, ambientColor: ${_this.ambientColor}, ambientAmount: ${_this.ambientAmount}, fogColor: ${_this.fogColor}, flicker: ${_this.flicker})';
}


}

/// @nodoc
abstract mixin class $LightRigCopyWith<$Res>  {
  factory $LightRigCopyWith(LightRig value, $Res Function(LightRig) _then) = _$LightRigCopyWithImpl;
@useResult
$Res call({
 int keyColor, double keyIntensity, double keyX, double keyY, int rimColor, double rimIntensity, int ambientColor, double ambientAmount, int fogColor, double flicker
});




}
/// @nodoc
class _$LightRigCopyWithImpl<$Res>
    implements $LightRigCopyWith<$Res> {
  _$LightRigCopyWithImpl(this._self, this._then);

  final LightRig _self;
  final $Res Function(LightRig) _then;

/// Create a copy of LightRig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? keyColor = null,Object? keyIntensity = null,Object? keyX = null,Object? keyY = null,Object? rimColor = null,Object? rimIntensity = null,Object? ambientColor = null,Object? ambientAmount = null,Object? fogColor = null,Object? flicker = null,}) {
  return _then(LightRig(
keyColor: null == keyColor ? _self.keyColor : keyColor // ignore: cast_nullable_to_non_nullable
as int,keyIntensity: null == keyIntensity ? _self.keyIntensity : keyIntensity // ignore: cast_nullable_to_non_nullable
as double,keyX: null == keyX ? _self.keyX : keyX // ignore: cast_nullable_to_non_nullable
as double,keyY: null == keyY ? _self.keyY : keyY // ignore: cast_nullable_to_non_nullable
as double,rimColor: null == rimColor ? _self.rimColor : rimColor // ignore: cast_nullable_to_non_nullable
as int,rimIntensity: null == rimIntensity ? _self.rimIntensity : rimIntensity // ignore: cast_nullable_to_non_nullable
as double,ambientColor: null == ambientColor ? _self.ambientColor : ambientColor // ignore: cast_nullable_to_non_nullable
as int,ambientAmount: null == ambientAmount ? _self.ambientAmount : ambientAmount // ignore: cast_nullable_to_non_nullable
as double,fogColor: null == fogColor ? _self.fogColor : fogColor // ignore: cast_nullable_to_non_nullable
as int,flicker: null == flicker ? _self.flicker : flicker // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [LightRig].
extension LightRigPatterns on LightRig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LightRig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LightRig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LightRig value)  $default,){
final _that = this;
switch (_that) {
case _LightRig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LightRig value)?  $default,){
final _that = this;
switch (_that) {
case _LightRig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int keyColor,  double keyIntensity,  double keyX,  double keyY,  int rimColor,  double rimIntensity,  int ambientColor,  double ambientAmount,  int fogColor,  double flicker)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LightRig() when $default != null:
return $default(_that.keyColor,_that.keyIntensity,_that.keyX,_that.keyY,_that.rimColor,_that.rimIntensity,_that.ambientColor,_that.ambientAmount,_that.fogColor,_that.flicker);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int keyColor,  double keyIntensity,  double keyX,  double keyY,  int rimColor,  double rimIntensity,  int ambientColor,  double ambientAmount,  int fogColor,  double flicker)  $default,) {final _that = this;
switch (_that) {
case _LightRig():
return $default(_that.keyColor,_that.keyIntensity,_that.keyX,_that.keyY,_that.rimColor,_that.rimIntensity,_that.ambientColor,_that.ambientAmount,_that.fogColor,_that.flicker);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int keyColor,  double keyIntensity,  double keyX,  double keyY,  int rimColor,  double rimIntensity,  int ambientColor,  double ambientAmount,  int fogColor,  double flicker)?  $default,) {final _that = this;
switch (_that) {
case _LightRig() when $default != null:
return $default(_that.keyColor,_that.keyIntensity,_that.keyX,_that.keyY,_that.rimColor,_that.rimIntensity,_that.ambientColor,_that.ambientAmount,_that.fogColor,_that.flicker);case _:
  return null;

}
}

}

/// @nodoc


class _LightRig implements LightRig {
  const _LightRig({this.keyColor = 0xFFFFFFFF, this.keyIntensity = 1.0, this.keyX = 0.0, this.keyY = 0.0, this.rimColor = 0xFFFFFFFF, this.rimIntensity = 0.35, this.ambientColor = 0xFF202028, this.ambientAmount = 0.35, this.fogColor = 0x00000000, this.flicker = 0.0});
  

@override@JsonKey() final  int keyColor;
@override@JsonKey() final  double keyIntensity;
/// Direction toward the key light, viewer space, −1..1 (`cos` of the angle).
@override@JsonKey() final  double keyX;
/// Direction toward the key light, viewer space, −1..1 (`sin` of the angle).
@override@JsonKey() final  double keyY;
@override@JsonKey() final  int rimColor;
@override@JsonKey() final  double rimIntensity;
@override@JsonKey() final  int ambientColor;
@override@JsonKey() final  double ambientAmount;
@override@JsonKey() final  int fogColor;
/// 0 steady .. 1 full flame flicker (looped inside the Rive files).
@override@JsonKey() final  double flicker;

/// Create a copy of LightRig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LightRigCopyWith<_LightRig> get copyWith => __$LightRigCopyWithImpl<_LightRig>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LightRig&&(identical(other.keyColor, keyColor) || other.keyColor == keyColor)&&(identical(other.keyIntensity, keyIntensity) || other.keyIntensity == keyIntensity)&&(identical(other.keyX, keyX) || other.keyX == keyX)&&(identical(other.keyY, keyY) || other.keyY == keyY)&&(identical(other.rimColor, rimColor) || other.rimColor == rimColor)&&(identical(other.rimIntensity, rimIntensity) || other.rimIntensity == rimIntensity)&&(identical(other.ambientColor, ambientColor) || other.ambientColor == ambientColor)&&(identical(other.ambientAmount, ambientAmount) || other.ambientAmount == ambientAmount)&&(identical(other.fogColor, fogColor) || other.fogColor == fogColor)&&(identical(other.flicker, flicker) || other.flicker == flicker));
}


@override
int get hashCode {
    return Object.hash(runtimeType,keyColor,keyIntensity,keyX,keyY,rimColor,rimIntensity,ambientColor,ambientAmount,fogColor,flicker);
}

@override
String toString() {
    return 'LightRig(keyColor: $keyColor, keyIntensity: $keyIntensity, keyX: $keyX, keyY: $keyY, rimColor: $rimColor, rimIntensity: $rimIntensity, ambientColor: $ambientColor, ambientAmount: $ambientAmount, fogColor: $fogColor, flicker: $flicker)';
}


}

/// @nodoc
abstract mixin class _$LightRigCopyWith<$Res> implements $LightRigCopyWith<$Res> {
  factory _$LightRigCopyWith(_LightRig value, $Res Function(_LightRig) _then) = __$LightRigCopyWithImpl;
@override @useResult
$Res call({
 int keyColor, double keyIntensity, double keyX, double keyY, int rimColor, double rimIntensity, int ambientColor, double ambientAmount, int fogColor, double flicker
});




}
/// @nodoc
class __$LightRigCopyWithImpl<$Res>
    implements _$LightRigCopyWith<$Res> {
  __$LightRigCopyWithImpl(this._self, this._then);

  final _LightRig _self;
  final $Res Function(_LightRig) _then;

/// Create a copy of LightRig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? keyColor = null,Object? keyIntensity = null,Object? keyX = null,Object? keyY = null,Object? rimColor = null,Object? rimIntensity = null,Object? ambientColor = null,Object? ambientAmount = null,Object? fogColor = null,Object? flicker = null,}) {
  return _then(_LightRig(
keyColor: null == keyColor ? _self.keyColor : keyColor // ignore: cast_nullable_to_non_nullable
as int,keyIntensity: null == keyIntensity ? _self.keyIntensity : keyIntensity // ignore: cast_nullable_to_non_nullable
as double,keyX: null == keyX ? _self.keyX : keyX // ignore: cast_nullable_to_non_nullable
as double,keyY: null == keyY ? _self.keyY : keyY // ignore: cast_nullable_to_non_nullable
as double,rimColor: null == rimColor ? _self.rimColor : rimColor // ignore: cast_nullable_to_non_nullable
as int,rimIntensity: null == rimIntensity ? _self.rimIntensity : rimIntensity // ignore: cast_nullable_to_non_nullable
as double,ambientColor: null == ambientColor ? _self.ambientColor : ambientColor // ignore: cast_nullable_to_non_nullable
as int,ambientAmount: null == ambientAmount ? _self.ambientAmount : ambientAmount // ignore: cast_nullable_to_non_nullable
as double,fogColor: null == fogColor ? _self.fogColor : fogColor // ignore: cast_nullable_to_non_nullable
as int,flicker: null == flicker ? _self.flicker : flicker // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
