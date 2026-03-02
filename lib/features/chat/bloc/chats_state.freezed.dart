// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chats_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatsState {

 ChatsStatus get status; List<Chat> get chatsList; Chat get currentChat; Chat get openedChat; String get errorMessage; bool get soundEffectsEnabled; String get currentLanguage; List<Map<String, dynamic>> get audioPathsWaitingSentences; bool get initializing; bool get functionCallingEnabled; bool get chatCreated;
/// Create a copy of ChatsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatsStateCopyWith<ChatsState> get copyWith => _$ChatsStateCopyWithImpl<ChatsState>(this as ChatsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatsState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.chatsList, chatsList)&&const DeepCollectionEquality().equals(other.currentChat, currentChat)&&const DeepCollectionEquality().equals(other.openedChat, openedChat)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.soundEffectsEnabled, soundEffectsEnabled) || other.soundEffectsEnabled == soundEffectsEnabled)&&(identical(other.currentLanguage, currentLanguage) || other.currentLanguage == currentLanguage)&&const DeepCollectionEquality().equals(other.audioPathsWaitingSentences, audioPathsWaitingSentences)&&(identical(other.initializing, initializing) || other.initializing == initializing)&&(identical(other.functionCallingEnabled, functionCallingEnabled) || other.functionCallingEnabled == functionCallingEnabled)&&(identical(other.chatCreated, chatCreated) || other.chatCreated == chatCreated));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(chatsList),const DeepCollectionEquality().hash(currentChat),const DeepCollectionEquality().hash(openedChat),errorMessage,soundEffectsEnabled,currentLanguage,const DeepCollectionEquality().hash(audioPathsWaitingSentences),initializing,functionCallingEnabled,chatCreated);

@override
String toString() {
  return 'ChatsState(status: $status, chatsList: $chatsList, currentChat: $currentChat, openedChat: $openedChat, errorMessage: $errorMessage, soundEffectsEnabled: $soundEffectsEnabled, currentLanguage: $currentLanguage, audioPathsWaitingSentences: $audioPathsWaitingSentences, initializing: $initializing, functionCallingEnabled: $functionCallingEnabled, chatCreated: $chatCreated)';
}


}

/// @nodoc
abstract mixin class $ChatsStateCopyWith<$Res>  {
  factory $ChatsStateCopyWith(ChatsState value, $Res Function(ChatsState) _then) = _$ChatsStateCopyWithImpl;
@useResult
$Res call({
 ChatsStatus status, List<Chat> chatsList, Chat currentChat, Chat openedChat, String errorMessage, bool soundEffectsEnabled, String currentLanguage, List<Map<String, dynamic>> audioPathsWaitingSentences, bool initializing, bool functionCallingEnabled, bool chatCreated
});




}
/// @nodoc
class _$ChatsStateCopyWithImpl<$Res>
    implements $ChatsStateCopyWith<$Res> {
  _$ChatsStateCopyWithImpl(this._self, this._then);

  final ChatsState _self;
  final $Res Function(ChatsState) _then;

/// Create a copy of ChatsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? chatsList = null,Object? currentChat = freezed,Object? openedChat = freezed,Object? errorMessage = null,Object? soundEffectsEnabled = null,Object? currentLanguage = null,Object? audioPathsWaitingSentences = null,Object? initializing = null,Object? functionCallingEnabled = null,Object? chatCreated = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ChatsStatus,chatsList: null == chatsList ? _self.chatsList : chatsList // ignore: cast_nullable_to_non_nullable
as List<Chat>,currentChat: freezed == currentChat ? _self.currentChat : currentChat // ignore: cast_nullable_to_non_nullable
as Chat,openedChat: freezed == openedChat ? _self.openedChat : openedChat // ignore: cast_nullable_to_non_nullable
as Chat,errorMessage: null == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String,soundEffectsEnabled: null == soundEffectsEnabled ? _self.soundEffectsEnabled : soundEffectsEnabled // ignore: cast_nullable_to_non_nullable
as bool,currentLanguage: null == currentLanguage ? _self.currentLanguage : currentLanguage // ignore: cast_nullable_to_non_nullable
as String,audioPathsWaitingSentences: null == audioPathsWaitingSentences ? _self.audioPathsWaitingSentences : audioPathsWaitingSentences // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,initializing: null == initializing ? _self.initializing : initializing // ignore: cast_nullable_to_non_nullable
as bool,functionCallingEnabled: null == functionCallingEnabled ? _self.functionCallingEnabled : functionCallingEnabled // ignore: cast_nullable_to_non_nullable
as bool,chatCreated: null == chatCreated ? _self.chatCreated : chatCreated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatsState].
extension ChatsStatePatterns on ChatsState {
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ChatsStatus status,  List<Chat> chatsList,  Chat currentChat,  Chat openedChat,  String errorMessage,  bool soundEffectsEnabled,  String currentLanguage,  List<Map<String, dynamic>> audioPathsWaitingSentences,  bool initializing,  bool functionCallingEnabled,  bool chatCreated)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatsState() when $default != null:
return $default(_that.status,_that.chatsList,_that.currentChat,_that.openedChat,_that.errorMessage,_that.soundEffectsEnabled,_that.currentLanguage,_that.audioPathsWaitingSentences,_that.initializing,_that.functionCallingEnabled,_that.chatCreated);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ChatsStatus status,  List<Chat> chatsList,  Chat currentChat,  Chat openedChat,  String errorMessage,  bool soundEffectsEnabled,  String currentLanguage,  List<Map<String, dynamic>> audioPathsWaitingSentences,  bool initializing,  bool functionCallingEnabled,  bool chatCreated)  $default,) {final _that = this;
switch (_that) {
case _ChatsState():
return $default(_that.status,_that.chatsList,_that.currentChat,_that.openedChat,_that.errorMessage,_that.soundEffectsEnabled,_that.currentLanguage,_that.audioPathsWaitingSentences,_that.initializing,_that.functionCallingEnabled,_that.chatCreated);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ChatsStatus status,  List<Chat> chatsList,  Chat currentChat,  Chat openedChat,  String errorMessage,  bool soundEffectsEnabled,  String currentLanguage,  List<Map<String, dynamic>> audioPathsWaitingSentences,  bool initializing,  bool functionCallingEnabled,  bool chatCreated)?  $default,) {final _that = this;
switch (_that) {
case _ChatsState() when $default != null:
return $default(_that.status,_that.chatsList,_that.currentChat,_that.openedChat,_that.errorMessage,_that.soundEffectsEnabled,_that.currentLanguage,_that.audioPathsWaitingSentences,_that.initializing,_that.functionCallingEnabled,_that.chatCreated);case _:
  return null;

}
}

}

/// @nodoc


class _ChatsState implements ChatsState {
  const _ChatsState({this.status = ChatsStatus.initial, final  List<Chat> chatsList = const <Chat>[], required this.currentChat, required this.openedChat, this.errorMessage = '', this.soundEffectsEnabled = true, this.currentLanguage = 'fr', final  List<Map<String, dynamic>> audioPathsWaitingSentences = const <Map<String, dynamic>>[], this.initializing = true, this.functionCallingEnabled = true, this.chatCreated = false}): _chatsList = chatsList,_audioPathsWaitingSentences = audioPathsWaitingSentences;
  

@override@JsonKey() final  ChatsStatus status;
 final  List<Chat> _chatsList;
@override@JsonKey() List<Chat> get chatsList {
  if (_chatsList is EqualUnmodifiableListView) return _chatsList;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_chatsList);
}

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

/// Create a copy of ChatsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatsStateCopyWith<_ChatsState> get copyWith => __$ChatsStateCopyWithImpl<_ChatsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatsState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._chatsList, _chatsList)&&const DeepCollectionEquality().equals(other.currentChat, currentChat)&&const DeepCollectionEquality().equals(other.openedChat, openedChat)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.soundEffectsEnabled, soundEffectsEnabled) || other.soundEffectsEnabled == soundEffectsEnabled)&&(identical(other.currentLanguage, currentLanguage) || other.currentLanguage == currentLanguage)&&const DeepCollectionEquality().equals(other._audioPathsWaitingSentences, _audioPathsWaitingSentences)&&(identical(other.initializing, initializing) || other.initializing == initializing)&&(identical(other.functionCallingEnabled, functionCallingEnabled) || other.functionCallingEnabled == functionCallingEnabled)&&(identical(other.chatCreated, chatCreated) || other.chatCreated == chatCreated));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_chatsList),const DeepCollectionEquality().hash(currentChat),const DeepCollectionEquality().hash(openedChat),errorMessage,soundEffectsEnabled,currentLanguage,const DeepCollectionEquality().hash(_audioPathsWaitingSentences),initializing,functionCallingEnabled,chatCreated);

@override
String toString() {
  return 'ChatsState(status: $status, chatsList: $chatsList, currentChat: $currentChat, openedChat: $openedChat, errorMessage: $errorMessage, soundEffectsEnabled: $soundEffectsEnabled, currentLanguage: $currentLanguage, audioPathsWaitingSentences: $audioPathsWaitingSentences, initializing: $initializing, functionCallingEnabled: $functionCallingEnabled, chatCreated: $chatCreated)';
}


}

/// @nodoc
abstract mixin class _$ChatsStateCopyWith<$Res> implements $ChatsStateCopyWith<$Res> {
  factory _$ChatsStateCopyWith(_ChatsState value, $Res Function(_ChatsState) _then) = __$ChatsStateCopyWithImpl;
@override @useResult
$Res call({
 ChatsStatus status, List<Chat> chatsList, Chat currentChat, Chat openedChat, String errorMessage, bool soundEffectsEnabled, String currentLanguage, List<Map<String, dynamic>> audioPathsWaitingSentences, bool initializing, bool functionCallingEnabled, bool chatCreated
});




}
/// @nodoc
class __$ChatsStateCopyWithImpl<$Res>
    implements _$ChatsStateCopyWith<$Res> {
  __$ChatsStateCopyWithImpl(this._self, this._then);

  final _ChatsState _self;
  final $Res Function(_ChatsState) _then;

/// Create a copy of ChatsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? chatsList = null,Object? currentChat = freezed,Object? openedChat = freezed,Object? errorMessage = null,Object? soundEffectsEnabled = null,Object? currentLanguage = null,Object? audioPathsWaitingSentences = null,Object? initializing = null,Object? functionCallingEnabled = null,Object? chatCreated = null,}) {
  return _then(_ChatsState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ChatsStatus,chatsList: null == chatsList ? _self._chatsList : chatsList // ignore: cast_nullable_to_non_nullable
as List<Chat>,currentChat: freezed == currentChat ? _self.currentChat : currentChat // ignore: cast_nullable_to_non_nullable
as Chat,openedChat: freezed == openedChat ? _self.openedChat : openedChat // ignore: cast_nullable_to_non_nullable
as Chat,errorMessage: null == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String,soundEffectsEnabled: null == soundEffectsEnabled ? _self.soundEffectsEnabled : soundEffectsEnabled // ignore: cast_nullable_to_non_nullable
as bool,currentLanguage: null == currentLanguage ? _self.currentLanguage : currentLanguage // ignore: cast_nullable_to_non_nullable
as String,audioPathsWaitingSentences: null == audioPathsWaitingSentences ? _self._audioPathsWaitingSentences : audioPathsWaitingSentences // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,initializing: null == initializing ? _self.initializing : initializing // ignore: cast_nullable_to_non_nullable
as bool,functionCallingEnabled: null == functionCallingEnabled ? _self.functionCallingEnabled : functionCallingEnabled // ignore: cast_nullable_to_non_nullable
as bool,chatCreated: null == chatCreated ? _self.chatCreated : chatCreated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
