// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_message_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatMessageState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatMessageState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ChatMessageState()';
}


}

/// @nodoc
class $ChatMessageStateCopyWith<$Res>  {
$ChatMessageStateCopyWith(ChatMessageState _, $Res Function(ChatMessageState) __);
}


/// Adds pattern-matching-related methods to [ChatMessageState].
extension ChatMessageStatePatterns on ChatMessageState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatMessageState value)?  $default,{TResult Function( _Interrupted value)?  interrupted,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatMessageState() when $default != null:
return $default(_that);case _Interrupted() when interrupted != null:
return interrupted(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatMessageState value)  $default,{required TResult Function( _Interrupted value)  interrupted,}){
final _that = this;
switch (_that) {
case _ChatMessageState():
return $default(_that);case _Interrupted():
return interrupted(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatMessageState value)?  $default,{TResult? Function( _Interrupted value)?  interrupted,}){
final _that = this;
switch (_that) {
case _ChatMessageState() when $default != null:
return $default(_that);case _Interrupted() when interrupted != null:
return interrupted(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ChatMessageStatus status,  String errorMessage,  String streamingContent,  int streamingSentenceCount,  Set<String> generatingTitleChatIds,  List<Map<String, dynamic>> audioPathsWaitingSentences,  bool initializing)?  $default,{TResult Function()?  interrupted,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatMessageState() when $default != null:
return $default(_that.status,_that.errorMessage,_that.streamingContent,_that.streamingSentenceCount,_that.generatingTitleChatIds,_that.audioPathsWaitingSentences,_that.initializing);case _Interrupted() when interrupted != null:
return interrupted();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ChatMessageStatus status,  String errorMessage,  String streamingContent,  int streamingSentenceCount,  Set<String> generatingTitleChatIds,  List<Map<String, dynamic>> audioPathsWaitingSentences,  bool initializing)  $default,{required TResult Function()  interrupted,}) {final _that = this;
switch (_that) {
case _ChatMessageState():
return $default(_that.status,_that.errorMessage,_that.streamingContent,_that.streamingSentenceCount,_that.generatingTitleChatIds,_that.audioPathsWaitingSentences,_that.initializing);case _Interrupted():
return interrupted();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ChatMessageStatus status,  String errorMessage,  String streamingContent,  int streamingSentenceCount,  Set<String> generatingTitleChatIds,  List<Map<String, dynamic>> audioPathsWaitingSentences,  bool initializing)?  $default,{TResult? Function()?  interrupted,}) {final _that = this;
switch (_that) {
case _ChatMessageState() when $default != null:
return $default(_that.status,_that.errorMessage,_that.streamingContent,_that.streamingSentenceCount,_that.generatingTitleChatIds,_that.audioPathsWaitingSentences,_that.initializing);case _Interrupted() when interrupted != null:
return interrupted();case _:
  return null;

}
}

}

/// @nodoc


class _ChatMessageState implements ChatMessageState {
  const _ChatMessageState({this.status = ChatMessageStatus.initial, this.errorMessage = '', this.streamingContent = '', this.streamingSentenceCount = 0, final  Set<String> generatingTitleChatIds = const <String>{}, final  List<Map<String, dynamic>> audioPathsWaitingSentences = const <Map<String, dynamic>>[], this.initializing = true}): _generatingTitleChatIds = generatingTitleChatIds,_audioPathsWaitingSentences = audioPathsWaitingSentences;
  

@JsonKey() final  ChatMessageStatus status;
@JsonKey() final  String errorMessage;
@JsonKey() final  String streamingContent;
@JsonKey() final  int streamingSentenceCount;
 final  Set<String> _generatingTitleChatIds;
@JsonKey() Set<String> get generatingTitleChatIds {
  if (_generatingTitleChatIds is EqualUnmodifiableSetView) return _generatingTitleChatIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_generatingTitleChatIds);
}

 final  List<Map<String, dynamic>> _audioPathsWaitingSentences;
@JsonKey() List<Map<String, dynamic>> get audioPathsWaitingSentences {
  if (_audioPathsWaitingSentences is EqualUnmodifiableListView) return _audioPathsWaitingSentences;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_audioPathsWaitingSentences);
}

@JsonKey() final  bool initializing;

/// Create a copy of ChatMessageState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatMessageStateCopyWith<_ChatMessageState> get copyWith => __$ChatMessageStateCopyWithImpl<_ChatMessageState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatMessageState&&(identical(other.status, status) || other.status == status)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.streamingContent, streamingContent) || other.streamingContent == streamingContent)&&(identical(other.streamingSentenceCount, streamingSentenceCount) || other.streamingSentenceCount == streamingSentenceCount)&&const DeepCollectionEquality().equals(other._generatingTitleChatIds, _generatingTitleChatIds)&&const DeepCollectionEquality().equals(other._audioPathsWaitingSentences, _audioPathsWaitingSentences)&&(identical(other.initializing, initializing) || other.initializing == initializing));
}


@override
int get hashCode => Object.hash(runtimeType,status,errorMessage,streamingContent,streamingSentenceCount,const DeepCollectionEquality().hash(_generatingTitleChatIds),const DeepCollectionEquality().hash(_audioPathsWaitingSentences),initializing);

@override
String toString() {
  return 'ChatMessageState(status: $status, errorMessage: $errorMessage, streamingContent: $streamingContent, streamingSentenceCount: $streamingSentenceCount, generatingTitleChatIds: $generatingTitleChatIds, audioPathsWaitingSentences: $audioPathsWaitingSentences, initializing: $initializing)';
}


}

/// @nodoc
abstract mixin class _$ChatMessageStateCopyWith<$Res> implements $ChatMessageStateCopyWith<$Res> {
  factory _$ChatMessageStateCopyWith(_ChatMessageState value, $Res Function(_ChatMessageState) _then) = __$ChatMessageStateCopyWithImpl;
@useResult
$Res call({
 ChatMessageStatus status, String errorMessage, String streamingContent, int streamingSentenceCount, Set<String> generatingTitleChatIds, List<Map<String, dynamic>> audioPathsWaitingSentences, bool initializing
});




}
/// @nodoc
class __$ChatMessageStateCopyWithImpl<$Res>
    implements _$ChatMessageStateCopyWith<$Res> {
  __$ChatMessageStateCopyWithImpl(this._self, this._then);

  final _ChatMessageState _self;
  final $Res Function(_ChatMessageState) _then;

/// Create a copy of ChatMessageState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? status = null,Object? errorMessage = null,Object? streamingContent = null,Object? streamingSentenceCount = null,Object? generatingTitleChatIds = null,Object? audioPathsWaitingSentences = null,Object? initializing = null,}) {
  return _then(_ChatMessageState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ChatMessageStatus,errorMessage: null == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String,streamingContent: null == streamingContent ? _self.streamingContent : streamingContent // ignore: cast_nullable_to_non_nullable
as String,streamingSentenceCount: null == streamingSentenceCount ? _self.streamingSentenceCount : streamingSentenceCount // ignore: cast_nullable_to_non_nullable
as int,generatingTitleChatIds: null == generatingTitleChatIds ? _self._generatingTitleChatIds : generatingTitleChatIds // ignore: cast_nullable_to_non_nullable
as Set<String>,audioPathsWaitingSentences: null == audioPathsWaitingSentences ? _self._audioPathsWaitingSentences : audioPathsWaitingSentences // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,initializing: null == initializing ? _self.initializing : initializing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class _Interrupted implements ChatMessageState {
  const _Interrupted();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Interrupted);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ChatMessageState.interrupted()';
}


}




// dart format on
