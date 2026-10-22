// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sound_effects.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SoundEffect {

 String get name; String get path; double get volume;
/// Create a copy of SoundEffect
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SoundEffectCopyWith<SoundEffect> get copyWith => _$SoundEffectCopyWithImpl<SoundEffect>(this as SoundEffect, _$identity);

  /// Serializes this SoundEffect to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SoundEffect&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path)&&(identical(other.volume, volume) || other.volume == volume));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,path,volume);

@override
String toString() {
  return 'SoundEffect(name: $name, path: $path, volume: $volume)';
}


}

/// @nodoc
abstract mixin class $SoundEffectCopyWith<$Res>  {
  factory $SoundEffectCopyWith(SoundEffect value, $Res Function(SoundEffect) _then) = _$SoundEffectCopyWithImpl;
@useResult
$Res call({
 String name, String path, double volume
});




}
/// @nodoc
class _$SoundEffectCopyWithImpl<$Res>
    implements $SoundEffectCopyWith<$Res> {
  _$SoundEffectCopyWithImpl(this._self, this._then);

  final SoundEffect _self;
  final $Res Function(SoundEffect) _then;

/// Create a copy of SoundEffect
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? path = null,Object? volume = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [SoundEffect].
extension SoundEffectPatterns on SoundEffect {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SoundEffect value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SoundEffect() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SoundEffect value)  $default,){
final _that = this;
switch (_that) {
case _SoundEffect():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SoundEffect value)?  $default,){
final _that = this;
switch (_that) {
case _SoundEffect() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String path,  double volume)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SoundEffect() when $default != null:
return $default(_that.name,_that.path,_that.volume);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String path,  double volume)  $default,) {final _that = this;
switch (_that) {
case _SoundEffect():
return $default(_that.name,_that.path,_that.volume);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String path,  double volume)?  $default,) {final _that = this;
switch (_that) {
case _SoundEffect() when $default != null:
return $default(_that.name,_that.path,_that.volume);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SoundEffect implements SoundEffect {
  const _SoundEffect({required this.name, required this.path, this.volume = 1.0});
  factory _SoundEffect.fromJson(Map<String, dynamic> json) => _$SoundEffectFromJson(json);

@override final  String name;
@override final  String path;
@override@JsonKey() final  double volume;

/// Create a copy of SoundEffect
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SoundEffectCopyWith<_SoundEffect> get copyWith => __$SoundEffectCopyWithImpl<_SoundEffect>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SoundEffectToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SoundEffect&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path)&&(identical(other.volume, volume) || other.volume == volume));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,path,volume);

@override
String toString() {
  return 'SoundEffect(name: $name, path: $path, volume: $volume)';
}


}

/// @nodoc
abstract mixin class _$SoundEffectCopyWith<$Res> implements $SoundEffectCopyWith<$Res> {
  factory _$SoundEffectCopyWith(_SoundEffect value, $Res Function(_SoundEffect) _then) = __$SoundEffectCopyWithImpl;
@override @useResult
$Res call({
 String name, String path, double volume
});




}
/// @nodoc
class __$SoundEffectCopyWithImpl<$Res>
    implements _$SoundEffectCopyWith<$Res> {
  __$SoundEffectCopyWithImpl(this._self, this._then);

  final _SoundEffect _self;
  final $Res Function(_SoundEffect) _then;

/// Create a copy of SoundEffect
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? path = null,Object? volume = null,}) {
  return _then(_SoundEffect(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
