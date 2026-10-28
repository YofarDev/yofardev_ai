// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gaze_target.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GazeTarget {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GazeTarget);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'GazeTarget()';
}


}

/// @nodoc
class $GazeTargetCopyWith<$Res>  {
$GazeTargetCopyWith(GazeTarget _, $Res Function(GazeTarget) __);
}


/// Adds pattern-matching-related methods to [GazeTarget].
extension GazeTargetPatterns on GazeTarget {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( GazeUser value)?  user,TResult Function( GazeAway value)?  away,TResult Function( GazePoint value)?  point,TResult Function( GazeCaret value)?  caret,required TResult orElse(),}){
final _that = this;
switch (_that) {
case GazeUser() when user != null:
return user(_that);case GazeAway() when away != null:
return away(_that);case GazePoint() when point != null:
return point(_that);case GazeCaret() when caret != null:
return caret(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( GazeUser value)  user,required TResult Function( GazeAway value)  away,required TResult Function( GazePoint value)  point,required TResult Function( GazeCaret value)  caret,}){
final _that = this;
switch (_that) {
case GazeUser():
return user(_that);case GazeAway():
return away(_that);case GazePoint():
return point(_that);case GazeCaret():
return caret(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( GazeUser value)?  user,TResult? Function( GazeAway value)?  away,TResult? Function( GazePoint value)?  point,TResult? Function( GazeCaret value)?  caret,}){
final _that = this;
switch (_that) {
case GazeUser() when user != null:
return user(_that);case GazeAway() when away != null:
return away(_that);case GazePoint() when point != null:
return point(_that);case GazeCaret() when caret != null:
return caret(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  user,TResult Function( double angle)?  away,TResult Function( double x,  double y)?  point,TResult Function()?  caret,required TResult orElse(),}) {final _that = this;
switch (_that) {
case GazeUser() when user != null:
return user();case GazeAway() when away != null:
return away(_that.angle);case GazePoint() when point != null:
return point(_that.x,_that.y);case GazeCaret() when caret != null:
return caret();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  user,required TResult Function( double angle)  away,required TResult Function( double x,  double y)  point,required TResult Function()  caret,}) {final _that = this;
switch (_that) {
case GazeUser():
return user();case GazeAway():
return away(_that.angle);case GazePoint():
return point(_that.x,_that.y);case GazeCaret():
return caret();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  user,TResult? Function( double angle)?  away,TResult? Function( double x,  double y)?  point,TResult? Function()?  caret,}) {final _that = this;
switch (_that) {
case GazeUser() when user != null:
return user();case GazeAway() when away != null:
return away(_that.angle);case GazePoint() when point != null:
return point(_that.x,_that.y);case GazeCaret() when caret != null:
return caret();case _:
  return null;

}
}

}

/// @nodoc


class GazeUser implements GazeTarget {
  const GazeUser();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GazeUser);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'GazeTarget.user()';
}


}




/// @nodoc


class GazeAway implements GazeTarget {
  const GazeAway(this.angle);
  

 final  double angle;

/// Create a copy of GazeTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GazeAwayCopyWith<GazeAway> get copyWith => _$GazeAwayCopyWithImpl<GazeAway>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GazeAway&&(identical(other.angle, angle) || other.angle == angle));
}


@override
int get hashCode {
    return Object.hash(runtimeType,angle);
}

@override
String toString() {
    return 'GazeTarget.away(angle: $angle)';
}


}

/// @nodoc
abstract mixin class $GazeAwayCopyWith<$Res> implements $GazeTargetCopyWith<$Res> {
  factory $GazeAwayCopyWith(GazeAway value, $Res Function(GazeAway) _then) = _$GazeAwayCopyWithImpl;
@useResult
$Res call({
 double angle
});




}
/// @nodoc
class _$GazeAwayCopyWithImpl<$Res>
    implements $GazeAwayCopyWith<$Res> {
  _$GazeAwayCopyWithImpl(this._self, this._then);

  final GazeAway _self;
  final $Res Function(GazeAway) _then;

/// Create a copy of GazeTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? angle = null,}) {
  return _then(GazeAway(
null == angle ? _self.angle : angle // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class GazePoint implements GazeTarget {
  const GazePoint(this.x, this.y);
  

 final  double x;
 final  double y;

/// Create a copy of GazeTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GazePointCopyWith<GazePoint> get copyWith => _$GazePointCopyWithImpl<GazePoint>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GazePoint&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y));
}


@override
int get hashCode {
    return Object.hash(runtimeType,x,y);
}

@override
String toString() {
    return 'GazeTarget.point(x: $x, y: $y)';
}


}

/// @nodoc
abstract mixin class $GazePointCopyWith<$Res> implements $GazeTargetCopyWith<$Res> {
  factory $GazePointCopyWith(GazePoint value, $Res Function(GazePoint) _then) = _$GazePointCopyWithImpl;
@useResult
$Res call({
 double x, double y
});




}
/// @nodoc
class _$GazePointCopyWithImpl<$Res>
    implements $GazePointCopyWith<$Res> {
  _$GazePointCopyWithImpl(this._self, this._then);

  final GazePoint _self;
  final $Res Function(GazePoint) _then;

/// Create a copy of GazeTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? x = null,Object? y = null,}) {
  return _then(GazePoint(
null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class GazeCaret implements GazeTarget {
  const GazeCaret();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GazeCaret);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'GazeTarget.caret()';
}


}




// dart format on
