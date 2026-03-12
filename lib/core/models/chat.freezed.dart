// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Chat {

 String get id; List<ChatEntry> get entries;@AvatarJsonConverter() Avatar get avatar; String get language; String get systemPrompt; ChatPersona get persona; String get title; bool get titleGenerated;
/// Create a copy of Chat
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatCopyWith<Chat> get copyWith => _$ChatCopyWithImpl<Chat>(this as Chat, _$identity);

  /// Serializes this Chat to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Chat&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.entries, entries)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.language, language) || other.language == language)&&(identical(other.systemPrompt, systemPrompt) || other.systemPrompt == systemPrompt)&&(identical(other.persona, persona) || other.persona == persona)&&(identical(other.title, title) || other.title == title)&&(identical(other.titleGenerated, titleGenerated) || other.titleGenerated == titleGenerated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(entries),avatar,language,systemPrompt,persona,title,titleGenerated);

@override
String toString() {
  return 'Chat(id: $id, entries: $entries, avatar: $avatar, language: $language, systemPrompt: $systemPrompt, persona: $persona, title: $title, titleGenerated: $titleGenerated)';
}


}

/// @nodoc
abstract mixin class $ChatCopyWith<$Res>  {
  factory $ChatCopyWith(Chat value, $Res Function(Chat) _then) = _$ChatCopyWithImpl;
@useResult
$Res call({
 String id, List<ChatEntry> entries,@AvatarJsonConverter() Avatar avatar, String language, String systemPrompt, ChatPersona persona, String title, bool titleGenerated
});


$AvatarCopyWith<$Res> get avatar;

}
/// @nodoc
class _$ChatCopyWithImpl<$Res>
    implements $ChatCopyWith<$Res> {
  _$ChatCopyWithImpl(this._self, this._then);

  final Chat _self;
  final $Res Function(Chat) _then;

/// Create a copy of Chat
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? entries = null,Object? avatar = null,Object? language = null,Object? systemPrompt = null,Object? persona = null,Object? title = null,Object? titleGenerated = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<ChatEntry>,avatar: null == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as Avatar,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,systemPrompt: null == systemPrompt ? _self.systemPrompt : systemPrompt // ignore: cast_nullable_to_non_nullable
as String,persona: null == persona ? _self.persona : persona // ignore: cast_nullable_to_non_nullable
as ChatPersona,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,titleGenerated: null == titleGenerated ? _self.titleGenerated : titleGenerated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of Chat
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AvatarCopyWith<$Res> get avatar {
  
  return $AvatarCopyWith<$Res>(_self.avatar, (value) {
    return _then(_self.copyWith(avatar: value));
  });
}
}


/// Adds pattern-matching-related methods to [Chat].
extension ChatPatterns on Chat {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Chat value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Chat() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Chat value)  $default,){
final _that = this;
switch (_that) {
case _Chat():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Chat value)?  $default,){
final _that = this;
switch (_that) {
case _Chat() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  List<ChatEntry> entries, @AvatarJsonConverter()  Avatar avatar,  String language,  String systemPrompt,  ChatPersona persona,  String title,  bool titleGenerated)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Chat() when $default != null:
return $default(_that.id,_that.entries,_that.avatar,_that.language,_that.systemPrompt,_that.persona,_that.title,_that.titleGenerated);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  List<ChatEntry> entries, @AvatarJsonConverter()  Avatar avatar,  String language,  String systemPrompt,  ChatPersona persona,  String title,  bool titleGenerated)  $default,) {final _that = this;
switch (_that) {
case _Chat():
return $default(_that.id,_that.entries,_that.avatar,_that.language,_that.systemPrompt,_that.persona,_that.title,_that.titleGenerated);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  List<ChatEntry> entries, @AvatarJsonConverter()  Avatar avatar,  String language,  String systemPrompt,  ChatPersona persona,  String title,  bool titleGenerated)?  $default,) {final _that = this;
switch (_that) {
case _Chat() when $default != null:
return $default(_that.id,_that.entries,_that.avatar,_that.language,_that.systemPrompt,_that.persona,_that.title,_that.titleGenerated);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Chat extends Chat {
  const _Chat({this.id = '', final  List<ChatEntry> entries = const <ChatEntry>[], @AvatarJsonConverter() this.avatar = const Avatar(), this.language = 'fr', this.systemPrompt = '', this.persona = ChatPersona.normal, this.title = '', this.titleGenerated = false}): _entries = entries,super._();
  factory _Chat.fromJson(Map<String, dynamic> json) => _$ChatFromJson(json);

@override@JsonKey() final  String id;
 final  List<ChatEntry> _entries;
@override@JsonKey() List<ChatEntry> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}

@override@JsonKey()@AvatarJsonConverter() final  Avatar avatar;
@override@JsonKey() final  String language;
@override@JsonKey() final  String systemPrompt;
@override@JsonKey() final  ChatPersona persona;
@override@JsonKey() final  String title;
@override@JsonKey() final  bool titleGenerated;

/// Create a copy of Chat
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatCopyWith<_Chat> get copyWith => __$ChatCopyWithImpl<_Chat>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Chat&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other._entries, _entries)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.language, language) || other.language == language)&&(identical(other.systemPrompt, systemPrompt) || other.systemPrompt == systemPrompt)&&(identical(other.persona, persona) || other.persona == persona)&&(identical(other.title, title) || other.title == title)&&(identical(other.titleGenerated, titleGenerated) || other.titleGenerated == titleGenerated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(_entries),avatar,language,systemPrompt,persona,title,titleGenerated);

@override
String toString() {
  return 'Chat(id: $id, entries: $entries, avatar: $avatar, language: $language, systemPrompt: $systemPrompt, persona: $persona, title: $title, titleGenerated: $titleGenerated)';
}


}

/// @nodoc
abstract mixin class _$ChatCopyWith<$Res> implements $ChatCopyWith<$Res> {
  factory _$ChatCopyWith(_Chat value, $Res Function(_Chat) _then) = __$ChatCopyWithImpl;
@override @useResult
$Res call({
 String id, List<ChatEntry> entries,@AvatarJsonConverter() Avatar avatar, String language, String systemPrompt, ChatPersona persona, String title, bool titleGenerated
});


@override $AvatarCopyWith<$Res> get avatar;

}
/// @nodoc
class __$ChatCopyWithImpl<$Res>
    implements _$ChatCopyWith<$Res> {
  __$ChatCopyWithImpl(this._self, this._then);

  final _Chat _self;
  final $Res Function(_Chat) _then;

/// Create a copy of Chat
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? entries = null,Object? avatar = null,Object? language = null,Object? systemPrompt = null,Object? persona = null,Object? title = null,Object? titleGenerated = null,}) {
  return _then(_Chat(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<ChatEntry>,avatar: null == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as Avatar,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,systemPrompt: null == systemPrompt ? _self.systemPrompt : systemPrompt // ignore: cast_nullable_to_non_nullable
as String,persona: null == persona ? _self.persona : persona // ignore: cast_nullable_to_non_nullable
as ChatPersona,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,titleGenerated: null == titleGenerated ? _self.titleGenerated : titleGenerated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of Chat
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AvatarCopyWith<$Res> get avatar {
  
  return $AvatarCopyWith<$Res>(_self.avatar, (value) {
    return _then(_self.copyWith(avatar: value));
  });
}
}

// dart format on
