// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatState {

 ChatStatus get status; List<Chat> get chatsList; ChatsListStatus get chatsListStatus; String? get chatsListError; Chat get currentChat; Chat get openedChat; String get errorMessage; bool get soundEffectsEnabled; String get currentLanguage; List<Map<String, dynamic>> get audioPathsWaitingSentences; bool get initializing; bool get functionCallingEnabled; bool get chatCreated; String get streamingContent; int get streamingSentenceCount;// Note: Named generatingTitleChatIds to match existing usage across the codebase
// rather than renaming to generatingChatIds (as per original spec)
// This field tracks which chats are currently generating titles
 Set<String> get generatingTitleChatIds;/// Result of the most recent title generation
 TitleResult? get lastGeneratedTitle;/// Flag to track if user has manually created a chat during initialization
/// This prevents getCurrentChat from overwriting user's new chat
 bool get userCreatedChatDuringInit;
/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatStateCopyWith<ChatState> get copyWith => _$ChatStateCopyWithImpl<ChatState>(this as ChatState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.chatsList, chatsList)&&(identical(other.chatsListStatus, chatsListStatus) || other.chatsListStatus == chatsListStatus)&&(identical(other.chatsListError, chatsListError) || other.chatsListError == chatsListError)&&(identical(other.currentChat, currentChat) || other.currentChat == currentChat)&&(identical(other.openedChat, openedChat) || other.openedChat == openedChat)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.soundEffectsEnabled, soundEffectsEnabled) || other.soundEffectsEnabled == soundEffectsEnabled)&&(identical(other.currentLanguage, currentLanguage) || other.currentLanguage == currentLanguage)&&const DeepCollectionEquality().equals(other.audioPathsWaitingSentences, audioPathsWaitingSentences)&&(identical(other.initializing, initializing) || other.initializing == initializing)&&(identical(other.functionCallingEnabled, functionCallingEnabled) || other.functionCallingEnabled == functionCallingEnabled)&&(identical(other.chatCreated, chatCreated) || other.chatCreated == chatCreated)&&(identical(other.streamingContent, streamingContent) || other.streamingContent == streamingContent)&&(identical(other.streamingSentenceCount, streamingSentenceCount) || other.streamingSentenceCount == streamingSentenceCount)&&const DeepCollectionEquality().equals(other.generatingTitleChatIds, generatingTitleChatIds)&&(identical(other.lastGeneratedTitle, lastGeneratedTitle) || other.lastGeneratedTitle == lastGeneratedTitle)&&(identical(other.userCreatedChatDuringInit, userCreatedChatDuringInit) || other.userCreatedChatDuringInit == userCreatedChatDuringInit));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(chatsList),chatsListStatus,chatsListError,currentChat,openedChat,errorMessage,soundEffectsEnabled,currentLanguage,const DeepCollectionEquality().hash(audioPathsWaitingSentences),initializing,functionCallingEnabled,chatCreated,streamingContent,streamingSentenceCount,const DeepCollectionEquality().hash(generatingTitleChatIds),lastGeneratedTitle,userCreatedChatDuringInit);

@override
String toString() {
  return 'ChatState(status: $status, chatsList: $chatsList, chatsListStatus: $chatsListStatus, chatsListError: $chatsListError, currentChat: $currentChat, openedChat: $openedChat, errorMessage: $errorMessage, soundEffectsEnabled: $soundEffectsEnabled, currentLanguage: $currentLanguage, audioPathsWaitingSentences: $audioPathsWaitingSentences, initializing: $initializing, functionCallingEnabled: $functionCallingEnabled, chatCreated: $chatCreated, streamingContent: $streamingContent, streamingSentenceCount: $streamingSentenceCount, generatingTitleChatIds: $generatingTitleChatIds, lastGeneratedTitle: $lastGeneratedTitle, userCreatedChatDuringInit: $userCreatedChatDuringInit)';
}


}

/// @nodoc
abstract mixin class $ChatStateCopyWith<$Res>  {
  factory $ChatStateCopyWith(ChatState value, $Res Function(ChatState) _then) = _$ChatStateCopyWithImpl;
@useResult
$Res call({
 ChatStatus status, List<Chat> chatsList, ChatsListStatus chatsListStatus, String? chatsListError, Chat currentChat, Chat openedChat, String errorMessage, bool soundEffectsEnabled, String currentLanguage, List<Map<String, dynamic>> audioPathsWaitingSentences, bool initializing, bool functionCallingEnabled, bool chatCreated, String streamingContent, int streamingSentenceCount, Set<String> generatingTitleChatIds, TitleResult? lastGeneratedTitle, bool userCreatedChatDuringInit
});


$ChatCopyWith<$Res> get currentChat;$ChatCopyWith<$Res> get openedChat;

}
/// @nodoc
class _$ChatStateCopyWithImpl<$Res>
    implements $ChatStateCopyWith<$Res> {
  _$ChatStateCopyWithImpl(this._self, this._then);

  final ChatState _self;
  final $Res Function(ChatState) _then;

/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? chatsList = null,Object? chatsListStatus = null,Object? chatsListError = freezed,Object? currentChat = null,Object? openedChat = null,Object? errorMessage = null,Object? soundEffectsEnabled = null,Object? currentLanguage = null,Object? audioPathsWaitingSentences = null,Object? initializing = null,Object? functionCallingEnabled = null,Object? chatCreated = null,Object? streamingContent = null,Object? streamingSentenceCount = null,Object? generatingTitleChatIds = null,Object? lastGeneratedTitle = freezed,Object? userCreatedChatDuringInit = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ChatStatus,chatsList: null == chatsList ? _self.chatsList : chatsList // ignore: cast_nullable_to_non_nullable
as List<Chat>,chatsListStatus: null == chatsListStatus ? _self.chatsListStatus : chatsListStatus // ignore: cast_nullable_to_non_nullable
as ChatsListStatus,chatsListError: freezed == chatsListError ? _self.chatsListError : chatsListError // ignore: cast_nullable_to_non_nullable
as String?,currentChat: null == currentChat ? _self.currentChat : currentChat // ignore: cast_nullable_to_non_nullable
as Chat,openedChat: null == openedChat ? _self.openedChat : openedChat // ignore: cast_nullable_to_non_nullable
as Chat,errorMessage: null == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String,soundEffectsEnabled: null == soundEffectsEnabled ? _self.soundEffectsEnabled : soundEffectsEnabled // ignore: cast_nullable_to_non_nullable
as bool,currentLanguage: null == currentLanguage ? _self.currentLanguage : currentLanguage // ignore: cast_nullable_to_non_nullable
as String,audioPathsWaitingSentences: null == audioPathsWaitingSentences ? _self.audioPathsWaitingSentences : audioPathsWaitingSentences // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,initializing: null == initializing ? _self.initializing : initializing // ignore: cast_nullable_to_non_nullable
as bool,functionCallingEnabled: null == functionCallingEnabled ? _self.functionCallingEnabled : functionCallingEnabled // ignore: cast_nullable_to_non_nullable
as bool,chatCreated: null == chatCreated ? _self.chatCreated : chatCreated // ignore: cast_nullable_to_non_nullable
as bool,streamingContent: null == streamingContent ? _self.streamingContent : streamingContent // ignore: cast_nullable_to_non_nullable
as String,streamingSentenceCount: null == streamingSentenceCount ? _self.streamingSentenceCount : streamingSentenceCount // ignore: cast_nullable_to_non_nullable
as int,generatingTitleChatIds: null == generatingTitleChatIds ? _self.generatingTitleChatIds : generatingTitleChatIds // ignore: cast_nullable_to_non_nullable
as Set<String>,lastGeneratedTitle: freezed == lastGeneratedTitle ? _self.lastGeneratedTitle : lastGeneratedTitle // ignore: cast_nullable_to_non_nullable
as TitleResult?,userCreatedChatDuringInit: null == userCreatedChatDuringInit ? _self.userCreatedChatDuringInit : userCreatedChatDuringInit // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChatCopyWith<$Res> get currentChat {
  
  return $ChatCopyWith<$Res>(_self.currentChat, (value) {
    return _then(_self.copyWith(currentChat: value));
  });
}/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChatCopyWith<$Res> get openedChat {
  
  return $ChatCopyWith<$Res>(_self.openedChat, (value) {
    return _then(_self.copyWith(openedChat: value));
  });
}
}


/// Adds pattern-matching-related methods to [ChatState].
extension ChatStatePatterns on ChatState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatsState value)  $default,){
final _that = this;
switch (_that) {
case _ChatsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatsState value)?  $default,){
final _that = this;
switch (_that) {
case _ChatsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ChatStatus status,  List<Chat> chatsList,  ChatsListStatus chatsListStatus,  String? chatsListError,  Chat currentChat,  Chat openedChat,  String errorMessage,  bool soundEffectsEnabled,  String currentLanguage,  List<Map<String, dynamic>> audioPathsWaitingSentences,  bool initializing,  bool functionCallingEnabled,  bool chatCreated,  String streamingContent,  int streamingSentenceCount,  Set<String> generatingTitleChatIds,  TitleResult? lastGeneratedTitle,  bool userCreatedChatDuringInit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatsState() when $default != null:
return $default(_that.status,_that.chatsList,_that.chatsListStatus,_that.chatsListError,_that.currentChat,_that.openedChat,_that.errorMessage,_that.soundEffectsEnabled,_that.currentLanguage,_that.audioPathsWaitingSentences,_that.initializing,_that.functionCallingEnabled,_that.chatCreated,_that.streamingContent,_that.streamingSentenceCount,_that.generatingTitleChatIds,_that.lastGeneratedTitle,_that.userCreatedChatDuringInit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ChatStatus status,  List<Chat> chatsList,  ChatsListStatus chatsListStatus,  String? chatsListError,  Chat currentChat,  Chat openedChat,  String errorMessage,  bool soundEffectsEnabled,  String currentLanguage,  List<Map<String, dynamic>> audioPathsWaitingSentences,  bool initializing,  bool functionCallingEnabled,  bool chatCreated,  String streamingContent,  int streamingSentenceCount,  Set<String> generatingTitleChatIds,  TitleResult? lastGeneratedTitle,  bool userCreatedChatDuringInit)  $default,) {final _that = this;
switch (_that) {
case _ChatsState():
return $default(_that.status,_that.chatsList,_that.chatsListStatus,_that.chatsListError,_that.currentChat,_that.openedChat,_that.errorMessage,_that.soundEffectsEnabled,_that.currentLanguage,_that.audioPathsWaitingSentences,_that.initializing,_that.functionCallingEnabled,_that.chatCreated,_that.streamingContent,_that.streamingSentenceCount,_that.generatingTitleChatIds,_that.lastGeneratedTitle,_that.userCreatedChatDuringInit);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ChatStatus status,  List<Chat> chatsList,  ChatsListStatus chatsListStatus,  String? chatsListError,  Chat currentChat,  Chat openedChat,  String errorMessage,  bool soundEffectsEnabled,  String currentLanguage,  List<Map<String, dynamic>> audioPathsWaitingSentences,  bool initializing,  bool functionCallingEnabled,  bool chatCreated,  String streamingContent,  int streamingSentenceCount,  Set<String> generatingTitleChatIds,  TitleResult? lastGeneratedTitle,  bool userCreatedChatDuringInit)?  $default,) {final _that = this;
switch (_that) {
case _ChatsState() when $default != null:
return $default(_that.status,_that.chatsList,_that.chatsListStatus,_that.chatsListError,_that.currentChat,_that.openedChat,_that.errorMessage,_that.soundEffectsEnabled,_that.currentLanguage,_that.audioPathsWaitingSentences,_that.initializing,_that.functionCallingEnabled,_that.chatCreated,_that.streamingContent,_that.streamingSentenceCount,_that.generatingTitleChatIds,_that.lastGeneratedTitle,_that.userCreatedChatDuringInit);case _:
  return null;

}
}

}

/// @nodoc


class _ChatsState implements ChatState {
  const _ChatsState({this.status = ChatStatus.initial, final  List<Chat> chatsList = const <Chat>[], this.chatsListStatus = ChatsListStatus.initial, this.chatsListError, required this.currentChat, required this.openedChat, this.errorMessage = '', this.soundEffectsEnabled = true, this.currentLanguage = 'fr', final  List<Map<String, dynamic>> audioPathsWaitingSentences = const <Map<String, dynamic>>[], this.initializing = true, this.functionCallingEnabled = false, this.chatCreated = false, this.streamingContent = '', this.streamingSentenceCount = 0, final  Set<String> generatingTitleChatIds = const <String>{}, this.lastGeneratedTitle, this.userCreatedChatDuringInit = false}): _chatsList = chatsList,_audioPathsWaitingSentences = audioPathsWaitingSentences,_generatingTitleChatIds = generatingTitleChatIds;
  

@override@JsonKey() final  ChatStatus status;
 final  List<Chat> _chatsList;
@override@JsonKey() List<Chat> get chatsList {
  if (_chatsList is EqualUnmodifiableListView) return _chatsList;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_chatsList);
}

@override@JsonKey() final  ChatsListStatus chatsListStatus;
@override final  String? chatsListError;
@override final  Chat currentChat;
@override final  Chat openedChat;
@override@JsonKey() final  String errorMessage;
@override@JsonKey() final  bool soundEffectsEnabled;
@override@JsonKey() final  String currentLanguage;
 final  List<Map<String, dynamic>> _audioPathsWaitingSentences;
@override@JsonKey() List<Map<String, dynamic>> get audioPathsWaitingSentences {
  if (_audioPathsWaitingSentences is EqualUnmodifiableListView) return _audioPathsWaitingSentences;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_audioPathsWaitingSentences);
}

@override@JsonKey() final  bool initializing;
@override@JsonKey() final  bool functionCallingEnabled;
@override@JsonKey() final  bool chatCreated;
@override@JsonKey() final  String streamingContent;
@override@JsonKey() final  int streamingSentenceCount;
// Note: Named generatingTitleChatIds to match existing usage across the codebase
// rather than renaming to generatingChatIds (as per original spec)
// This field tracks which chats are currently generating titles
 final  Set<String> _generatingTitleChatIds;
// Note: Named generatingTitleChatIds to match existing usage across the codebase
// rather than renaming to generatingChatIds (as per original spec)
// This field tracks which chats are currently generating titles
@override@JsonKey() Set<String> get generatingTitleChatIds {
  if (_generatingTitleChatIds is EqualUnmodifiableSetView) return _generatingTitleChatIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_generatingTitleChatIds);
}

/// Result of the most recent title generation
@override final  TitleResult? lastGeneratedTitle;
/// Flag to track if user has manually created a chat during initialization
/// This prevents getCurrentChat from overwriting user's new chat
@override@JsonKey() final  bool userCreatedChatDuringInit;

/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatsStateCopyWith<_ChatsState> get copyWith => __$ChatsStateCopyWithImpl<_ChatsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatsState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._chatsList, _chatsList)&&(identical(other.chatsListStatus, chatsListStatus) || other.chatsListStatus == chatsListStatus)&&(identical(other.chatsListError, chatsListError) || other.chatsListError == chatsListError)&&(identical(other.currentChat, currentChat) || other.currentChat == currentChat)&&(identical(other.openedChat, openedChat) || other.openedChat == openedChat)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.soundEffectsEnabled, soundEffectsEnabled) || other.soundEffectsEnabled == soundEffectsEnabled)&&(identical(other.currentLanguage, currentLanguage) || other.currentLanguage == currentLanguage)&&const DeepCollectionEquality().equals(other._audioPathsWaitingSentences, _audioPathsWaitingSentences)&&(identical(other.initializing, initializing) || other.initializing == initializing)&&(identical(other.functionCallingEnabled, functionCallingEnabled) || other.functionCallingEnabled == functionCallingEnabled)&&(identical(other.chatCreated, chatCreated) || other.chatCreated == chatCreated)&&(identical(other.streamingContent, streamingContent) || other.streamingContent == streamingContent)&&(identical(other.streamingSentenceCount, streamingSentenceCount) || other.streamingSentenceCount == streamingSentenceCount)&&const DeepCollectionEquality().equals(other._generatingTitleChatIds, _generatingTitleChatIds)&&(identical(other.lastGeneratedTitle, lastGeneratedTitle) || other.lastGeneratedTitle == lastGeneratedTitle)&&(identical(other.userCreatedChatDuringInit, userCreatedChatDuringInit) || other.userCreatedChatDuringInit == userCreatedChatDuringInit));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_chatsList),chatsListStatus,chatsListError,currentChat,openedChat,errorMessage,soundEffectsEnabled,currentLanguage,const DeepCollectionEquality().hash(_audioPathsWaitingSentences),initializing,functionCallingEnabled,chatCreated,streamingContent,streamingSentenceCount,const DeepCollectionEquality().hash(_generatingTitleChatIds),lastGeneratedTitle,userCreatedChatDuringInit);

@override
String toString() {
  return 'ChatState(status: $status, chatsList: $chatsList, chatsListStatus: $chatsListStatus, chatsListError: $chatsListError, currentChat: $currentChat, openedChat: $openedChat, errorMessage: $errorMessage, soundEffectsEnabled: $soundEffectsEnabled, currentLanguage: $currentLanguage, audioPathsWaitingSentences: $audioPathsWaitingSentences, initializing: $initializing, functionCallingEnabled: $functionCallingEnabled, chatCreated: $chatCreated, streamingContent: $streamingContent, streamingSentenceCount: $streamingSentenceCount, generatingTitleChatIds: $generatingTitleChatIds, lastGeneratedTitle: $lastGeneratedTitle, userCreatedChatDuringInit: $userCreatedChatDuringInit)';
}


}

/// @nodoc
abstract mixin class _$ChatsStateCopyWith<$Res> implements $ChatStateCopyWith<$Res> {
  factory _$ChatsStateCopyWith(_ChatsState value, $Res Function(_ChatsState) _then) = __$ChatsStateCopyWithImpl;
@override @useResult
$Res call({
 ChatStatus status, List<Chat> chatsList, ChatsListStatus chatsListStatus, String? chatsListError, Chat currentChat, Chat openedChat, String errorMessage, bool soundEffectsEnabled, String currentLanguage, List<Map<String, dynamic>> audioPathsWaitingSentences, bool initializing, bool functionCallingEnabled, bool chatCreated, String streamingContent, int streamingSentenceCount, Set<String> generatingTitleChatIds, TitleResult? lastGeneratedTitle, bool userCreatedChatDuringInit
});


@override $ChatCopyWith<$Res> get currentChat;@override $ChatCopyWith<$Res> get openedChat;

}
/// @nodoc
class __$ChatsStateCopyWithImpl<$Res>
    implements _$ChatsStateCopyWith<$Res> {
  __$ChatsStateCopyWithImpl(this._self, this._then);

  final _ChatsState _self;
  final $Res Function(_ChatsState) _then;

/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? chatsList = null,Object? chatsListStatus = null,Object? chatsListError = freezed,Object? currentChat = null,Object? openedChat = null,Object? errorMessage = null,Object? soundEffectsEnabled = null,Object? currentLanguage = null,Object? audioPathsWaitingSentences = null,Object? initializing = null,Object? functionCallingEnabled = null,Object? chatCreated = null,Object? streamingContent = null,Object? streamingSentenceCount = null,Object? generatingTitleChatIds = null,Object? lastGeneratedTitle = freezed,Object? userCreatedChatDuringInit = null,}) {
  return _then(_ChatsState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ChatStatus,chatsList: null == chatsList ? _self._chatsList : chatsList // ignore: cast_nullable_to_non_nullable
as List<Chat>,chatsListStatus: null == chatsListStatus ? _self.chatsListStatus : chatsListStatus // ignore: cast_nullable_to_non_nullable
as ChatsListStatus,chatsListError: freezed == chatsListError ? _self.chatsListError : chatsListError // ignore: cast_nullable_to_non_nullable
as String?,currentChat: null == currentChat ? _self.currentChat : currentChat // ignore: cast_nullable_to_non_nullable
as Chat,openedChat: null == openedChat ? _self.openedChat : openedChat // ignore: cast_nullable_to_non_nullable
as Chat,errorMessage: null == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String,soundEffectsEnabled: null == soundEffectsEnabled ? _self.soundEffectsEnabled : soundEffectsEnabled // ignore: cast_nullable_to_non_nullable
as bool,currentLanguage: null == currentLanguage ? _self.currentLanguage : currentLanguage // ignore: cast_nullable_to_non_nullable
as String,audioPathsWaitingSentences: null == audioPathsWaitingSentences ? _self._audioPathsWaitingSentences : audioPathsWaitingSentences // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,initializing: null == initializing ? _self.initializing : initializing // ignore: cast_nullable_to_non_nullable
as bool,functionCallingEnabled: null == functionCallingEnabled ? _self.functionCallingEnabled : functionCallingEnabled // ignore: cast_nullable_to_non_nullable
as bool,chatCreated: null == chatCreated ? _self.chatCreated : chatCreated // ignore: cast_nullable_to_non_nullable
as bool,streamingContent: null == streamingContent ? _self.streamingContent : streamingContent // ignore: cast_nullable_to_non_nullable
as String,streamingSentenceCount: null == streamingSentenceCount ? _self.streamingSentenceCount : streamingSentenceCount // ignore: cast_nullable_to_non_nullable
as int,generatingTitleChatIds: null == generatingTitleChatIds ? _self._generatingTitleChatIds : generatingTitleChatIds // ignore: cast_nullable_to_non_nullable
as Set<String>,lastGeneratedTitle: freezed == lastGeneratedTitle ? _self.lastGeneratedTitle : lastGeneratedTitle // ignore: cast_nullable_to_non_nullable
as TitleResult?,userCreatedChatDuringInit: null == userCreatedChatDuringInit ? _self.userCreatedChatDuringInit : userCreatedChatDuringInit // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChatCopyWith<$Res> get currentChat {
  
  return $ChatCopyWith<$Res>(_self.currentChat, (value) {
    return _then(_self.copyWith(currentChat: value));
  });
}/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChatCopyWith<$Res> get openedChat {
  
  return $ChatCopyWith<$Res>(_self.openedChat, (value) {
    return _then(_self.copyWith(openedChat: value));
  });
}
}

// dart format on
