// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tts_engine_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TtsEngineStatus {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TtsEngineStatus);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'TtsEngineStatus()';
}


}

/// @nodoc
class $TtsEngineStatusCopyWith<$Res>  {
$TtsEngineStatusCopyWith(TtsEngineStatus _, $Res Function(TtsEngineStatus) __);
}


/// Adds pattern-matching-related methods to [TtsEngineStatus].
extension TtsEngineStatusPatterns on TtsEngineStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TtsEngineNotInstalled value)?  notInstalled,TResult Function( TtsEngineDownloading value)?  downloading,TResult Function( TtsEngineExtracting value)?  extracting,TResult Function( TtsEngineLoading value)?  loading,TResult Function( TtsEngineReady value)?  ready,TResult Function( TtsEngineFailed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TtsEngineNotInstalled() when notInstalled != null:
return notInstalled(_that);case TtsEngineDownloading() when downloading != null:
return downloading(_that);case TtsEngineExtracting() when extracting != null:
return extracting(_that);case TtsEngineLoading() when loading != null:
return loading(_that);case TtsEngineReady() when ready != null:
return ready(_that);case TtsEngineFailed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TtsEngineNotInstalled value)  notInstalled,required TResult Function( TtsEngineDownloading value)  downloading,required TResult Function( TtsEngineExtracting value)  extracting,required TResult Function( TtsEngineLoading value)  loading,required TResult Function( TtsEngineReady value)  ready,required TResult Function( TtsEngineFailed value)  failed,}){
final _that = this;
switch (_that) {
case TtsEngineNotInstalled():
return notInstalled(_that);case TtsEngineDownloading():
return downloading(_that);case TtsEngineExtracting():
return extracting(_that);case TtsEngineLoading():
return loading(_that);case TtsEngineReady():
return ready(_that);case TtsEngineFailed():
return failed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TtsEngineNotInstalled value)?  notInstalled,TResult? Function( TtsEngineDownloading value)?  downloading,TResult? Function( TtsEngineExtracting value)?  extracting,TResult? Function( TtsEngineLoading value)?  loading,TResult? Function( TtsEngineReady value)?  ready,TResult? Function( TtsEngineFailed value)?  failed,}){
final _that = this;
switch (_that) {
case TtsEngineNotInstalled() when notInstalled != null:
return notInstalled(_that);case TtsEngineDownloading() when downloading != null:
return downloading(_that);case TtsEngineExtracting() when extracting != null:
return extracting(_that);case TtsEngineLoading() when loading != null:
return loading(_that);case TtsEngineReady() when ready != null:
return ready(_that);case TtsEngineFailed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  notInstalled,TResult Function( double? progress)?  downloading,TResult Function()?  extracting,TResult Function()?  loading,TResult Function()?  ready,TResult Function( Failure failure)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TtsEngineNotInstalled() when notInstalled != null:
return notInstalled();case TtsEngineDownloading() when downloading != null:
return downloading(_that.progress);case TtsEngineExtracting() when extracting != null:
return extracting();case TtsEngineLoading() when loading != null:
return loading();case TtsEngineReady() when ready != null:
return ready();case TtsEngineFailed() when failed != null:
return failed(_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  notInstalled,required TResult Function( double? progress)  downloading,required TResult Function()  extracting,required TResult Function()  loading,required TResult Function()  ready,required TResult Function( Failure failure)  failed,}) {final _that = this;
switch (_that) {
case TtsEngineNotInstalled():
return notInstalled();case TtsEngineDownloading():
return downloading(_that.progress);case TtsEngineExtracting():
return extracting();case TtsEngineLoading():
return loading();case TtsEngineReady():
return ready();case TtsEngineFailed():
return failed(_that.failure);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  notInstalled,TResult? Function( double? progress)?  downloading,TResult? Function()?  extracting,TResult? Function()?  loading,TResult? Function()?  ready,TResult? Function( Failure failure)?  failed,}) {final _that = this;
switch (_that) {
case TtsEngineNotInstalled() when notInstalled != null:
return notInstalled();case TtsEngineDownloading() when downloading != null:
return downloading(_that.progress);case TtsEngineExtracting() when extracting != null:
return extracting();case TtsEngineLoading() when loading != null:
return loading();case TtsEngineReady() when ready != null:
return ready();case TtsEngineFailed() when failed != null:
return failed(_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class TtsEngineNotInstalled implements TtsEngineStatus {
  const TtsEngineNotInstalled();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TtsEngineNotInstalled);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'TtsEngineStatus.notInstalled()';
}


}




/// @nodoc


class TtsEngineDownloading implements TtsEngineStatus {
  const TtsEngineDownloading(this.progress);
  

 final  double? progress;

/// Create a copy of TtsEngineStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TtsEngineDownloadingCopyWith<TtsEngineDownloading> get copyWith => _$TtsEngineDownloadingCopyWithImpl<TtsEngineDownloading>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TtsEngineDownloading&&(identical(other.progress, progress) || other.progress == progress));
}


@override
int get hashCode {
    return Object.hash(runtimeType,progress);
}

@override
String toString() {
    return 'TtsEngineStatus.downloading(progress: $progress)';
}


}

/// @nodoc
abstract mixin class $TtsEngineDownloadingCopyWith<$Res> implements $TtsEngineStatusCopyWith<$Res> {
  factory $TtsEngineDownloadingCopyWith(TtsEngineDownloading value, $Res Function(TtsEngineDownloading) _then) = _$TtsEngineDownloadingCopyWithImpl;
@useResult
$Res call({
 double? progress
});




}
/// @nodoc
class _$TtsEngineDownloadingCopyWithImpl<$Res>
    implements $TtsEngineDownloadingCopyWith<$Res> {
  _$TtsEngineDownloadingCopyWithImpl(this._self, this._then);

  final TtsEngineDownloading _self;
  final $Res Function(TtsEngineDownloading) _then;

/// Create a copy of TtsEngineStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? progress = freezed,}) {
  return _then(TtsEngineDownloading(
freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

/// @nodoc


class TtsEngineExtracting implements TtsEngineStatus {
  const TtsEngineExtracting();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TtsEngineExtracting);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'TtsEngineStatus.extracting()';
}


}




/// @nodoc


class TtsEngineLoading implements TtsEngineStatus {
  const TtsEngineLoading();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TtsEngineLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'TtsEngineStatus.loading()';
}


}




/// @nodoc


class TtsEngineReady implements TtsEngineStatus {
  const TtsEngineReady();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TtsEngineReady);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'TtsEngineStatus.ready()';
}


}




/// @nodoc


class TtsEngineFailed implements TtsEngineStatus {
  const TtsEngineFailed(this.failure);
  

 final  Failure failure;

/// Create a copy of TtsEngineStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TtsEngineFailedCopyWith<TtsEngineFailed> get copyWith => _$TtsEngineFailedCopyWithImpl<TtsEngineFailed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TtsEngineFailed&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,failure);
}

@override
String toString() {
    return 'TtsEngineStatus.failed(failure: $failure)';
}


}

/// @nodoc
abstract mixin class $TtsEngineFailedCopyWith<$Res> implements $TtsEngineStatusCopyWith<$Res> {
  factory $TtsEngineFailedCopyWith(TtsEngineFailed value, $Res Function(TtsEngineFailed) _then) = _$TtsEngineFailedCopyWithImpl;
@useResult
$Res call({
 Failure failure
});




}
/// @nodoc
class _$TtsEngineFailedCopyWithImpl<$Res>
    implements $TtsEngineFailedCopyWith<$Res> {
  _$TtsEngineFailedCopyWithImpl(this._self, this._then);

  final TtsEngineFailed _self;
  final $Res Function(TtsEngineFailed) _then;

/// Create a copy of TtsEngineStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = null,}) {
  return _then(TtsEngineFailed(
null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure,
  ));
}


}

// dart format on
