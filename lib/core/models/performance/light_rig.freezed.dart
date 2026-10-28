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

 double get keyDirection; int get keyColor; double get keyIntensity; int get rimColor; double get rimIntensity; int get ambientColor; double get fog; int get flickerSeed; double get flickerAmount;
/// Create a copy of LightRig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LightRigCopyWith<LightRig> get copyWith => _$LightRigCopyWithImpl<LightRig>(this as LightRig, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LightRig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LightRig&&(identical(other.keyDirection, _this.keyDirection) || other.keyDirection == _this.keyDirection)&&(identical(other.keyColor, _this.keyColor) || other.keyColor == _this.keyColor)&&(identical(other.keyIntensity, _this.keyIntensity) || other.keyIntensity == _this.keyIntensity)&&(identical(other.rimColor, _this.rimColor) || other.rimColor == _this.rimColor)&&(identical(other.rimIntensity, _this.rimIntensity) || other.rimIntensity == _this.rimIntensity)&&(identical(other.ambientColor, _this.ambientColor) || other.ambientColor == _this.ambientColor)&&(identical(other.fog, _this.fog) || other.fog == _this.fog)&&(identical(other.flickerSeed, _this.flickerSeed) || other.flickerSeed == _this.flickerSeed)&&(identical(other.flickerAmount, _this.flickerAmount) || other.flickerAmount == _this.flickerAmount));
}


@override
int get hashCode {
  final _this = this as LightRig;
  return Object.hash(runtimeType,_this.keyDirection,_this.keyColor,_this.keyIntensity,_this.rimColor,_this.rimIntensity,_this.ambientColor,_this.fog,_this.flickerSeed,_this.flickerAmount);
}

@override
String toString() {
  final _this = this as LightRig;
  return 'LightRig(keyDirection: ${_this.keyDirection}, keyColor: ${_this.keyColor}, keyIntensity: ${_this.keyIntensity}, rimColor: ${_this.rimColor}, rimIntensity: ${_this.rimIntensity}, ambientColor: ${_this.ambientColor}, fog: ${_this.fog}, flickerSeed: ${_this.flickerSeed}, flickerAmount: ${_this.flickerAmount})';
}


}

/// @nodoc
abstract mixin class $LightRigCopyWith<$Res>  {
  factory $LightRigCopyWith(LightRig value, $Res Function(LightRig) _then) = _$LightRigCopyWithImpl;
@useResult
$Res call({
 double keyDirection, int keyColor, double keyIntensity, int rimColor, double rimIntensity, int ambientColor, double fog, int flickerSeed, double flickerAmount
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
@pragma('vm:prefer-inline') @override $Res call({Object? keyDirection = null,Object? keyColor = null,Object? keyIntensity = null,Object? rimColor = null,Object? rimIntensity = null,Object? ambientColor = null,Object? fog = null,Object? flickerSeed = null,Object? flickerAmount = null,}) {
  return _then(LightRig(
keyDirection: null == keyDirection ? _self.keyDirection : keyDirection // ignore: cast_nullable_to_non_nullable
as double,keyColor: null == keyColor ? _self.keyColor : keyColor // ignore: cast_nullable_to_non_nullable
as int,keyIntensity: null == keyIntensity ? _self.keyIntensity : keyIntensity // ignore: cast_nullable_to_non_nullable
as double,rimColor: null == rimColor ? _self.rimColor : rimColor // ignore: cast_nullable_to_non_nullable
as int,rimIntensity: null == rimIntensity ? _self.rimIntensity : rimIntensity // ignore: cast_nullable_to_non_nullable
as double,ambientColor: null == ambientColor ? _self.ambientColor : ambientColor // ignore: cast_nullable_to_non_nullable
as int,fog: null == fog ? _self.fog : fog // ignore: cast_nullable_to_non_nullable
as double,flickerSeed: null == flickerSeed ? _self.flickerSeed : flickerSeed // ignore: cast_nullable_to_non_nullable
as int,flickerAmount: null == flickerAmount ? _self.flickerAmount : flickerAmount // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double keyDirection,  int keyColor,  double keyIntensity,  int rimColor,  double rimIntensity,  int ambientColor,  double fog,  int flickerSeed,  double flickerAmount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LightRig() when $default != null:
return $default(_that.keyDirection,_that.keyColor,_that.keyIntensity,_that.rimColor,_that.rimIntensity,_that.ambientColor,_that.fog,_that.flickerSeed,_that.flickerAmount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double keyDirection,  int keyColor,  double keyIntensity,  int rimColor,  double rimIntensity,  int ambientColor,  double fog,  int flickerSeed,  double flickerAmount)  $default,) {final _that = this;
switch (_that) {
case _LightRig():
return $default(_that.keyDirection,_that.keyColor,_that.keyIntensity,_that.rimColor,_that.rimIntensity,_that.ambientColor,_that.fog,_that.flickerSeed,_that.flickerAmount);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double keyDirection,  int keyColor,  double keyIntensity,  int rimColor,  double rimIntensity,  int ambientColor,  double fog,  int flickerSeed,  double flickerAmount)?  $default,) {final _that = this;
switch (_that) {
case _LightRig() when $default != null:
return $default(_that.keyDirection,_that.keyColor,_that.keyIntensity,_that.rimColor,_that.rimIntensity,_that.ambientColor,_that.fog,_that.flickerSeed,_that.flickerAmount);case _:
  return null;

}
}

}

/// @nodoc


class _LightRig implements LightRig {
  const _LightRig({this.keyDirection = 0.0, this.keyColor = 0xFFFFFFFF, this.keyIntensity = 1.0, this.rimColor = 0xFFFFFFFF, this.rimIntensity = 0.35, this.ambientColor = 0xFF202028, this.fog = 0.0, this.flickerSeed = 0, this.flickerAmount = 0.0});
  

@override@JsonKey() final  double keyDirection;
@override@JsonKey() final  int keyColor;
@override@JsonKey() final  double keyIntensity;
@override@JsonKey() final  int rimColor;
@override@JsonKey() final  double rimIntensity;
@override@JsonKey() final  int ambientColor;
@override@JsonKey() final  double fog;
@override@JsonKey() final  int flickerSeed;
@override@JsonKey() final  double flickerAmount;

/// Create a copy of LightRig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LightRigCopyWith<_LightRig> get copyWith => __$LightRigCopyWithImpl<_LightRig>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LightRig&&(identical(other.keyDirection, keyDirection) || other.keyDirection == keyDirection)&&(identical(other.keyColor, keyColor) || other.keyColor == keyColor)&&(identical(other.keyIntensity, keyIntensity) || other.keyIntensity == keyIntensity)&&(identical(other.rimColor, rimColor) || other.rimColor == rimColor)&&(identical(other.rimIntensity, rimIntensity) || other.rimIntensity == rimIntensity)&&(identical(other.ambientColor, ambientColor) || other.ambientColor == ambientColor)&&(identical(other.fog, fog) || other.fog == fog)&&(identical(other.flickerSeed, flickerSeed) || other.flickerSeed == flickerSeed)&&(identical(other.flickerAmount, flickerAmount) || other.flickerAmount == flickerAmount));
}


@override
int get hashCode {
    return Object.hash(runtimeType,keyDirection,keyColor,keyIntensity,rimColor,rimIntensity,ambientColor,fog,flickerSeed,flickerAmount);
}

@override
String toString() {
    return 'LightRig(keyDirection: $keyDirection, keyColor: $keyColor, keyIntensity: $keyIntensity, rimColor: $rimColor, rimIntensity: $rimIntensity, ambientColor: $ambientColor, fog: $fog, flickerSeed: $flickerSeed, flickerAmount: $flickerAmount)';
}


}

/// @nodoc
abstract mixin class _$LightRigCopyWith<$Res> implements $LightRigCopyWith<$Res> {
  factory _$LightRigCopyWith(_LightRig value, $Res Function(_LightRig) _then) = __$LightRigCopyWithImpl;
@override @useResult
$Res call({
 double keyDirection, int keyColor, double keyIntensity, int rimColor, double rimIntensity, int ambientColor, double fog, int flickerSeed, double flickerAmount
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
@override @pragma('vm:prefer-inline') $Res call({Object? keyDirection = null,Object? keyColor = null,Object? keyIntensity = null,Object? rimColor = null,Object? rimIntensity = null,Object? ambientColor = null,Object? fog = null,Object? flickerSeed = null,Object? flickerAmount = null,}) {
  return _then(_LightRig(
keyDirection: null == keyDirection ? _self.keyDirection : keyDirection // ignore: cast_nullable_to_non_nullable
as double,keyColor: null == keyColor ? _self.keyColor : keyColor // ignore: cast_nullable_to_non_nullable
as int,keyIntensity: null == keyIntensity ? _self.keyIntensity : keyIntensity // ignore: cast_nullable_to_non_nullable
as double,rimColor: null == rimColor ? _self.rimColor : rimColor // ignore: cast_nullable_to_non_nullable
as int,rimIntensity: null == rimIntensity ? _self.rimIntensity : rimIntensity // ignore: cast_nullable_to_non_nullable
as double,ambientColor: null == ambientColor ? _self.ambientColor : ambientColor // ignore: cast_nullable_to_non_nullable
as int,fog: null == fog ? _self.fog : fog // ignore: cast_nullable_to_non_nullable
as double,flickerSeed: null == flickerSeed ? _self.flickerSeed : flickerSeed // ignore: cast_nullable_to_non_nullable
as int,flickerAmount: null == flickerAmount ? _self.flickerAmount : flickerAmount // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
