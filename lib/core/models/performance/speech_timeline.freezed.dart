// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'speech_timeline.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VisemeSpan {

 Viseme get viseme; Duration get start; Duration get end;/// 0-1, scales the jaw opening for this span.
 double get weight;
/// Create a copy of VisemeSpan
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VisemeSpanCopyWith<VisemeSpan> get copyWith => _$VisemeSpanCopyWithImpl<VisemeSpan>(this as VisemeSpan, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as VisemeSpan;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VisemeSpan&&(identical(other.viseme, _this.viseme) || other.viseme == _this.viseme)&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.end, _this.end) || other.end == _this.end)&&(identical(other.weight, _this.weight) || other.weight == _this.weight));
}


@override
int get hashCode {
  final _this = this as VisemeSpan;
  return Object.hash(runtimeType,_this.viseme,_this.start,_this.end,_this.weight);
}

@override
String toString() {
  final _this = this as VisemeSpan;
  return 'VisemeSpan(viseme: ${_this.viseme}, start: ${_this.start}, end: ${_this.end}, weight: ${_this.weight})';
}


}

/// @nodoc
abstract mixin class $VisemeSpanCopyWith<$Res>  {
  factory $VisemeSpanCopyWith(VisemeSpan value, $Res Function(VisemeSpan) _then) = _$VisemeSpanCopyWithImpl;
@useResult
$Res call({
 Viseme viseme, Duration start, Duration end, double weight
});




}
/// @nodoc
class _$VisemeSpanCopyWithImpl<$Res>
    implements $VisemeSpanCopyWith<$Res> {
  _$VisemeSpanCopyWithImpl(this._self, this._then);

  final VisemeSpan _self;
  final $Res Function(VisemeSpan) _then;

/// Create a copy of VisemeSpan
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? viseme = null,Object? start = null,Object? end = null,Object? weight = null,}) {
  return _then(VisemeSpan(
viseme: null == viseme ? _self.viseme : viseme // ignore: cast_nullable_to_non_nullable
as Viseme,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as Duration,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as Duration,weight: null == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [VisemeSpan].
extension VisemeSpanPatterns on VisemeSpan {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VisemeSpan value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VisemeSpan() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VisemeSpan value)  $default,){
final _that = this;
switch (_that) {
case _VisemeSpan():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VisemeSpan value)?  $default,){
final _that = this;
switch (_that) {
case _VisemeSpan() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Viseme viseme,  Duration start,  Duration end,  double weight)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VisemeSpan() when $default != null:
return $default(_that.viseme,_that.start,_that.end,_that.weight);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Viseme viseme,  Duration start,  Duration end,  double weight)  $default,) {final _that = this;
switch (_that) {
case _VisemeSpan():
return $default(_that.viseme,_that.start,_that.end,_that.weight);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Viseme viseme,  Duration start,  Duration end,  double weight)?  $default,) {final _that = this;
switch (_that) {
case _VisemeSpan() when $default != null:
return $default(_that.viseme,_that.start,_that.end,_that.weight);case _:
  return null;

}
}

}

/// @nodoc


class _VisemeSpan implements VisemeSpan {
  const _VisemeSpan({required this.viseme, required this.start, required this.end, this.weight = 1.0});
  

@override final  Viseme viseme;
@override final  Duration start;
@override final  Duration end;
/// 0-1, scales the jaw opening for this span.
@override@JsonKey() final  double weight;

/// Create a copy of VisemeSpan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VisemeSpanCopyWith<_VisemeSpan> get copyWith => __$VisemeSpanCopyWithImpl<_VisemeSpan>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VisemeSpan&&(identical(other.viseme, viseme) || other.viseme == viseme)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.weight, weight) || other.weight == weight));
}


@override
int get hashCode {
    return Object.hash(runtimeType,viseme,start,end,weight);
}

@override
String toString() {
    return 'VisemeSpan(viseme: $viseme, start: $start, end: $end, weight: $weight)';
}


}

/// @nodoc
abstract mixin class _$VisemeSpanCopyWith<$Res> implements $VisemeSpanCopyWith<$Res> {
  factory _$VisemeSpanCopyWith(_VisemeSpan value, $Res Function(_VisemeSpan) _then) = __$VisemeSpanCopyWithImpl;
@override @useResult
$Res call({
 Viseme viseme, Duration start, Duration end, double weight
});




}
/// @nodoc
class __$VisemeSpanCopyWithImpl<$Res>
    implements _$VisemeSpanCopyWith<$Res> {
  __$VisemeSpanCopyWithImpl(this._self, this._then);

  final _VisemeSpan _self;
  final $Res Function(_VisemeSpan) _then;

/// Create a copy of VisemeSpan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? viseme = null,Object? start = null,Object? end = null,Object? weight = null,}) {
  return _then(_VisemeSpan(
viseme: null == viseme ? _self.viseme : viseme // ignore: cast_nullable_to_non_nullable
as Viseme,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as Duration,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as Duration,weight: null == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$ProsodyMark {

 ProsodyMarkKind get kind; Duration get at; Duration get length; double get strength;/// Pitch peaks only: how steeply the voice rose into the peak, 0 (flat)
/// to 1 (a 60 % rise over the 200 ms before it); null when unknown (a
/// typical rise).
 double? get slope;
/// Create a copy of ProsodyMark
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProsodyMarkCopyWith<ProsodyMark> get copyWith => _$ProsodyMarkCopyWithImpl<ProsodyMark>(this as ProsodyMark, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ProsodyMark;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProsodyMark&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.at, _this.at) || other.at == _this.at)&&(identical(other.length, _this.length) || other.length == _this.length)&&(identical(other.strength, _this.strength) || other.strength == _this.strength)&&(identical(other.slope, _this.slope) || other.slope == _this.slope));
}


@override
int get hashCode {
  final _this = this as ProsodyMark;
  return Object.hash(runtimeType,_this.kind,_this.at,_this.length,_this.strength,_this.slope);
}

@override
String toString() {
  final _this = this as ProsodyMark;
  return 'ProsodyMark(kind: ${_this.kind}, at: ${_this.at}, length: ${_this.length}, strength: ${_this.strength}, slope: ${_this.slope})';
}


}

/// @nodoc
abstract mixin class $ProsodyMarkCopyWith<$Res>  {
  factory $ProsodyMarkCopyWith(ProsodyMark value, $Res Function(ProsodyMark) _then) = _$ProsodyMarkCopyWithImpl;
@useResult
$Res call({
 ProsodyMarkKind kind, Duration at, Duration length, double strength, double? slope
});




}
/// @nodoc
class _$ProsodyMarkCopyWithImpl<$Res>
    implements $ProsodyMarkCopyWith<$Res> {
  _$ProsodyMarkCopyWithImpl(this._self, this._then);

  final ProsodyMark _self;
  final $Res Function(ProsodyMark) _then;

/// Create a copy of ProsodyMark
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? at = null,Object? length = null,Object? strength = null,Object? slope = freezed,}) {
  return _then(ProsodyMark(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ProsodyMarkKind,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as Duration,length: null == length ? _self.length : length // ignore: cast_nullable_to_non_nullable
as Duration,strength: null == strength ? _self.strength : strength // ignore: cast_nullable_to_non_nullable
as double,slope: freezed == slope ? _self.slope : slope // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProsodyMark].
extension ProsodyMarkPatterns on ProsodyMark {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProsodyMark value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProsodyMark() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProsodyMark value)  $default,){
final _that = this;
switch (_that) {
case _ProsodyMark():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProsodyMark value)?  $default,){
final _that = this;
switch (_that) {
case _ProsodyMark() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProsodyMarkKind kind,  Duration at,  Duration length,  double strength,  double? slope)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProsodyMark() when $default != null:
return $default(_that.kind,_that.at,_that.length,_that.strength,_that.slope);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProsodyMarkKind kind,  Duration at,  Duration length,  double strength,  double? slope)  $default,) {final _that = this;
switch (_that) {
case _ProsodyMark():
return $default(_that.kind,_that.at,_that.length,_that.strength,_that.slope);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProsodyMarkKind kind,  Duration at,  Duration length,  double strength,  double? slope)?  $default,) {final _that = this;
switch (_that) {
case _ProsodyMark() when $default != null:
return $default(_that.kind,_that.at,_that.length,_that.strength,_that.slope);case _:
  return null;

}
}

}

/// @nodoc


class _ProsodyMark implements ProsodyMark {
  const _ProsodyMark({required this.kind, required this.at, this.length = Duration.zero, this.strength = 1.0, this.slope});
  

@override final  ProsodyMarkKind kind;
@override final  Duration at;
@override@JsonKey() final  Duration length;
@override@JsonKey() final  double strength;
/// Pitch peaks only: how steeply the voice rose into the peak, 0 (flat)
/// to 1 (a 60 % rise over the 200 ms before it); null when unknown (a
/// typical rise).
@override final  double? slope;

/// Create a copy of ProsodyMark
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProsodyMarkCopyWith<_ProsodyMark> get copyWith => __$ProsodyMarkCopyWithImpl<_ProsodyMark>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProsodyMark&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.at, at) || other.at == at)&&(identical(other.length, length) || other.length == length)&&(identical(other.strength, strength) || other.strength == strength)&&(identical(other.slope, slope) || other.slope == slope));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind,at,length,strength,slope);
}

@override
String toString() {
    return 'ProsodyMark(kind: $kind, at: $at, length: $length, strength: $strength, slope: $slope)';
}


}

/// @nodoc
abstract mixin class _$ProsodyMarkCopyWith<$Res> implements $ProsodyMarkCopyWith<$Res> {
  factory _$ProsodyMarkCopyWith(_ProsodyMark value, $Res Function(_ProsodyMark) _then) = __$ProsodyMarkCopyWithImpl;
@override @useResult
$Res call({
 ProsodyMarkKind kind, Duration at, Duration length, double strength, double? slope
});




}
/// @nodoc
class __$ProsodyMarkCopyWithImpl<$Res>
    implements _$ProsodyMarkCopyWith<$Res> {
  __$ProsodyMarkCopyWithImpl(this._self, this._then);

  final _ProsodyMark _self;
  final $Res Function(_ProsodyMark) _then;

/// Create a copy of ProsodyMark
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? at = null,Object? length = null,Object? strength = null,Object? slope = freezed,}) {
  return _then(_ProsodyMark(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ProsodyMarkKind,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as Duration,length: null == length ? _self.length : length // ignore: cast_nullable_to_non_nullable
as Duration,strength: null == strength ? _self.strength : strength // ignore: cast_nullable_to_non_nullable
as double,slope: freezed == slope ? _self.slope : slope // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

/// @nodoc
mixin _$SpeechTimeline {

 List<VisemeSpan> get visemes; List<ProsodyMark> get marks; Duration get duration; Duration get leadingSilence; bool get isQuestion;/// The sh/zh sounds (`ch` spans) are strongly rounded, as in French
/// (/ʃ/, /ʒ/: "chat", "jour"), not spread and rounded at once.
 bool get roundedSh;/// Loudness per [energyFrame] (0-1, relative to the sentence's loud
/// frames): the jaw follows it inside long vowels. Empty when unknown.
 List<double> get energy; Duration get energyFrame;
/// Create a copy of SpeechTimeline
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpeechTimelineCopyWith<SpeechTimeline> get copyWith => _$SpeechTimelineCopyWithImpl<SpeechTimeline>(this as SpeechTimeline, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SpeechTimeline;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpeechTimeline&&const DeepCollectionEquality().equals(other.visemes, _this.visemes)&&const DeepCollectionEquality().equals(other.marks, _this.marks)&&(identical(other.duration, _this.duration) || other.duration == _this.duration)&&(identical(other.leadingSilence, _this.leadingSilence) || other.leadingSilence == _this.leadingSilence)&&(identical(other.isQuestion, _this.isQuestion) || other.isQuestion == _this.isQuestion)&&(identical(other.roundedSh, _this.roundedSh) || other.roundedSh == _this.roundedSh)&&const DeepCollectionEquality().equals(other.energy, _this.energy)&&(identical(other.energyFrame, _this.energyFrame) || other.energyFrame == _this.energyFrame));
}


@override
int get hashCode {
  final _this = this as SpeechTimeline;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.visemes),const DeepCollectionEquality().hash(_this.marks),_this.duration,_this.leadingSilence,_this.isQuestion,_this.roundedSh,const DeepCollectionEquality().hash(_this.energy),_this.energyFrame);
}

@override
String toString() {
  final _this = this as SpeechTimeline;
  return 'SpeechTimeline(visemes: ${_this.visemes}, marks: ${_this.marks}, duration: ${_this.duration}, leadingSilence: ${_this.leadingSilence}, isQuestion: ${_this.isQuestion}, roundedSh: ${_this.roundedSh}, energy: ${_this.energy}, energyFrame: ${_this.energyFrame})';
}


}

/// @nodoc
abstract mixin class $SpeechTimelineCopyWith<$Res>  {
  factory $SpeechTimelineCopyWith(SpeechTimeline value, $Res Function(SpeechTimeline) _then) = _$SpeechTimelineCopyWithImpl;
@useResult
$Res call({
 List<VisemeSpan> visemes, List<ProsodyMark> marks, Duration duration, Duration leadingSilence, bool isQuestion, bool roundedSh, List<double> energy, Duration energyFrame
});




}
/// @nodoc
class _$SpeechTimelineCopyWithImpl<$Res>
    implements $SpeechTimelineCopyWith<$Res> {
  _$SpeechTimelineCopyWithImpl(this._self, this._then);

  final SpeechTimeline _self;
  final $Res Function(SpeechTimeline) _then;

/// Create a copy of SpeechTimeline
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? visemes = null,Object? marks = null,Object? duration = null,Object? leadingSilence = null,Object? isQuestion = null,Object? roundedSh = null,Object? energy = null,Object? energyFrame = null,}) {
  return _then(SpeechTimeline(
visemes: null == visemes ? _self.visemes : visemes // ignore: cast_nullable_to_non_nullable
as List<VisemeSpan>,marks: null == marks ? _self.marks : marks // ignore: cast_nullable_to_non_nullable
as List<ProsodyMark>,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,leadingSilence: null == leadingSilence ? _self.leadingSilence : leadingSilence // ignore: cast_nullable_to_non_nullable
as Duration,isQuestion: null == isQuestion ? _self.isQuestion : isQuestion // ignore: cast_nullable_to_non_nullable
as bool,roundedSh: null == roundedSh ? _self.roundedSh : roundedSh // ignore: cast_nullable_to_non_nullable
as bool,energy: null == energy ? _self.energy : energy // ignore: cast_nullable_to_non_nullable
as List<double>,energyFrame: null == energyFrame ? _self.energyFrame : energyFrame // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}

}


/// Adds pattern-matching-related methods to [SpeechTimeline].
extension SpeechTimelinePatterns on SpeechTimeline {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpeechTimeline value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpeechTimeline() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpeechTimeline value)  $default,){
final _that = this;
switch (_that) {
case _SpeechTimeline():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpeechTimeline value)?  $default,){
final _that = this;
switch (_that) {
case _SpeechTimeline() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<VisemeSpan> visemes,  List<ProsodyMark> marks,  Duration duration,  Duration leadingSilence,  bool isQuestion,  bool roundedSh,  List<double> energy,  Duration energyFrame)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpeechTimeline() when $default != null:
return $default(_that.visemes,_that.marks,_that.duration,_that.leadingSilence,_that.isQuestion,_that.roundedSh,_that.energy,_that.energyFrame);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<VisemeSpan> visemes,  List<ProsodyMark> marks,  Duration duration,  Duration leadingSilence,  bool isQuestion,  bool roundedSh,  List<double> energy,  Duration energyFrame)  $default,) {final _that = this;
switch (_that) {
case _SpeechTimeline():
return $default(_that.visemes,_that.marks,_that.duration,_that.leadingSilence,_that.isQuestion,_that.roundedSh,_that.energy,_that.energyFrame);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<VisemeSpan> visemes,  List<ProsodyMark> marks,  Duration duration,  Duration leadingSilence,  bool isQuestion,  bool roundedSh,  List<double> energy,  Duration energyFrame)?  $default,) {final _that = this;
switch (_that) {
case _SpeechTimeline() when $default != null:
return $default(_that.visemes,_that.marks,_that.duration,_that.leadingSilence,_that.isQuestion,_that.roundedSh,_that.energy,_that.energyFrame);case _:
  return null;

}
}

}

/// @nodoc


class _SpeechTimeline extends SpeechTimeline {
  const _SpeechTimeline({ List<VisemeSpan> visemes = const <VisemeSpan>[],  List<ProsodyMark> marks = const <ProsodyMark>[], this.duration = Duration.zero, this.leadingSilence = Duration.zero, this.isQuestion = false, this.roundedSh = false,  List<double> energy = const <double>[], this.energyFrame = const Duration(milliseconds: 25)}): _visemes = visemes,_marks = marks,_energy = energy,super._();
  

 final  List<VisemeSpan> _visemes;
@override@JsonKey() List<VisemeSpan> get visemes {
  if (_visemes is EqualUnmodifiableListView) return _visemes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_visemes);
}

 final  List<ProsodyMark> _marks;
@override@JsonKey() List<ProsodyMark> get marks {
  if (_marks is EqualUnmodifiableListView) return _marks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_marks);
}

@override@JsonKey() final  Duration duration;
@override@JsonKey() final  Duration leadingSilence;
@override@JsonKey() final  bool isQuestion;
/// The sh/zh sounds (`ch` spans) are strongly rounded, as in French
/// (/ʃ/, /ʒ/: "chat", "jour"), not spread and rounded at once.
@override@JsonKey() final  bool roundedSh;
/// Loudness per [energyFrame] (0-1, relative to the sentence's loud
/// frames): the jaw follows it inside long vowels. Empty when unknown.
 final  List<double> _energy;
/// Loudness per [energyFrame] (0-1, relative to the sentence's loud
/// frames): the jaw follows it inside long vowels. Empty when unknown.
@override@JsonKey() List<double> get energy {
  if (_energy is EqualUnmodifiableListView) return _energy;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_energy);
}

@override@JsonKey() final  Duration energyFrame;

/// Create a copy of SpeechTimeline
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpeechTimelineCopyWith<_SpeechTimeline> get copyWith => __$SpeechTimelineCopyWithImpl<_SpeechTimeline>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpeechTimeline&&const DeepCollectionEquality().equals(other.visemes, _visemes)&&const DeepCollectionEquality().equals(other.marks, _marks)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.leadingSilence, leadingSilence) || other.leadingSilence == leadingSilence)&&(identical(other.isQuestion, isQuestion) || other.isQuestion == isQuestion)&&(identical(other.roundedSh, roundedSh) || other.roundedSh == roundedSh)&&const DeepCollectionEquality().equals(other.energy, _energy)&&(identical(other.energyFrame, energyFrame) || other.energyFrame == energyFrame));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_visemes),const DeepCollectionEquality().hash(_marks),duration,leadingSilence,isQuestion,roundedSh,const DeepCollectionEquality().hash(_energy),energyFrame);
}

@override
String toString() {
    return 'SpeechTimeline(visemes: $visemes, marks: $marks, duration: $duration, leadingSilence: $leadingSilence, isQuestion: $isQuestion, roundedSh: $roundedSh, energy: $energy, energyFrame: $energyFrame)';
}


}

/// @nodoc
abstract mixin class _$SpeechTimelineCopyWith<$Res> implements $SpeechTimelineCopyWith<$Res> {
  factory _$SpeechTimelineCopyWith(_SpeechTimeline value, $Res Function(_SpeechTimeline) _then) = __$SpeechTimelineCopyWithImpl;
@override @useResult
$Res call({
 List<VisemeSpan> visemes, List<ProsodyMark> marks, Duration duration, Duration leadingSilence, bool isQuestion, bool roundedSh, List<double> energy, Duration energyFrame
});




}
/// @nodoc
class __$SpeechTimelineCopyWithImpl<$Res>
    implements _$SpeechTimelineCopyWith<$Res> {
  __$SpeechTimelineCopyWithImpl(this._self, this._then);

  final _SpeechTimeline _self;
  final $Res Function(_SpeechTimeline) _then;

/// Create a copy of SpeechTimeline
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? visemes = null,Object? marks = null,Object? duration = null,Object? leadingSilence = null,Object? isQuestion = null,Object? roundedSh = null,Object? energy = null,Object? energyFrame = null,}) {
  return _then(_SpeechTimeline(
visemes: null == visemes ? _self._visemes : visemes // ignore: cast_nullable_to_non_nullable
as List<VisemeSpan>,marks: null == marks ? _self._marks : marks // ignore: cast_nullable_to_non_nullable
as List<ProsodyMark>,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,leadingSilence: null == leadingSilence ? _self.leadingSilence : leadingSilence // ignore: cast_nullable_to_non_nullable
as Duration,isQuestion: null == isQuestion ? _self.isQuestion : isQuestion // ignore: cast_nullable_to_non_nullable
as bool,roundedSh: null == roundedSh ? _self.roundedSh : roundedSh // ignore: cast_nullable_to_non_nullable
as bool,energy: null == energy ? _self._energy : energy // ignore: cast_nullable_to_non_nullable
as List<double>,energyFrame: null == energyFrame ? _self.energyFrame : energyFrame // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}


}

// dart format on
