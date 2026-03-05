// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_list_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatListState {

 ChatListStatus get status; List<String> get chatsListIds; String get currentChatId; String get openedChatId; String get errorMessage; bool get soundEffectsEnabled; String get currentLanguage; bool get functionCallingEnabled; bool get chatCreated;
/// Create a copy of ChatListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatListStateCopyWith<ChatListState> get copyWith => _$ChatListStateCopyWithImpl<ChatListState>(this as ChatListState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatListState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.chatsListIds, chatsListIds)&&(identical(other.currentChatId, currentChatId) || other.currentChatId == currentChatId)&&(identical(other.openedChatId, openedChatId) || other.openedChatId == openedChatId)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.soundEffectsEnabled, soundEffectsEnabled) || other.soundEffectsEnabled == soundEffectsEnabled)&&(identical(other.currentLanguage, currentLanguage) || other.currentLanguage == currentLanguage)&&(identical(other.functionCallingEnabled, functionCallingEnabled) || other.functionCallingEnabled == functionCallingEnabled)&&(identical(other.chatCreated, chatCreated) || other.chatCreated == chatCreated));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(chatsListIds),currentChatId,openedChatId,errorMessage,soundEffectsEnabled,currentLanguage,functionCallingEnabled,chatCreated);

@override
String toString() {
  return 'ChatListState(status: $status, chatsListIds: $chatsListIds, currentChatId: $currentChatId, openedChatId: $openedChatId, errorMessage: $errorMessage, soundEffectsEnabled: $soundEffectsEnabled, currentLanguage: $currentLanguage, functionCallingEnabled: $functionCallingEnabled, chatCreated: $chatCreated)';
}


}

/// @nodoc
abstract mixin class $ChatListStateCopyWith<$Res>  {
  factory $ChatListStateCopyWith(ChatListState value, $Res Function(ChatListState) _then) = _$ChatListStateCopyWithImpl;
@useResult
$Res call({
 ChatListStatus status, List<String> chatsListIds, String currentChatId, String openedChatId, String errorMessage, bool soundEffectsEnabled, String currentLanguage, bool functionCallingEnabled, bool chatCreated
});




}
/// @nodoc
class _$ChatListStateCopyWithImpl<$Res>
    implements $ChatListStateCopyWith<$Res> {
  _$ChatListStateCopyWithImpl(this._self, this._then);

  final ChatListState _self;
  final $Res Function(ChatListState) _then;

/// Create a copy of ChatListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? chatsListIds = null,Object? currentChatId = null,Object? openedChatId = null,Object? errorMessage = null,Object? soundEffectsEnabled = null,Object? currentLanguage = null,Object? functionCallingEnabled = null,Object? chatCreated = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ChatListStatus,chatsListIds: null == chatsListIds ? _self.chatsListIds : chatsListIds // ignore: cast_nullable_to_non_nullable
as List<String>,currentChatId: null == currentChatId ? _self.currentChatId : currentChatId // ignore: cast_nullable_to_non_nullable
as String,openedChatId: null == openedChatId ? _self.openedChatId : openedChatId // ignore: cast_nullable_to_non_nullable
as String,errorMessage: null == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String,soundEffectsEnabled: null == soundEffectsEnabled ? _self.soundEffectsEnabled : soundEffectsEnabled // ignore: cast_nullable_to_non_nullable
as bool,currentLanguage: null == currentLanguage ? _self.currentLanguage : currentLanguage // ignore: cast_nullable_to_non_nullable
as String,functionCallingEnabled: null == functionCallingEnabled ? _self.functionCallingEnabled : functionCallingEnabled // ignore: cast_nullable_to_non_nullable
as bool,chatCreated: null == chatCreated ? _self.chatCreated : chatCreated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatListState].
extension ChatListStatePatterns on ChatListState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatListState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatListState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatListState value)  $default,){
final _that = this;
switch (_that) {
case _ChatListState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatListState value)?  $default,){
final _that = this;
switch (_that) {
case _ChatListState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ChatListStatus status,  List<String> chatsListIds,  String currentChatId,  String openedChatId,  String errorMessage,  bool soundEffectsEnabled,  String currentLanguage,  bool functionCallingEnabled,  bool chatCreated)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatListState() when $default != null:
return $default(_that.status,_that.chatsListIds,_that.currentChatId,_that.openedChatId,_that.errorMessage,_that.soundEffectsEnabled,_that.currentLanguage,_that.functionCallingEnabled,_that.chatCreated);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ChatListStatus status,  List<String> chatsListIds,  String currentChatId,  String openedChatId,  String errorMessage,  bool soundEffectsEnabled,  String currentLanguage,  bool functionCallingEnabled,  bool chatCreated)  $default,) {final _that = this;
switch (_that) {
case _ChatListState():
return $default(_that.status,_that.chatsListIds,_that.currentChatId,_that.openedChatId,_that.errorMessage,_that.soundEffectsEnabled,_that.currentLanguage,_that.functionCallingEnabled,_that.chatCreated);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ChatListStatus status,  List<String> chatsListIds,  String currentChatId,  String openedChatId,  String errorMessage,  bool soundEffectsEnabled,  String currentLanguage,  bool functionCallingEnabled,  bool chatCreated)?  $default,) {final _that = this;
switch (_that) {
case _ChatListState() when $default != null:
return $default(_that.status,_that.chatsListIds,_that.currentChatId,_that.openedChatId,_that.errorMessage,_that.soundEffectsEnabled,_that.currentLanguage,_that.functionCallingEnabled,_that.chatCreated);case _:
  return null;

}
}

}

/// @nodoc


class _ChatListState implements ChatListState {
  const _ChatListState({this.status = ChatListStatus.initial, final  List<String> chatsListIds = const <String>[], required this.currentChatId, required this.openedChatId, this.errorMessage = '', this.soundEffectsEnabled = true, this.currentLanguage = 'fr', this.functionCallingEnabled = true, this.chatCreated = false}): _chatsListIds = chatsListIds;
  

@override@JsonKey() final  ChatListStatus status;
 final  List<String> _chatsListIds;
@override@JsonKey() List<String> get chatsListIds {
  if (_chatsListIds is EqualUnmodifiableListView) return _chatsListIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_chatsListIds);
}

@override final  String currentChatId;
@override final  String openedChatId;
@override@JsonKey() final  String errorMessage;
@override@JsonKey() final  bool soundEffectsEnabled;
@override@JsonKey() final  String currentLanguage;
@override@JsonKey() final  bool functionCallingEnabled;
@override@JsonKey() final  bool chatCreated;

/// Create a copy of ChatListState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatListStateCopyWith<_ChatListState> get copyWith => __$ChatListStateCopyWithImpl<_ChatListState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatListState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._chatsListIds, _chatsListIds)&&(identical(other.currentChatId, currentChatId) || other.currentChatId == currentChatId)&&(identical(other.openedChatId, openedChatId) || other.openedChatId == openedChatId)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.soundEffectsEnabled, soundEffectsEnabled) || other.soundEffectsEnabled == soundEffectsEnabled)&&(identical(other.currentLanguage, currentLanguage) || other.currentLanguage == currentLanguage)&&(identical(other.functionCallingEnabled, functionCallingEnabled) || other.functionCallingEnabled == functionCallingEnabled)&&(identical(other.chatCreated, chatCreated) || other.chatCreated == chatCreated));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_chatsListIds),currentChatId,openedChatId,errorMessage,soundEffectsEnabled,currentLanguage,functionCallingEnabled,chatCreated);

@override
String toString() {
  return 'ChatListState(status: $status, chatsListIds: $chatsListIds, currentChatId: $currentChatId, openedChatId: $openedChatId, errorMessage: $errorMessage, soundEffectsEnabled: $soundEffectsEnabled, currentLanguage: $currentLanguage, functionCallingEnabled: $functionCallingEnabled, chatCreated: $chatCreated)';
}


}

/// @nodoc
abstract mixin class _$ChatListStateCopyWith<$Res> implements $ChatListStateCopyWith<$Res> {
  factory _$ChatListStateCopyWith(_ChatListState value, $Res Function(_ChatListState) _then) = __$ChatListStateCopyWithImpl;
@override @useResult
$Res call({
 ChatListStatus status, List<String> chatsListIds, String currentChatId, String openedChatId, String errorMessage, bool soundEffectsEnabled, String currentLanguage, bool functionCallingEnabled, bool chatCreated
});




}
/// @nodoc
class __$ChatListStateCopyWithImpl<$Res>
    implements _$ChatListStateCopyWith<$Res> {
  __$ChatListStateCopyWithImpl(this._self, this._then);

  final _ChatListState _self;
  final $Res Function(_ChatListState) _then;

/// Create a copy of ChatListState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? chatsListIds = null,Object? currentChatId = null,Object? openedChatId = null,Object? errorMessage = null,Object? soundEffectsEnabled = null,Object? currentLanguage = null,Object? functionCallingEnabled = null,Object? chatCreated = null,}) {
  return _then(_ChatListState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ChatListStatus,chatsListIds: null == chatsListIds ? _self._chatsListIds : chatsListIds // ignore: cast_nullable_to_non_nullable
as List<String>,currentChatId: null == currentChatId ? _self.currentChatId : currentChatId // ignore: cast_nullable_to_non_nullable
as String,openedChatId: null == openedChatId ? _self.openedChatId : openedChatId // ignore: cast_nullable_to_non_nullable
as String,errorMessage: null == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String,soundEffectsEnabled: null == soundEffectsEnabled ? _self.soundEffectsEnabled : soundEffectsEnabled // ignore: cast_nullable_to_non_nullable
as bool,currentLanguage: null == currentLanguage ? _self.currentLanguage : currentLanguage // ignore: cast_nullable_to_non_nullable
as String,functionCallingEnabled: null == functionCallingEnabled ? _self.functionCallingEnabled : functionCallingEnabled // ignore: cast_nullable_to_non_nullable
as bool,chatCreated: null == chatCreated ? _self.chatCreated : chatCreated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
