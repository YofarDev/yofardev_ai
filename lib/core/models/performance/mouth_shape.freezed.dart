// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mouth_shape.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MouthShape {

 double get jaw; double get pucker; double get stretch; double get press; double get lipTuck; double get tongueUp;
/// Create a copy of MouthShape
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MouthShapeCopyWith<MouthShape> get copyWith => _$MouthShapeCopyWithImpl<MouthShape>(this as MouthShape, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MouthShape;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MouthShape&&(identical(other.jaw, _this.jaw) || other.jaw == _this.jaw)&&(identical(other.pucker, _this.pucker) || other.pucker == _this.pucker)&&(identical(other.stretch, _this.stretch) || other.stretch == _this.stretch)&&(identical(other.press, _this.press) || other.press == _this.press)&&(identical(other.lipTuck, _this.lipTuck) || other.lipTuck == _this.lipTuck)&&(identical(other.tongueUp, _this.tongueUp) || other.tongueUp == _this.tongueUp));
}


@override
int get hashCode {
  final _this = this as MouthShape;
  return Object.hash(runtimeType,_this.jaw,_this.pucker,_this.stretch,_this.press,_this.lipTuck,_this.tongueUp);
}

@override
String toString() {
  final _this = this as MouthShape;
  return 'MouthShape(jaw: ${_this.jaw}, pucker: ${_this.pucker}, stretch: ${_this.stretch}, press: ${_this.press}, lipTuck: ${_this.lipTuck}, tongueUp: ${_this.tongueUp})';
}


}

/// @nodoc
abstract mixin class $MouthShapeCopyWith<$Res>  {
  factory $MouthShapeCopyWith(MouthShape value, $Res Function(MouthShape) _then) = _$MouthShapeCopyWithImpl;
@useResult
$Res call({
 double jaw, double pucker, double stretch, double press, double lipTuck, double tongueUp
});




}
/// @nodoc
class _$MouthShapeCopyWithImpl<$Res>
    implements $MouthShapeCopyWith<$Res> {
  _$MouthShapeCopyWithImpl(this._self, this._then);

  final MouthShape _self;
  final $Res Function(MouthShape) _then;

/// Create a copy of MouthShape
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? jaw = null,Object? pucker = null,Object? stretch = null,Object? press = null,Object? lipTuck = null,Object? tongueUp = null,}) {
  return _then(MouthShape(
jaw: null == jaw ? _self.jaw : jaw // ignore: cast_nullable_to_non_nullable
as double,pucker: null == pucker ? _self.pucker : pucker // ignore: cast_nullable_to_non_nullable
as double,stretch: null == stretch ? _self.stretch : stretch // ignore: cast_nullable_to_non_nullable
as double,press: null == press ? _self.press : press // ignore: cast_nullable_to_non_nullable
as double,lipTuck: null == lipTuck ? _self.lipTuck : lipTuck // ignore: cast_nullable_to_non_nullable
as double,tongueUp: null == tongueUp ? _self.tongueUp : tongueUp // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [MouthShape].
extension MouthShapePatterns on MouthShape {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MouthShape value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MouthShape() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MouthShape value)  $default,){
final _that = this;
switch (_that) {
case _MouthShape():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MouthShape value)?  $default,){
final _that = this;
switch (_that) {
case _MouthShape() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double jaw,  double pucker,  double stretch,  double press,  double lipTuck,  double tongueUp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MouthShape() when $default != null:
return $default(_that.jaw,_that.pucker,_that.stretch,_that.press,_that.lipTuck,_that.tongueUp);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double jaw,  double pucker,  double stretch,  double press,  double lipTuck,  double tongueUp)  $default,) {final _that = this;
switch (_that) {
case _MouthShape():
return $default(_that.jaw,_that.pucker,_that.stretch,_that.press,_that.lipTuck,_that.tongueUp);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double jaw,  double pucker,  double stretch,  double press,  double lipTuck,  double tongueUp)?  $default,) {final _that = this;
switch (_that) {
case _MouthShape() when $default != null:
return $default(_that.jaw,_that.pucker,_that.stretch,_that.press,_that.lipTuck,_that.tongueUp);case _:
  return null;

}
}

}

/// @nodoc


class _MouthShape extends MouthShape {
  const _MouthShape({this.jaw = 0.0, this.pucker = 0.0, this.stretch = 0.0, this.press = 0.0, this.lipTuck = 0.0, this.tongueUp = 0.0}): super._();
  

@override@JsonKey() final  double jaw;
@override@JsonKey() final  double pucker;
@override@JsonKey() final  double stretch;
@override@JsonKey() final  double press;
@override@JsonKey() final  double lipTuck;
@override@JsonKey() final  double tongueUp;

/// Create a copy of MouthShape
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MouthShapeCopyWith<_MouthShape> get copyWith => __$MouthShapeCopyWithImpl<_MouthShape>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MouthShape&&(identical(other.jaw, jaw) || other.jaw == jaw)&&(identical(other.pucker, pucker) || other.pucker == pucker)&&(identical(other.stretch, stretch) || other.stretch == stretch)&&(identical(other.press, press) || other.press == press)&&(identical(other.lipTuck, lipTuck) || other.lipTuck == lipTuck)&&(identical(other.tongueUp, tongueUp) || other.tongueUp == tongueUp));
}


@override
int get hashCode {
    return Object.hash(runtimeType,jaw,pucker,stretch,press,lipTuck,tongueUp);
}

@override
String toString() {
    return 'MouthShape(jaw: $jaw, pucker: $pucker, stretch: $stretch, press: $press, lipTuck: $lipTuck, tongueUp: $tongueUp)';
}


}

/// @nodoc
abstract mixin class _$MouthShapeCopyWith<$Res> implements $MouthShapeCopyWith<$Res> {
  factory _$MouthShapeCopyWith(_MouthShape value, $Res Function(_MouthShape) _then) = __$MouthShapeCopyWithImpl;
@override @useResult
$Res call({
 double jaw, double pucker, double stretch, double press, double lipTuck, double tongueUp
});




}
/// @nodoc
class __$MouthShapeCopyWithImpl<$Res>
    implements _$MouthShapeCopyWith<$Res> {
  __$MouthShapeCopyWithImpl(this._self, this._then);

  final _MouthShape _self;
  final $Res Function(_MouthShape) _then;

/// Create a copy of MouthShape
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? jaw = null,Object? pucker = null,Object? stretch = null,Object? press = null,Object? lipTuck = null,Object? tongueUp = null,}) {
  return _then(_MouthShape(
jaw: null == jaw ? _self.jaw : jaw // ignore: cast_nullable_to_non_nullable
as double,pucker: null == pucker ? _self.pucker : pucker // ignore: cast_nullable_to_non_nullable
as double,stretch: null == stretch ? _self.stretch : stretch // ignore: cast_nullable_to_non_nullable
as double,press: null == press ? _self.press : press // ignore: cast_nullable_to_non_nullable
as double,lipTuck: null == lipTuck ? _self.lipTuck : lipTuck // ignore: cast_nullable_to_non_nullable
as double,tongueUp: null == tongueUp ? _self.tongueUp : tongueUp // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
