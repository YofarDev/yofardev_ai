// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'llm_stream_chunk.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
LlmStreamChunk _$LlmStreamChunkFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'text':
          return _LlmStreamChunkText.fromJson(
            json
          );
                case 'error':
          return _LlmStreamChunkError.fromJson(
            json
          );
                case 'complete':
          return _LlmStreamChunkComplete.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'LlmStreamChunk',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$LlmStreamChunk {



  /// Serializes this LlmStreamChunk to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LlmStreamChunk);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LlmStreamChunk()';
}


}

/// @nodoc
class $LlmStreamChunkCopyWith<$Res>  {
$LlmStreamChunkCopyWith(LlmStreamChunk _, $Res Function(LlmStreamChunk) __);
}


/// Adds pattern-matching-related methods to [LlmStreamChunk].
extension LlmStreamChunkPatterns on LlmStreamChunk {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _LlmStreamChunkText value)?  text,TResult Function( _LlmStreamChunkError value)?  error,TResult Function( _LlmStreamChunkComplete value)?  complete,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LlmStreamChunkText() when text != null:
return text(_that);case _LlmStreamChunkError() when error != null:
return error(_that);case _LlmStreamChunkComplete() when complete != null:
return complete(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _LlmStreamChunkText value)  text,required TResult Function( _LlmStreamChunkError value)  error,required TResult Function( _LlmStreamChunkComplete value)  complete,}){
final _that = this;
switch (_that) {
case _LlmStreamChunkText():
return text(_that);case _LlmStreamChunkError():
return error(_that);case _LlmStreamChunkComplete():
return complete(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _LlmStreamChunkText value)?  text,TResult? Function( _LlmStreamChunkError value)?  error,TResult? Function( _LlmStreamChunkComplete value)?  complete,}){
final _that = this;
switch (_that) {
case _LlmStreamChunkText() when text != null:
return text(_that);case _LlmStreamChunkError() when error != null:
return error(_that);case _LlmStreamChunkComplete() when complete != null:
return complete(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String content,  bool isComplete)?  text,TResult Function( String message)?  error,TResult Function()?  complete,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LlmStreamChunkText() when text != null:
return text(_that.content,_that.isComplete);case _LlmStreamChunkError() when error != null:
return error(_that.message);case _LlmStreamChunkComplete() when complete != null:
return complete();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String content,  bool isComplete)  text,required TResult Function( String message)  error,required TResult Function()  complete,}) {final _that = this;
switch (_that) {
case _LlmStreamChunkText():
return text(_that.content,_that.isComplete);case _LlmStreamChunkError():
return error(_that.message);case _LlmStreamChunkComplete():
return complete();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String content,  bool isComplete)?  text,TResult? Function( String message)?  error,TResult? Function()?  complete,}) {final _that = this;
switch (_that) {
case _LlmStreamChunkText() when text != null:
return text(_that.content,_that.isComplete);case _LlmStreamChunkError() when error != null:
return error(_that.message);case _LlmStreamChunkComplete() when complete != null:
return complete();case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LlmStreamChunkText implements LlmStreamChunk {
  const _LlmStreamChunkText({required this.content, required this.isComplete, final  String? $type}): $type = $type ?? 'text';
  factory _LlmStreamChunkText.fromJson(Map<String, dynamic> json) => _$LlmStreamChunkTextFromJson(json);

 final  String content;
 final  bool isComplete;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of LlmStreamChunk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LlmStreamChunkTextCopyWith<_LlmStreamChunkText> get copyWith => __$LlmStreamChunkTextCopyWithImpl<_LlmStreamChunkText>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LlmStreamChunkTextToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LlmStreamChunkText&&(identical(other.content, content) || other.content == content)&&(identical(other.isComplete, isComplete) || other.isComplete == isComplete));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,content,isComplete);

@override
String toString() {
  return 'LlmStreamChunk.text(content: $content, isComplete: $isComplete)';
}


}

/// @nodoc
abstract mixin class _$LlmStreamChunkTextCopyWith<$Res> implements $LlmStreamChunkCopyWith<$Res> {
  factory _$LlmStreamChunkTextCopyWith(_LlmStreamChunkText value, $Res Function(_LlmStreamChunkText) _then) = __$LlmStreamChunkTextCopyWithImpl;
@useResult
$Res call({
 String content, bool isComplete
});




}
/// @nodoc
class __$LlmStreamChunkTextCopyWithImpl<$Res>
    implements _$LlmStreamChunkTextCopyWith<$Res> {
  __$LlmStreamChunkTextCopyWithImpl(this._self, this._then);

  final _LlmStreamChunkText _self;
  final $Res Function(_LlmStreamChunkText) _then;

/// Create a copy of LlmStreamChunk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? content = null,Object? isComplete = null,}) {
  return _then(_LlmStreamChunkText(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,isComplete: null == isComplete ? _self.isComplete : isComplete // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
@JsonSerializable()

class _LlmStreamChunkError implements LlmStreamChunk {
  const _LlmStreamChunkError(this.message, {final  String? $type}): $type = $type ?? 'error';
  factory _LlmStreamChunkError.fromJson(Map<String, dynamic> json) => _$LlmStreamChunkErrorFromJson(json);

 final  String message;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of LlmStreamChunk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LlmStreamChunkErrorCopyWith<_LlmStreamChunkError> get copyWith => __$LlmStreamChunkErrorCopyWithImpl<_LlmStreamChunkError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LlmStreamChunkErrorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LlmStreamChunkError&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'LlmStreamChunk.error(message: $message)';
}


}

/// @nodoc
abstract mixin class _$LlmStreamChunkErrorCopyWith<$Res> implements $LlmStreamChunkCopyWith<$Res> {
  factory _$LlmStreamChunkErrorCopyWith(_LlmStreamChunkError value, $Res Function(_LlmStreamChunkError) _then) = __$LlmStreamChunkErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class __$LlmStreamChunkErrorCopyWithImpl<$Res>
    implements _$LlmStreamChunkErrorCopyWith<$Res> {
  __$LlmStreamChunkErrorCopyWithImpl(this._self, this._then);

  final _LlmStreamChunkError _self;
  final $Res Function(_LlmStreamChunkError) _then;

/// Create a copy of LlmStreamChunk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(_LlmStreamChunkError(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class _LlmStreamChunkComplete implements LlmStreamChunk {
  const _LlmStreamChunkComplete({final  String? $type}): $type = $type ?? 'complete';
  factory _LlmStreamChunkComplete.fromJson(Map<String, dynamic> json) => _$LlmStreamChunkCompleteFromJson(json);



@JsonKey(name: 'runtimeType')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$LlmStreamChunkCompleteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LlmStreamChunkComplete);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LlmStreamChunk.complete()';
}


}




// dart format on
