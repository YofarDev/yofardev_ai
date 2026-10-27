// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'caption_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CaptionState {

 String? get text; int get seq; bool get enabled;
/// Create a copy of CaptionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CaptionStateCopyWith<CaptionState> get copyWith => _$CaptionStateCopyWithImpl<CaptionState>(this as CaptionState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CaptionState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CaptionState&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.seq, _this.seq) || other.seq == _this.seq)&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled));
}


@override
int get hashCode {
  final _this = this as CaptionState;
  return Object.hash(runtimeType,_this.text,_this.seq,_this.enabled);
}

@override
String toString() {
  final _this = this as CaptionState;
  return 'CaptionState(text: ${_this.text}, seq: ${_this.seq}, enabled: ${_this.enabled})';
}


}

/// @nodoc
abstract mixin class $CaptionStateCopyWith<$Res>  {
  factory $CaptionStateCopyWith(CaptionState value, $Res Function(CaptionState) _then) = _$CaptionStateCopyWithImpl;
@useResult
$Res call({
 String? text, int seq, bool enabled
});




}
/// @nodoc
class _$CaptionStateCopyWithImpl<$Res>
    implements $CaptionStateCopyWith<$Res> {
  _$CaptionStateCopyWithImpl(this._self, this._then);

  final CaptionState _self;
  final $Res Function(CaptionState) _then;

/// Create a copy of CaptionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = freezed,Object? seq = null,Object? enabled = null,}) {
  return _then(CaptionState(
text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CaptionState].
extension CaptionStatePatterns on CaptionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CaptionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CaptionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CaptionState value)  $default,){
final _that = this;
switch (_that) {
case _CaptionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CaptionState value)?  $default,){
final _that = this;
switch (_that) {
case _CaptionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? text,  int seq,  bool enabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CaptionState() when $default != null:
return $default(_that.text,_that.seq,_that.enabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? text,  int seq,  bool enabled)  $default,) {final _that = this;
switch (_that) {
case _CaptionState():
return $default(_that.text,_that.seq,_that.enabled);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? text,  int seq,  bool enabled)?  $default,) {final _that = this;
switch (_that) {
case _CaptionState() when $default != null:
return $default(_that.text,_that.seq,_that.enabled);case _:
  return null;

}
}

}

/// @nodoc


class _CaptionState implements CaptionState {
  const _CaptionState({this.text, this.seq = 0, this.enabled = true});
  

@override final  String? text;
@override@JsonKey() final  int seq;
@override@JsonKey() final  bool enabled;

/// Create a copy of CaptionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CaptionStateCopyWith<_CaptionState> get copyWith => __$CaptionStateCopyWithImpl<_CaptionState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CaptionState&&(identical(other.text, text) || other.text == text)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}


@override
int get hashCode {
    return Object.hash(runtimeType,text,seq,enabled);
}

@override
String toString() {
    return 'CaptionState(text: $text, seq: $seq, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class _$CaptionStateCopyWith<$Res> implements $CaptionStateCopyWith<$Res> {
  factory _$CaptionStateCopyWith(_CaptionState value, $Res Function(_CaptionState) _then) = __$CaptionStateCopyWithImpl;
@override @useResult
$Res call({
 String? text, int seq, bool enabled
});




}
/// @nodoc
class __$CaptionStateCopyWithImpl<$Res>
    implements _$CaptionStateCopyWith<$Res> {
  __$CaptionStateCopyWithImpl(this._self, this._then);

  final _CaptionState _self;
  final $Res Function(_CaptionState) _then;

/// Create a copy of CaptionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = freezed,Object? seq = null,Object? enabled = null,}) {
  return _then(_CaptionState(
text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
