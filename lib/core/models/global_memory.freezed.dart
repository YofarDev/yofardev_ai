// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'global_memory.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GlobalMemoryItem {

 String get id; String get text; DateTime get updatedAt;
/// Create a copy of GlobalMemoryItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GlobalMemoryItemCopyWith<GlobalMemoryItem> get copyWith => _$GlobalMemoryItemCopyWithImpl<GlobalMemoryItem>(this as GlobalMemoryItem, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GlobalMemoryItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GlobalMemoryItem&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}


@override
int get hashCode {
  final _this = this as GlobalMemoryItem;
  return Object.hash(runtimeType,_this.id,_this.text,_this.updatedAt);
}

@override
String toString() {
  final _this = this as GlobalMemoryItem;
  return 'GlobalMemoryItem(id: ${_this.id}, text: ${_this.text}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $GlobalMemoryItemCopyWith<$Res>  {
  factory $GlobalMemoryItemCopyWith(GlobalMemoryItem value, $Res Function(GlobalMemoryItem) _then) = _$GlobalMemoryItemCopyWithImpl;
@useResult
$Res call({
 String id, String text, DateTime updatedAt
});




}
/// @nodoc
class _$GlobalMemoryItemCopyWithImpl<$Res>
    implements $GlobalMemoryItemCopyWith<$Res> {
  _$GlobalMemoryItemCopyWithImpl(this._self, this._then);

  final GlobalMemoryItem _self;
  final $Res Function(GlobalMemoryItem) _then;

/// Create a copy of GlobalMemoryItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? text = null,Object? updatedAt = null,}) {
  return _then(GlobalMemoryItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [GlobalMemoryItem].
extension GlobalMemoryItemPatterns on GlobalMemoryItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GlobalMemoryItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GlobalMemoryItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GlobalMemoryItem value)  $default,){
final _that = this;
switch (_that) {
case _GlobalMemoryItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GlobalMemoryItem value)?  $default,){
final _that = this;
switch (_that) {
case _GlobalMemoryItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String text,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GlobalMemoryItem() when $default != null:
return $default(_that.id,_that.text,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String text,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _GlobalMemoryItem():
return $default(_that.id,_that.text,_that.updatedAt);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String text,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _GlobalMemoryItem() when $default != null:
return $default(_that.id,_that.text,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _GlobalMemoryItem extends GlobalMemoryItem {
  const _GlobalMemoryItem({required this.id, required this.text, required this.updatedAt}): super._();
  

@override final  String id;
@override final  String text;
@override final  DateTime updatedAt;

/// Create a copy of GlobalMemoryItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GlobalMemoryItemCopyWith<_GlobalMemoryItem> get copyWith => __$GlobalMemoryItemCopyWithImpl<_GlobalMemoryItem>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GlobalMemoryItem&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,text,updatedAt);
}

@override
String toString() {
    return 'GlobalMemoryItem(id: $id, text: $text, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$GlobalMemoryItemCopyWith<$Res> implements $GlobalMemoryItemCopyWith<$Res> {
  factory _$GlobalMemoryItemCopyWith(_GlobalMemoryItem value, $Res Function(_GlobalMemoryItem) _then) = __$GlobalMemoryItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String text, DateTime updatedAt
});




}
/// @nodoc
class __$GlobalMemoryItemCopyWithImpl<$Res>
    implements _$GlobalMemoryItemCopyWith<$Res> {
  __$GlobalMemoryItemCopyWithImpl(this._self, this._then);

  final _GlobalMemoryItem _self;
  final $Res Function(_GlobalMemoryItem) _then;

/// Create a copy of GlobalMemoryItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? text = null,Object? updatedAt = null,}) {
  return _then(_GlobalMemoryItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
mixin _$GlobalMemory {

 List<GlobalMemoryItem> get items;
/// Create a copy of GlobalMemory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GlobalMemoryCopyWith<GlobalMemory> get copyWith => _$GlobalMemoryCopyWithImpl<GlobalMemory>(this as GlobalMemory, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GlobalMemory;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GlobalMemory&&const DeepCollectionEquality().equals(other.items, _this.items));
}


@override
int get hashCode {
  final _this = this as GlobalMemory;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.items));
}

@override
String toString() {
  final _this = this as GlobalMemory;
  return 'GlobalMemory(items: ${_this.items})';
}


}

/// @nodoc
abstract mixin class $GlobalMemoryCopyWith<$Res>  {
  factory $GlobalMemoryCopyWith(GlobalMemory value, $Res Function(GlobalMemory) _then) = _$GlobalMemoryCopyWithImpl;
@useResult
$Res call({
 List<GlobalMemoryItem> items
});




}
/// @nodoc
class _$GlobalMemoryCopyWithImpl<$Res>
    implements $GlobalMemoryCopyWith<$Res> {
  _$GlobalMemoryCopyWithImpl(this._self, this._then);

  final GlobalMemory _self;
  final $Res Function(GlobalMemory) _then;

/// Create a copy of GlobalMemory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,}) {
  return _then(GlobalMemory(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<GlobalMemoryItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [GlobalMemory].
extension GlobalMemoryPatterns on GlobalMemory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GlobalMemory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GlobalMemory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GlobalMemory value)  $default,){
final _that = this;
switch (_that) {
case _GlobalMemory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GlobalMemory value)?  $default,){
final _that = this;
switch (_that) {
case _GlobalMemory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<GlobalMemoryItem> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GlobalMemory() when $default != null:
return $default(_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<GlobalMemoryItem> items)  $default,) {final _that = this;
switch (_that) {
case _GlobalMemory():
return $default(_that.items);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<GlobalMemoryItem> items)?  $default,) {final _that = this;
switch (_that) {
case _GlobalMemory() when $default != null:
return $default(_that.items);case _:
  return null;

}
}

}

/// @nodoc


class _GlobalMemory extends GlobalMemory {
  const _GlobalMemory({ List<GlobalMemoryItem> items = const <GlobalMemoryItem>[]}): _items = items,super._();
  

 final  List<GlobalMemoryItem> _items;
@override@JsonKey() List<GlobalMemoryItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of GlobalMemory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GlobalMemoryCopyWith<_GlobalMemory> get copyWith => __$GlobalMemoryCopyWithImpl<_GlobalMemory>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GlobalMemory&&const DeepCollectionEquality().equals(other.items, _items));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_items));
}

@override
String toString() {
    return 'GlobalMemory(items: $items)';
}


}

/// @nodoc
abstract mixin class _$GlobalMemoryCopyWith<$Res> implements $GlobalMemoryCopyWith<$Res> {
  factory _$GlobalMemoryCopyWith(_GlobalMemory value, $Res Function(_GlobalMemory) _then) = __$GlobalMemoryCopyWithImpl;
@override @useResult
$Res call({
 List<GlobalMemoryItem> items
});




}
/// @nodoc
class __$GlobalMemoryCopyWithImpl<$Res>
    implements _$GlobalMemoryCopyWith<$Res> {
  __$GlobalMemoryCopyWithImpl(this._self, this._then);

  final _GlobalMemory _self;
  final $Res Function(_GlobalMemory) _then;

/// Create a copy of GlobalMemory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,}) {
  return _then(_GlobalMemory(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<GlobalMemoryItem>,
  ));
}


}

// dart format on
