// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'emotion_vector.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$EmotionVector {

 double get valence; double get arousal; double get intensity;
/// Create a copy of EmotionVector
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EmotionVectorCopyWith<EmotionVector> get copyWith => _$EmotionVectorCopyWithImpl<EmotionVector>(this as EmotionVector, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as EmotionVector;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EmotionVector&&(identical(other.valence, _this.valence) || other.valence == _this.valence)&&(identical(other.arousal, _this.arousal) || other.arousal == _this.arousal)&&(identical(other.intensity, _this.intensity) || other.intensity == _this.intensity));
}


@override
int get hashCode {
  final _this = this as EmotionVector;
  return Object.hash(runtimeType,_this.valence,_this.arousal,_this.intensity);
}

@override
String toString() {
  final _this = this as EmotionVector;
  return 'EmotionVector(valence: ${_this.valence}, arousal: ${_this.arousal}, intensity: ${_this.intensity})';
}


}

/// @nodoc
abstract mixin class $EmotionVectorCopyWith<$Res>  {
  factory $EmotionVectorCopyWith(EmotionVector value, $Res Function(EmotionVector) _then) = _$EmotionVectorCopyWithImpl;
@useResult
$Res call({
 double valence, double arousal, double intensity
});




}
/// @nodoc
class _$EmotionVectorCopyWithImpl<$Res>
    implements $EmotionVectorCopyWith<$Res> {
  _$EmotionVectorCopyWithImpl(this._self, this._then);

  final EmotionVector _self;
  final $Res Function(EmotionVector) _then;

/// Create a copy of EmotionVector
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? valence = null,Object? arousal = null,Object? intensity = null,}) {
  return _then(EmotionVector(
valence: null == valence ? _self.valence : valence // ignore: cast_nullable_to_non_nullable
as double,arousal: null == arousal ? _self.arousal : arousal // ignore: cast_nullable_to_non_nullable
as double,intensity: null == intensity ? _self.intensity : intensity // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [EmotionVector].
extension EmotionVectorPatterns on EmotionVector {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EmotionVector value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EmotionVector() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EmotionVector value)  $default,){
final _that = this;
switch (_that) {
case _EmotionVector():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EmotionVector value)?  $default,){
final _that = this;
switch (_that) {
case _EmotionVector() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double valence,  double arousal,  double intensity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EmotionVector() when $default != null:
return $default(_that.valence,_that.arousal,_that.intensity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double valence,  double arousal,  double intensity)  $default,) {final _that = this;
switch (_that) {
case _EmotionVector():
return $default(_that.valence,_that.arousal,_that.intensity);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double valence,  double arousal,  double intensity)?  $default,) {final _that = this;
switch (_that) {
case _EmotionVector() when $default != null:
return $default(_that.valence,_that.arousal,_that.intensity);case _:
  return null;

}
}

}

/// @nodoc


class _EmotionVector extends EmotionVector {
  const _EmotionVector({this.valence = 0.0, this.arousal = 0.0, this.intensity = 1.0}): super._();
  

@override@JsonKey() final  double valence;
@override@JsonKey() final  double arousal;
@override@JsonKey() final  double intensity;

/// Create a copy of EmotionVector
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EmotionVectorCopyWith<_EmotionVector> get copyWith => __$EmotionVectorCopyWithImpl<_EmotionVector>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EmotionVector&&(identical(other.valence, valence) || other.valence == valence)&&(identical(other.arousal, arousal) || other.arousal == arousal)&&(identical(other.intensity, intensity) || other.intensity == intensity));
}


@override
int get hashCode {
    return Object.hash(runtimeType,valence,arousal,intensity);
}

@override
String toString() {
    return 'EmotionVector(valence: $valence, arousal: $arousal, intensity: $intensity)';
}


}

/// @nodoc
abstract mixin class _$EmotionVectorCopyWith<$Res> implements $EmotionVectorCopyWith<$Res> {
  factory _$EmotionVectorCopyWith(_EmotionVector value, $Res Function(_EmotionVector) _then) = __$EmotionVectorCopyWithImpl;
@override @useResult
$Res call({
 double valence, double arousal, double intensity
});




}
/// @nodoc
class __$EmotionVectorCopyWithImpl<$Res>
    implements _$EmotionVectorCopyWith<$Res> {
  __$EmotionVectorCopyWithImpl(this._self, this._then);

  final _EmotionVector _self;
  final $Res Function(_EmotionVector) _then;

/// Create a copy of EmotionVector
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? valence = null,Object? arousal = null,Object? intensity = null,}) {
  return _then(_EmotionVector(
valence: null == valence ? _self.valence : valence // ignore: cast_nullable_to_non_nullable
as double,arousal: null == arousal ? _self.arousal : arousal // ignore: cast_nullable_to_non_nullable
as double,intensity: null == intensity ? _self.intensity : intensity // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
