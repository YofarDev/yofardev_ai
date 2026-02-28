// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
ChatEntry _$ChatEntryFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'text':
          return ChatEntryText.fromJson(
            json
          );
                case 'image':
          return ChatEntryImage.fromJson(
            json
          );
                case 'toolCall':
          return ChatEntryToolCall.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'ChatEntry',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$ChatEntry {

 String get id;
/// Create a copy of ChatEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatEntryCopyWith<ChatEntry> get copyWith => _$ChatEntryCopyWithImpl<ChatEntry>(this as ChatEntry, _$identity);

  /// Serializes this ChatEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatEntry&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'ChatEntry(id: $id)';
}


}

/// @nodoc
abstract mixin class $ChatEntryCopyWith<$Res>  {
  factory $ChatEntryCopyWith(ChatEntry value, $Res Function(ChatEntry) _then) = _$ChatEntryCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$ChatEntryCopyWithImpl<$Res>
    implements $ChatEntryCopyWith<$Res> {
  _$ChatEntryCopyWithImpl(this._self, this._then);

  final ChatEntry _self;
  final $Res Function(ChatEntry) _then;

/// Create a copy of ChatEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatEntry].
extension ChatEntryPatterns on ChatEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ChatEntryText value)?  text,TResult Function( ChatEntryImage value)?  image,TResult Function( ChatEntryToolCall value)?  toolCall,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ChatEntryText() when text != null:
return text(_that);case ChatEntryImage() when image != null:
return image(_that);case ChatEntryToolCall() when toolCall != null:
return toolCall(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ChatEntryText value)  text,required TResult Function( ChatEntryImage value)  image,required TResult Function( ChatEntryToolCall value)  toolCall,}){
final _that = this;
switch (_that) {
case ChatEntryText():
return text(_that);case ChatEntryImage():
return image(_that);case ChatEntryToolCall():
return toolCall(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ChatEntryText value)?  text,TResult? Function( ChatEntryImage value)?  image,TResult? Function( ChatEntryToolCall value)?  toolCall,}){
final _that = this;
switch (_that) {
case ChatEntryText() when text != null:
return text(_that);case ChatEntryImage() when image != null:
return image(_that);case ChatEntryToolCall() when toolCall != null:
return toolCall(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String id,  String content,  String role,  DateTime? timestamp)?  text,TResult Function( String id,  String imageUrl,  String role,  DateTime? timestamp)?  image,TResult Function( String id,  String toolName,  Map<String, dynamic> arguments)?  toolCall,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ChatEntryText() when text != null:
return text(_that.id,_that.content,_that.role,_that.timestamp);case ChatEntryImage() when image != null:
return image(_that.id,_that.imageUrl,_that.role,_that.timestamp);case ChatEntryToolCall() when toolCall != null:
return toolCall(_that.id,_that.toolName,_that.arguments);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String id,  String content,  String role,  DateTime? timestamp)  text,required TResult Function( String id,  String imageUrl,  String role,  DateTime? timestamp)  image,required TResult Function( String id,  String toolName,  Map<String, dynamic> arguments)  toolCall,}) {final _that = this;
switch (_that) {
case ChatEntryText():
return text(_that.id,_that.content,_that.role,_that.timestamp);case ChatEntryImage():
return image(_that.id,_that.imageUrl,_that.role,_that.timestamp);case ChatEntryToolCall():
return toolCall(_that.id,_that.toolName,_that.arguments);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String id,  String content,  String role,  DateTime? timestamp)?  text,TResult? Function( String id,  String imageUrl,  String role,  DateTime? timestamp)?  image,TResult? Function( String id,  String toolName,  Map<String, dynamic> arguments)?  toolCall,}) {final _that = this;
switch (_that) {
case ChatEntryText() when text != null:
return text(_that.id,_that.content,_that.role,_that.timestamp);case ChatEntryImage() when image != null:
return image(_that.id,_that.imageUrl,_that.role,_that.timestamp);case ChatEntryToolCall() when toolCall != null:
return toolCall(_that.id,_that.toolName,_that.arguments);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class ChatEntryText implements ChatEntry {
  const ChatEntryText({required this.id, required this.content, required this.role, this.timestamp, final  String? $type}): $type = $type ?? 'text';
  factory ChatEntryText.fromJson(Map<String, dynamic> json) => _$ChatEntryTextFromJson(json);

@override final  String id;
 final  String content;
 final  String role;
 final  DateTime? timestamp;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of ChatEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatEntryTextCopyWith<ChatEntryText> get copyWith => _$ChatEntryTextCopyWithImpl<ChatEntryText>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatEntryTextToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatEntryText&&(identical(other.id, id) || other.id == id)&&(identical(other.content, content) || other.content == content)&&(identical(other.role, role) || other.role == role)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,content,role,timestamp);

@override
String toString() {
  return 'ChatEntry.text(id: $id, content: $content, role: $role, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class $ChatEntryTextCopyWith<$Res> implements $ChatEntryCopyWith<$Res> {
  factory $ChatEntryTextCopyWith(ChatEntryText value, $Res Function(ChatEntryText) _then) = _$ChatEntryTextCopyWithImpl;
@override @useResult
$Res call({
 String id, String content, String role, DateTime? timestamp
});




}
/// @nodoc
class _$ChatEntryTextCopyWithImpl<$Res>
    implements $ChatEntryTextCopyWith<$Res> {
  _$ChatEntryTextCopyWithImpl(this._self, this._then);

  final ChatEntryText _self;
  final $Res Function(ChatEntryText) _then;

/// Create a copy of ChatEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? content = null,Object? role = null,Object? timestamp = freezed,}) {
  return _then(ChatEntryText(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ChatEntryImage implements ChatEntry {
  const ChatEntryImage({required this.id, required this.imageUrl, required this.role, this.timestamp, final  String? $type}): $type = $type ?? 'image';
  factory ChatEntryImage.fromJson(Map<String, dynamic> json) => _$ChatEntryImageFromJson(json);

@override final  String id;
 final  String imageUrl;
 final  String role;
 final  DateTime? timestamp;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of ChatEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatEntryImageCopyWith<ChatEntryImage> get copyWith => _$ChatEntryImageCopyWithImpl<ChatEntryImage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatEntryImageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatEntryImage&&(identical(other.id, id) || other.id == id)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.role, role) || other.role == role)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,imageUrl,role,timestamp);

@override
String toString() {
  return 'ChatEntry.image(id: $id, imageUrl: $imageUrl, role: $role, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class $ChatEntryImageCopyWith<$Res> implements $ChatEntryCopyWith<$Res> {
  factory $ChatEntryImageCopyWith(ChatEntryImage value, $Res Function(ChatEntryImage) _then) = _$ChatEntryImageCopyWithImpl;
@override @useResult
$Res call({
 String id, String imageUrl, String role, DateTime? timestamp
});




}
/// @nodoc
class _$ChatEntryImageCopyWithImpl<$Res>
    implements $ChatEntryImageCopyWith<$Res> {
  _$ChatEntryImageCopyWithImpl(this._self, this._then);

  final ChatEntryImage _self;
  final $Res Function(ChatEntryImage) _then;

/// Create a copy of ChatEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? imageUrl = null,Object? role = null,Object? timestamp = freezed,}) {
  return _then(ChatEntryImage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ChatEntryToolCall implements ChatEntry {
  const ChatEntryToolCall({required this.id, required this.toolName, required final  Map<String, dynamic> arguments, final  String? $type}): _arguments = arguments,$type = $type ?? 'toolCall';
  factory ChatEntryToolCall.fromJson(Map<String, dynamic> json) => _$ChatEntryToolCallFromJson(json);

@override final  String id;
 final  String toolName;
 final  Map<String, dynamic> _arguments;
 Map<String, dynamic> get arguments {
  if (_arguments is EqualUnmodifiableMapView) return _arguments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_arguments);
}


@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of ChatEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatEntryToolCallCopyWith<ChatEntryToolCall> get copyWith => _$ChatEntryToolCallCopyWithImpl<ChatEntryToolCall>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatEntryToolCallToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatEntryToolCall&&(identical(other.id, id) || other.id == id)&&(identical(other.toolName, toolName) || other.toolName == toolName)&&const DeepCollectionEquality().equals(other._arguments, _arguments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,toolName,const DeepCollectionEquality().hash(_arguments));

@override
String toString() {
  return 'ChatEntry.toolCall(id: $id, toolName: $toolName, arguments: $arguments)';
}


}

/// @nodoc
abstract mixin class $ChatEntryToolCallCopyWith<$Res> implements $ChatEntryCopyWith<$Res> {
  factory $ChatEntryToolCallCopyWith(ChatEntryToolCall value, $Res Function(ChatEntryToolCall) _then) = _$ChatEntryToolCallCopyWithImpl;
@override @useResult
$Res call({
 String id, String toolName, Map<String, dynamic> arguments
});




}
/// @nodoc
class _$ChatEntryToolCallCopyWithImpl<$Res>
    implements $ChatEntryToolCallCopyWith<$Res> {
  _$ChatEntryToolCallCopyWithImpl(this._self, this._then);

  final ChatEntryToolCall _self;
  final $Res Function(ChatEntryToolCall) _then;

/// Create a copy of ChatEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? toolName = null,Object? arguments = null,}) {
  return _then(ChatEntryToolCall(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String,arguments: null == arguments ? _self._arguments : arguments // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

// dart format on
