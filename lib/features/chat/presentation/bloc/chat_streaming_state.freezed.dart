// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_streaming_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatStreamingState {

 ChatStreamingStatus get status; String get errorMessage; String get streamingContent; int get streamingSentenceCount;
/// Create a copy of ChatStreamingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatStreamingStateCopyWith<ChatStreamingState> get copyWith => _$ChatStreamingStateCopyWithImpl<ChatStreamingState>(this as ChatStreamingState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatStreamingState&&(identical(other.status, status) || other.status == status)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.streamingContent, streamingContent) || other.streamingContent == streamingContent)&&(identical(other.streamingSentenceCount, streamingSentenceCount) || other.streamingSentenceCount == streamingSentenceCount));
}


@override
int get hashCode => Object.hash(runtimeType,status,errorMessage,streamingContent,streamingSentenceCount);

@override
String toString() {
  return 'ChatStreamingState(status: $status, errorMessage: $errorMessage, streamingContent: $streamingContent, streamingSentenceCount: $streamingSentenceCount)';
}


}

/// @nodoc
abstract mixin class $ChatStreamingStateCopyWith<$Res>  {
  factory $ChatStreamingStateCopyWith(ChatStreamingState value, $Res Function(ChatStreamingState) _then) = _$ChatStreamingStateCopyWithImpl;
@useResult
$Res call({
 ChatStreamingStatus status, String errorMessage, String streamingContent, int streamingSentenceCount
});




}
/// @nodoc
class _$ChatStreamingStateCopyWithImpl<$Res>
    implements $ChatStreamingStateCopyWith<$Res> {
  _$ChatStreamingStateCopyWithImpl(this._self, this._then);

  final ChatStreamingState _self;
  final $Res Function(ChatStreamingState) _then;

/// Create a copy of ChatStreamingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? errorMessage = null,Object? streamingContent = null,Object? streamingSentenceCount = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ChatStreamingStatus,errorMessage: null == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String,streamingContent: null == streamingContent ? _self.streamingContent : streamingContent // ignore: cast_nullable_to_non_nullable
as String,streamingSentenceCount: null == streamingSentenceCount ? _self.streamingSentenceCount : streamingSentenceCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatStreamingState].
extension ChatStreamingStatePatterns on ChatStreamingState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatStreamingState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatStreamingState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatStreamingState value)  $default,){
final _that = this;
switch (_that) {
case _ChatStreamingState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatStreamingState value)?  $default,){
final _that = this;
switch (_that) {
case _ChatStreamingState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ChatStreamingStatus status,  String errorMessage,  String streamingContent,  int streamingSentenceCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatStreamingState() when $default != null:
return $default(_that.status,_that.errorMessage,_that.streamingContent,_that.streamingSentenceCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ChatStreamingStatus status,  String errorMessage,  String streamingContent,  int streamingSentenceCount)  $default,) {final _that = this;
switch (_that) {
case _ChatStreamingState():
return $default(_that.status,_that.errorMessage,_that.streamingContent,_that.streamingSentenceCount);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ChatStreamingStatus status,  String errorMessage,  String streamingContent,  int streamingSentenceCount)?  $default,) {final _that = this;
switch (_that) {
case _ChatStreamingState() when $default != null:
return $default(_that.status,_that.errorMessage,_that.streamingContent,_that.streamingSentenceCount);case _:
  return null;

}
}

}

/// @nodoc


class _ChatStreamingState implements ChatStreamingState {
  const _ChatStreamingState({this.status = ChatStreamingStatus.initial, this.errorMessage = '', this.streamingContent = '', this.streamingSentenceCount = 0});
  

@override@JsonKey() final  ChatStreamingStatus status;
@override@JsonKey() final  String errorMessage;
@override@JsonKey() final  String streamingContent;
@override@JsonKey() final  int streamingSentenceCount;

/// Create a copy of ChatStreamingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatStreamingStateCopyWith<_ChatStreamingState> get copyWith => __$ChatStreamingStateCopyWithImpl<_ChatStreamingState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatStreamingState&&(identical(other.status, status) || other.status == status)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.streamingContent, streamingContent) || other.streamingContent == streamingContent)&&(identical(other.streamingSentenceCount, streamingSentenceCount) || other.streamingSentenceCount == streamingSentenceCount));
}


@override
int get hashCode => Object.hash(runtimeType,status,errorMessage,streamingContent,streamingSentenceCount);

@override
String toString() {
  return 'ChatStreamingState(status: $status, errorMessage: $errorMessage, streamingContent: $streamingContent, streamingSentenceCount: $streamingSentenceCount)';
}


}

/// @nodoc
abstract mixin class _$ChatStreamingStateCopyWith<$Res> implements $ChatStreamingStateCopyWith<$Res> {
  factory _$ChatStreamingStateCopyWith(_ChatStreamingState value, $Res Function(_ChatStreamingState) _then) = __$ChatStreamingStateCopyWithImpl;
@override @useResult
$Res call({
 ChatStreamingStatus status, String errorMessage, String streamingContent, int streamingSentenceCount
});




}
/// @nodoc
class __$ChatStreamingStateCopyWithImpl<$Res>
    implements _$ChatStreamingStateCopyWith<$Res> {
  __$ChatStreamingStateCopyWithImpl(this._self, this._then);

  final _ChatStreamingState _self;
  final $Res Function(_ChatStreamingState) _then;

/// Create a copy of ChatStreamingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? errorMessage = null,Object? streamingContent = null,Object? streamingSentenceCount = null,}) {
  return _then(_ChatStreamingState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ChatStreamingStatus,errorMessage: null == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String,streamingContent: null == streamingContent ? _self.streamingContent : streamingContent // ignore: cast_nullable_to_non_nullable
as String,streamingSentenceCount: null == streamingSentenceCount ? _self.streamingSentenceCount : streamingSentenceCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
