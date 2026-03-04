// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sentence_chunk.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
SentenceChunk _$SentenceChunkFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'sentence':
          return _SentenceChunkSentence.fromJson(
            json
          );
                case 'metadata':
          return _SentenceChunkMetadata.fromJson(
            json
          );
                case 'complete':
          return _SentenceChunkComplete.fromJson(
            json
          );
                case 'error':
          return _SentenceChunkError.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'SentenceChunk',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$SentenceChunk {



  /// Serializes this SentenceChunk to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SentenceChunk);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SentenceChunk()';
}


}

/// @nodoc
class $SentenceChunkCopyWith<$Res>  {
$SentenceChunkCopyWith(SentenceChunk _, $Res Function(SentenceChunk) __);
}


/// Adds pattern-matching-related methods to [SentenceChunk].
extension SentenceChunkPatterns on SentenceChunk {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _SentenceChunkSentence value)?  sentence,TResult Function( _SentenceChunkMetadata value)?  metadata,TResult Function( _SentenceChunkComplete value)?  complete,TResult Function( _SentenceChunkError value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SentenceChunkSentence() when sentence != null:
return sentence(_that);case _SentenceChunkMetadata() when metadata != null:
return metadata(_that);case _SentenceChunkComplete() when complete != null:
return complete(_that);case _SentenceChunkError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _SentenceChunkSentence value)  sentence,required TResult Function( _SentenceChunkMetadata value)  metadata,required TResult Function( _SentenceChunkComplete value)  complete,required TResult Function( _SentenceChunkError value)  error,}){
final _that = this;
switch (_that) {
case _SentenceChunkSentence():
return sentence(_that);case _SentenceChunkMetadata():
return metadata(_that);case _SentenceChunkComplete():
return complete(_that);case _SentenceChunkError():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _SentenceChunkSentence value)?  sentence,TResult? Function( _SentenceChunkMetadata value)?  metadata,TResult? Function( _SentenceChunkComplete value)?  complete,TResult? Function( _SentenceChunkError value)?  error,}){
final _that = this;
switch (_that) {
case _SentenceChunkSentence() when sentence != null:
return sentence(_that);case _SentenceChunkMetadata() when metadata != null:
return metadata(_that);case _SentenceChunkComplete() when complete != null:
return complete(_that);case _SentenceChunkError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String text,  int index)?  sentence,TResult Function( Map<String, dynamic> json)?  metadata,TResult Function()?  complete,TResult Function( String message)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SentenceChunkSentence() when sentence != null:
return sentence(_that.text,_that.index);case _SentenceChunkMetadata() when metadata != null:
return metadata(_that.json);case _SentenceChunkComplete() when complete != null:
return complete();case _SentenceChunkError() when error != null:
return error(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String text,  int index)  sentence,required TResult Function( Map<String, dynamic> json)  metadata,required TResult Function()  complete,required TResult Function( String message)  error,}) {final _that = this;
switch (_that) {
case _SentenceChunkSentence():
return sentence(_that.text,_that.index);case _SentenceChunkMetadata():
return metadata(_that.json);case _SentenceChunkComplete():
return complete();case _SentenceChunkError():
return error(_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String text,  int index)?  sentence,TResult? Function( Map<String, dynamic> json)?  metadata,TResult? Function()?  complete,TResult? Function( String message)?  error,}) {final _that = this;
switch (_that) {
case _SentenceChunkSentence() when sentence != null:
return sentence(_that.text,_that.index);case _SentenceChunkMetadata() when metadata != null:
return metadata(_that.json);case _SentenceChunkComplete() when complete != null:
return complete();case _SentenceChunkError() when error != null:
return error(_that.message);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SentenceChunkSentence implements SentenceChunk {
  const _SentenceChunkSentence({required this.text, required this.index, final  String? $type}): $type = $type ?? 'sentence';
  factory _SentenceChunkSentence.fromJson(Map<String, dynamic> json) => _$SentenceChunkSentenceFromJson(json);

 final  String text;
 final  int index;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SentenceChunk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SentenceChunkSentenceCopyWith<_SentenceChunkSentence> get copyWith => __$SentenceChunkSentenceCopyWithImpl<_SentenceChunkSentence>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SentenceChunkSentenceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SentenceChunkSentence&&(identical(other.text, text) || other.text == text)&&(identical(other.index, index) || other.index == index));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,index);

@override
String toString() {
  return 'SentenceChunk.sentence(text: $text, index: $index)';
}


}

/// @nodoc
abstract mixin class _$SentenceChunkSentenceCopyWith<$Res> implements $SentenceChunkCopyWith<$Res> {
  factory _$SentenceChunkSentenceCopyWith(_SentenceChunkSentence value, $Res Function(_SentenceChunkSentence) _then) = __$SentenceChunkSentenceCopyWithImpl;
@useResult
$Res call({
 String text, int index
});




}
/// @nodoc
class __$SentenceChunkSentenceCopyWithImpl<$Res>
    implements _$SentenceChunkSentenceCopyWith<$Res> {
  __$SentenceChunkSentenceCopyWithImpl(this._self, this._then);

  final _SentenceChunkSentence _self;
  final $Res Function(_SentenceChunkSentence) _then;

/// Create a copy of SentenceChunk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,Object? index = null,}) {
  return _then(_SentenceChunkSentence(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
@JsonSerializable()

class _SentenceChunkMetadata implements SentenceChunk {
  const _SentenceChunkMetadata({required final  Map<String, dynamic> json, final  String? $type}): _json = json,$type = $type ?? 'metadata';
  factory _SentenceChunkMetadata.fromJson(Map<String, dynamic> json) => _$SentenceChunkMetadataFromJson(json);

 final  Map<String, dynamic> _json;
 Map<String, dynamic> get json {
  if (_json is EqualUnmodifiableMapView) return _json;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_json);
}


@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SentenceChunk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SentenceChunkMetadataCopyWith<_SentenceChunkMetadata> get copyWith => __$SentenceChunkMetadataCopyWithImpl<_SentenceChunkMetadata>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SentenceChunkMetadataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SentenceChunkMetadata&&const DeepCollectionEquality().equals(other._json, _json));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_json));

@override
String toString() {
  return 'SentenceChunk.metadata(json: $json)';
}


}

/// @nodoc
abstract mixin class _$SentenceChunkMetadataCopyWith<$Res> implements $SentenceChunkCopyWith<$Res> {
  factory _$SentenceChunkMetadataCopyWith(_SentenceChunkMetadata value, $Res Function(_SentenceChunkMetadata) _then) = __$SentenceChunkMetadataCopyWithImpl;
@useResult
$Res call({
 Map<String, dynamic> json
});




}
/// @nodoc
class __$SentenceChunkMetadataCopyWithImpl<$Res>
    implements _$SentenceChunkMetadataCopyWith<$Res> {
  __$SentenceChunkMetadataCopyWithImpl(this._self, this._then);

  final _SentenceChunkMetadata _self;
  final $Res Function(_SentenceChunkMetadata) _then;

/// Create a copy of SentenceChunk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? json = null,}) {
  return _then(_SentenceChunkMetadata(
json: null == json ? _self._json : json // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class _SentenceChunkComplete implements SentenceChunk {
  const _SentenceChunkComplete({final  String? $type}): $type = $type ?? 'complete';
  factory _SentenceChunkComplete.fromJson(Map<String, dynamic> json) => _$SentenceChunkCompleteFromJson(json);



@JsonKey(name: 'runtimeType')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SentenceChunkCompleteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SentenceChunkComplete);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SentenceChunk.complete()';
}


}




/// @nodoc
@JsonSerializable()

class _SentenceChunkError implements SentenceChunk {
  const _SentenceChunkError(this.message, {final  String? $type}): $type = $type ?? 'error';
  factory _SentenceChunkError.fromJson(Map<String, dynamic> json) => _$SentenceChunkErrorFromJson(json);

 final  String message;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SentenceChunk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SentenceChunkErrorCopyWith<_SentenceChunkError> get copyWith => __$SentenceChunkErrorCopyWithImpl<_SentenceChunkError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SentenceChunkErrorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SentenceChunkError&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'SentenceChunk.error(message: $message)';
}


}

/// @nodoc
abstract mixin class _$SentenceChunkErrorCopyWith<$Res> implements $SentenceChunkCopyWith<$Res> {
  factory _$SentenceChunkErrorCopyWith(_SentenceChunkError value, $Res Function(_SentenceChunkError) _then) = __$SentenceChunkErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class __$SentenceChunkErrorCopyWithImpl<$Res>
    implements _$SentenceChunkErrorCopyWith<$Res> {
  __$SentenceChunkErrorCopyWithImpl(this._self, this._then);

  final _SentenceChunkError _self;
  final $Res Function(_SentenceChunkError) _then;

/// Create a copy of SentenceChunk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(_SentenceChunkError(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
