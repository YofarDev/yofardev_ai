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

/// @nodoc
mixin _$ChatEntry {

 String get id; EntryType get entryType; String get body; DateTime get timestamp; String? get attachedImage;
/// Create a copy of ChatEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatEntryCopyWith<ChatEntry> get copyWith => _$ChatEntryCopyWithImpl<ChatEntry>(this as ChatEntry, _$identity);

  /// Serializes this ChatEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.entryType, entryType) || other.entryType == entryType)&&(identical(other.body, body) || other.body == body)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.attachedImage, attachedImage) || other.attachedImage == attachedImage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,entryType,body,timestamp,attachedImage);

@override
String toString() {
  return 'ChatEntry(id: $id, entryType: $entryType, body: $body, timestamp: $timestamp, attachedImage: $attachedImage)';
}


}

/// @nodoc
abstract mixin class $ChatEntryCopyWith<$Res>  {
  factory $ChatEntryCopyWith(ChatEntry value, $Res Function(ChatEntry) _then) = _$ChatEntryCopyWithImpl;
@useResult
$Res call({
 String id, EntryType entryType, String body, DateTime timestamp, String? attachedImage
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? entryType = null,Object? body = null,Object? timestamp = null,Object? attachedImage = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,entryType: null == entryType ? _self.entryType : entryType // ignore: cast_nullable_to_non_nullable
as EntryType,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,attachedImage: freezed == attachedImage ? _self.attachedImage : attachedImage // ignore: cast_nullable_to_non_nullable
as String?,
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatEntry value)  $default,){
final _that = this;
switch (_that) {
case _ChatEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatEntry value)?  $default,){
final _that = this;
switch (_that) {
case _ChatEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  EntryType entryType,  String body,  DateTime timestamp,  String? attachedImage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatEntry() when $default != null:
return $default(_that.id,_that.entryType,_that.body,_that.timestamp,_that.attachedImage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  EntryType entryType,  String body,  DateTime timestamp,  String? attachedImage)  $default,) {final _that = this;
switch (_that) {
case _ChatEntry():
return $default(_that.id,_that.entryType,_that.body,_that.timestamp,_that.attachedImage);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  EntryType entryType,  String body,  DateTime timestamp,  String? attachedImage)?  $default,) {final _that = this;
switch (_that) {
case _ChatEntry() when $default != null:
return $default(_that.id,_that.entryType,_that.body,_that.timestamp,_that.attachedImage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatEntry extends ChatEntry {
  const _ChatEntry({required this.id, required this.entryType, required this.body, required this.timestamp, this.attachedImage}): super._();
  factory _ChatEntry.fromJson(Map<String, dynamic> json) => _$ChatEntryFromJson(json);

@override final  String id;
@override final  EntryType entryType;
@override final  String body;
@override final  DateTime timestamp;
@override final  String? attachedImage;

/// Create a copy of ChatEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatEntryCopyWith<_ChatEntry> get copyWith => __$ChatEntryCopyWithImpl<_ChatEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.entryType, entryType) || other.entryType == entryType)&&(identical(other.body, body) || other.body == body)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.attachedImage, attachedImage) || other.attachedImage == attachedImage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,entryType,body,timestamp,attachedImage);

@override
String toString() {
  return 'ChatEntry(id: $id, entryType: $entryType, body: $body, timestamp: $timestamp, attachedImage: $attachedImage)';
}


}

/// @nodoc
abstract mixin class _$ChatEntryCopyWith<$Res> implements $ChatEntryCopyWith<$Res> {
  factory _$ChatEntryCopyWith(_ChatEntry value, $Res Function(_ChatEntry) _then) = __$ChatEntryCopyWithImpl;
@override @useResult
$Res call({
 String id, EntryType entryType, String body, DateTime timestamp, String? attachedImage
});




}
/// @nodoc
class __$ChatEntryCopyWithImpl<$Res>
    implements _$ChatEntryCopyWith<$Res> {
  __$ChatEntryCopyWithImpl(this._self, this._then);

  final _ChatEntry _self;
  final $Res Function(_ChatEntry) _then;

/// Create a copy of ChatEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? entryType = null,Object? body = null,Object? timestamp = null,Object? attachedImage = freezed,}) {
  return _then(_ChatEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,entryType: null == entryType ? _self.entryType : entryType // ignore: cast_nullable_to_non_nullable
as EntryType,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,attachedImage: freezed == attachedImage ? _self.attachedImage : attachedImage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
