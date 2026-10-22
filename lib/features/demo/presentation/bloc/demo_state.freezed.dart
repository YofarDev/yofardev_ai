// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'demo_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DemoState {

 DemoStatus get status; int get countdownValue; DemoScript? get currentScript; int get remainingResponses;
/// Create a copy of DemoState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DemoStateCopyWith<DemoState> get copyWith => _$DemoStateCopyWithImpl<DemoState>(this as DemoState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DemoState&&(identical(other.status, status) || other.status == status)&&(identical(other.countdownValue, countdownValue) || other.countdownValue == countdownValue)&&(identical(other.currentScript, currentScript) || other.currentScript == currentScript)&&(identical(other.remainingResponses, remainingResponses) || other.remainingResponses == remainingResponses));
}


@override
int get hashCode => Object.hash(runtimeType,status,countdownValue,currentScript,remainingResponses);

@override
String toString() {
  return 'DemoState(status: $status, countdownValue: $countdownValue, currentScript: $currentScript, remainingResponses: $remainingResponses)';
}


}

/// @nodoc
abstract mixin class $DemoStateCopyWith<$Res>  {
  factory $DemoStateCopyWith(DemoState value, $Res Function(DemoState) _then) = _$DemoStateCopyWithImpl;
@useResult
$Res call({
 DemoStatus status, int countdownValue, DemoScript? currentScript, int remainingResponses
});




}
/// @nodoc
class _$DemoStateCopyWithImpl<$Res>
    implements $DemoStateCopyWith<$Res> {
  _$DemoStateCopyWithImpl(this._self, this._then);

  final DemoState _self;
  final $Res Function(DemoState) _then;

/// Create a copy of DemoState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? countdownValue = null,Object? currentScript = freezed,Object? remainingResponses = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DemoStatus,countdownValue: null == countdownValue ? _self.countdownValue : countdownValue // ignore: cast_nullable_to_non_nullable
as int,currentScript: freezed == currentScript ? _self.currentScript : currentScript // ignore: cast_nullable_to_non_nullable
as DemoScript?,remainingResponses: null == remainingResponses ? _self.remainingResponses : remainingResponses // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DemoState].
extension DemoStatePatterns on DemoState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DemoState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DemoState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DemoState value)  $default,){
final _that = this;
switch (_that) {
case _DemoState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DemoState value)?  $default,){
final _that = this;
switch (_that) {
case _DemoState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DemoStatus status,  int countdownValue,  DemoScript? currentScript,  int remainingResponses)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DemoState() when $default != null:
return $default(_that.status,_that.countdownValue,_that.currentScript,_that.remainingResponses);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DemoStatus status,  int countdownValue,  DemoScript? currentScript,  int remainingResponses)  $default,) {final _that = this;
switch (_that) {
case _DemoState():
return $default(_that.status,_that.countdownValue,_that.currentScript,_that.remainingResponses);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DemoStatus status,  int countdownValue,  DemoScript? currentScript,  int remainingResponses)?  $default,) {final _that = this;
switch (_that) {
case _DemoState() when $default != null:
return $default(_that.status,_that.countdownValue,_that.currentScript,_that.remainingResponses);case _:
  return null;

}
}

}

/// @nodoc


class _DemoState extends DemoState {
  const _DemoState({this.status = DemoStatus.idle, this.countdownValue = 0, this.currentScript, this.remainingResponses = 0}): super._();
  

@override@JsonKey() final  DemoStatus status;
@override@JsonKey() final  int countdownValue;
@override final  DemoScript? currentScript;
@override@JsonKey() final  int remainingResponses;

/// Create a copy of DemoState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DemoStateCopyWith<_DemoState> get copyWith => __$DemoStateCopyWithImpl<_DemoState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DemoState&&(identical(other.status, status) || other.status == status)&&(identical(other.countdownValue, countdownValue) || other.countdownValue == countdownValue)&&(identical(other.currentScript, currentScript) || other.currentScript == currentScript)&&(identical(other.remainingResponses, remainingResponses) || other.remainingResponses == remainingResponses));
}


@override
int get hashCode => Object.hash(runtimeType,status,countdownValue,currentScript,remainingResponses);

@override
String toString() {
  return 'DemoState(status: $status, countdownValue: $countdownValue, currentScript: $currentScript, remainingResponses: $remainingResponses)';
}


}

/// @nodoc
abstract mixin class _$DemoStateCopyWith<$Res> implements $DemoStateCopyWith<$Res> {
  factory _$DemoStateCopyWith(_DemoState value, $Res Function(_DemoState) _then) = __$DemoStateCopyWithImpl;
@override @useResult
$Res call({
 DemoStatus status, int countdownValue, DemoScript? currentScript, int remainingResponses
});




}
/// @nodoc
class __$DemoStateCopyWithImpl<$Res>
    implements _$DemoStateCopyWith<$Res> {
  __$DemoStateCopyWithImpl(this._self, this._then);

  final _DemoState _self;
  final $Res Function(_DemoState) _then;

/// Create a copy of DemoState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? countdownValue = null,Object? currentScript = freezed,Object? remainingResponses = null,}) {
  return _then(_DemoState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DemoStatus,countdownValue: null == countdownValue ? _self.countdownValue : countdownValue // ignore: cast_nullable_to_non_nullable
as int,currentScript: freezed == currentScript ? _self.currentScript : currentScript // ignore: cast_nullable_to_non_nullable
as DemoScript?,remainingResponses: null == remainingResponses ? _self.remainingResponses : remainingResponses // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
