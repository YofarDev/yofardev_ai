// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_title_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatTitleState {

 Set<String> get generatingChatIds; TitleResult? get lastGeneratedTitle;
/// Create a copy of ChatTitleState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatTitleStateCopyWith<ChatTitleState> get copyWith => _$ChatTitleStateCopyWithImpl<ChatTitleState>(this as ChatTitleState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatTitleState&&const DeepCollectionEquality().equals(other.generatingChatIds, generatingChatIds)&&(identical(other.lastGeneratedTitle, lastGeneratedTitle) || other.lastGeneratedTitle == lastGeneratedTitle));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(generatingChatIds),lastGeneratedTitle);

@override
String toString() {
  return 'ChatTitleState(generatingChatIds: $generatingChatIds, lastGeneratedTitle: $lastGeneratedTitle)';
}


}

/// @nodoc
abstract mixin class $ChatTitleStateCopyWith<$Res>  {
  factory $ChatTitleStateCopyWith(ChatTitleState value, $Res Function(ChatTitleState) _then) = _$ChatTitleStateCopyWithImpl;
@useResult
$Res call({
 Set<String> generatingChatIds, TitleResult? lastGeneratedTitle
});




}
/// @nodoc
class _$ChatTitleStateCopyWithImpl<$Res>
    implements $ChatTitleStateCopyWith<$Res> {
  _$ChatTitleStateCopyWithImpl(this._self, this._then);

  final ChatTitleState _self;
  final $Res Function(ChatTitleState) _then;

/// Create a copy of ChatTitleState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? generatingChatIds = null,Object? lastGeneratedTitle = freezed,}) {
  return _then(_self.copyWith(
generatingChatIds: null == generatingChatIds ? _self.generatingChatIds : generatingChatIds // ignore: cast_nullable_to_non_nullable
as Set<String>,lastGeneratedTitle: freezed == lastGeneratedTitle ? _self.lastGeneratedTitle : lastGeneratedTitle // ignore: cast_nullable_to_non_nullable
as TitleResult?,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatTitleState].
extension ChatTitleStatePatterns on ChatTitleState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatTitleState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatTitleState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatTitleState value)  $default,){
final _that = this;
switch (_that) {
case _ChatTitleState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatTitleState value)?  $default,){
final _that = this;
switch (_that) {
case _ChatTitleState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Set<String> generatingChatIds,  TitleResult? lastGeneratedTitle)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatTitleState() when $default != null:
return $default(_that.generatingChatIds,_that.lastGeneratedTitle);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Set<String> generatingChatIds,  TitleResult? lastGeneratedTitle)  $default,) {final _that = this;
switch (_that) {
case _ChatTitleState():
return $default(_that.generatingChatIds,_that.lastGeneratedTitle);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Set<String> generatingChatIds,  TitleResult? lastGeneratedTitle)?  $default,) {final _that = this;
switch (_that) {
case _ChatTitleState() when $default != null:
return $default(_that.generatingChatIds,_that.lastGeneratedTitle);case _:
  return null;

}
}

}

/// @nodoc


class _ChatTitleState implements ChatTitleState {
  const _ChatTitleState({final  Set<String> generatingChatIds = const <String>{}, this.lastGeneratedTitle}): _generatingChatIds = generatingChatIds;
  

 final  Set<String> _generatingChatIds;
@override@JsonKey() Set<String> get generatingChatIds {
  if (_generatingChatIds is EqualUnmodifiableSetView) return _generatingChatIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_generatingChatIds);
}

@override final  TitleResult? lastGeneratedTitle;

/// Create a copy of ChatTitleState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatTitleStateCopyWith<_ChatTitleState> get copyWith => __$ChatTitleStateCopyWithImpl<_ChatTitleState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatTitleState&&const DeepCollectionEquality().equals(other._generatingChatIds, _generatingChatIds)&&(identical(other.lastGeneratedTitle, lastGeneratedTitle) || other.lastGeneratedTitle == lastGeneratedTitle));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_generatingChatIds),lastGeneratedTitle);

@override
String toString() {
  return 'ChatTitleState(generatingChatIds: $generatingChatIds, lastGeneratedTitle: $lastGeneratedTitle)';
}


}

/// @nodoc
abstract mixin class _$ChatTitleStateCopyWith<$Res> implements $ChatTitleStateCopyWith<$Res> {
  factory _$ChatTitleStateCopyWith(_ChatTitleState value, $Res Function(_ChatTitleState) _then) = __$ChatTitleStateCopyWithImpl;
@override @useResult
$Res call({
 Set<String> generatingChatIds, TitleResult? lastGeneratedTitle
});




}
/// @nodoc
class __$ChatTitleStateCopyWithImpl<$Res>
    implements _$ChatTitleStateCopyWith<$Res> {
  __$ChatTitleStateCopyWithImpl(this._self, this._then);

  final _ChatTitleState _self;
  final $Res Function(_ChatTitleState) _then;

/// Create a copy of ChatTitleState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? generatingChatIds = null,Object? lastGeneratedTitle = freezed,}) {
  return _then(_ChatTitleState(
generatingChatIds: null == generatingChatIds ? _self._generatingChatIds : generatingChatIds // ignore: cast_nullable_to_non_nullable
as Set<String>,lastGeneratedTitle: freezed == lastGeneratedTitle ? _self.lastGeneratedTitle : lastGeneratedTitle // ignore: cast_nullable_to_non_nullable
as TitleResult?,
  ));
}


}

// dart format on
