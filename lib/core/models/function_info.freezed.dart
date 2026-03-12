// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'function_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FunctionInfo {

 String get name; String get description; List<Parameter> get parameters; FunctionCallback get function; Map<String, dynamic>? get parametersCalled;
/// Create a copy of FunctionInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FunctionInfoCopyWith<FunctionInfo> get copyWith => _$FunctionInfoCopyWithImpl<FunctionInfo>(this as FunctionInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FunctionInfo&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.parameters, parameters)&&(identical(other.function, function) || other.function == function)&&const DeepCollectionEquality().equals(other.parametersCalled, parametersCalled));
}


@override
int get hashCode => Object.hash(runtimeType,name,description,const DeepCollectionEquality().hash(parameters),function,const DeepCollectionEquality().hash(parametersCalled));

@override
String toString() {
  return 'FunctionInfo(name: $name, description: $description, parameters: $parameters, function: $function, parametersCalled: $parametersCalled)';
}


}

/// @nodoc
abstract mixin class $FunctionInfoCopyWith<$Res>  {
  factory $FunctionInfoCopyWith(FunctionInfo value, $Res Function(FunctionInfo) _then) = _$FunctionInfoCopyWithImpl;
@useResult
$Res call({
 String name, String description, List<Parameter> parameters, FunctionCallback function, Map<String, dynamic>? parametersCalled
});




}
/// @nodoc
class _$FunctionInfoCopyWithImpl<$Res>
    implements $FunctionInfoCopyWith<$Res> {
  _$FunctionInfoCopyWithImpl(this._self, this._then);

  final FunctionInfo _self;
  final $Res Function(FunctionInfo) _then;

/// Create a copy of FunctionInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = null,Object? parameters = null,Object? function = null,Object? parametersCalled = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,parameters: null == parameters ? _self.parameters : parameters // ignore: cast_nullable_to_non_nullable
as List<Parameter>,function: null == function ? _self.function : function // ignore: cast_nullable_to_non_nullable
as FunctionCallback,parametersCalled: freezed == parametersCalled ? _self.parametersCalled : parametersCalled // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

}


/// Adds pattern-matching-related methods to [FunctionInfo].
extension FunctionInfoPatterns on FunctionInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FunctionInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FunctionInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FunctionInfo value)  $default,){
final _that = this;
switch (_that) {
case _FunctionInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FunctionInfo value)?  $default,){
final _that = this;
switch (_that) {
case _FunctionInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String description,  List<Parameter> parameters,  FunctionCallback function,  Map<String, dynamic>? parametersCalled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FunctionInfo() when $default != null:
return $default(_that.name,_that.description,_that.parameters,_that.function,_that.parametersCalled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String description,  List<Parameter> parameters,  FunctionCallback function,  Map<String, dynamic>? parametersCalled)  $default,) {final _that = this;
switch (_that) {
case _FunctionInfo():
return $default(_that.name,_that.description,_that.parameters,_that.function,_that.parametersCalled);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String description,  List<Parameter> parameters,  FunctionCallback function,  Map<String, dynamic>? parametersCalled)?  $default,) {final _that = this;
switch (_that) {
case _FunctionInfo() when $default != null:
return $default(_that.name,_that.description,_that.parameters,_that.function,_that.parametersCalled);case _:
  return null;

}
}

}

/// @nodoc


class _FunctionInfo extends FunctionInfo {
  const _FunctionInfo({required this.name, required this.description, required final  List<Parameter> parameters, required this.function, final  Map<String, dynamic>? parametersCalled}): _parameters = parameters,_parametersCalled = parametersCalled,super._();
  

@override final  String name;
@override final  String description;
 final  List<Parameter> _parameters;
@override List<Parameter> get parameters {
  if (_parameters is EqualUnmodifiableListView) return _parameters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_parameters);
}

@override final  FunctionCallback function;
 final  Map<String, dynamic>? _parametersCalled;
@override Map<String, dynamic>? get parametersCalled {
  final value = _parametersCalled;
  if (value == null) return null;
  if (_parametersCalled is EqualUnmodifiableMapView) return _parametersCalled;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of FunctionInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FunctionInfoCopyWith<_FunctionInfo> get copyWith => __$FunctionInfoCopyWithImpl<_FunctionInfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FunctionInfo&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._parameters, _parameters)&&(identical(other.function, function) || other.function == function)&&const DeepCollectionEquality().equals(other._parametersCalled, _parametersCalled));
}


@override
int get hashCode => Object.hash(runtimeType,name,description,const DeepCollectionEquality().hash(_parameters),function,const DeepCollectionEquality().hash(_parametersCalled));

@override
String toString() {
  return 'FunctionInfo(name: $name, description: $description, parameters: $parameters, function: $function, parametersCalled: $parametersCalled)';
}


}

/// @nodoc
abstract mixin class _$FunctionInfoCopyWith<$Res> implements $FunctionInfoCopyWith<$Res> {
  factory _$FunctionInfoCopyWith(_FunctionInfo value, $Res Function(_FunctionInfo) _then) = __$FunctionInfoCopyWithImpl;
@override @useResult
$Res call({
 String name, String description, List<Parameter> parameters, FunctionCallback function, Map<String, dynamic>? parametersCalled
});




}
/// @nodoc
class __$FunctionInfoCopyWithImpl<$Res>
    implements _$FunctionInfoCopyWith<$Res> {
  __$FunctionInfoCopyWithImpl(this._self, this._then);

  final _FunctionInfo _self;
  final $Res Function(_FunctionInfo) _then;

/// Create a copy of FunctionInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = null,Object? parameters = null,Object? function = null,Object? parametersCalled = freezed,}) {
  return _then(_FunctionInfo(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,parameters: null == parameters ? _self._parameters : parameters // ignore: cast_nullable_to_non_nullable
as List<Parameter>,function: null == function ? _self.function : function // ignore: cast_nullable_to_non_nullable
as FunctionCallback,parametersCalled: freezed == parametersCalled ? _self._parametersCalled : parametersCalled // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}


}

/// @nodoc
mixin _$Parameter {

 String get name; String get description; String get type; bool get isRequired;
/// Create a copy of Parameter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParameterCopyWith<Parameter> get copyWith => _$ParameterCopyWithImpl<Parameter>(this as Parameter, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Parameter&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.type, type) || other.type == type)&&(identical(other.isRequired, isRequired) || other.isRequired == isRequired));
}


@override
int get hashCode => Object.hash(runtimeType,name,description,type,isRequired);

@override
String toString() {
  return 'Parameter(name: $name, description: $description, type: $type, isRequired: $isRequired)';
}


}

/// @nodoc
abstract mixin class $ParameterCopyWith<$Res>  {
  factory $ParameterCopyWith(Parameter value, $Res Function(Parameter) _then) = _$ParameterCopyWithImpl;
@useResult
$Res call({
 String name, String description, String type, bool isRequired
});




}
/// @nodoc
class _$ParameterCopyWithImpl<$Res>
    implements $ParameterCopyWith<$Res> {
  _$ParameterCopyWithImpl(this._self, this._then);

  final Parameter _self;
  final $Res Function(Parameter) _then;

/// Create a copy of Parameter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = null,Object? type = null,Object? isRequired = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,isRequired: null == isRequired ? _self.isRequired : isRequired // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Parameter].
extension ParameterPatterns on Parameter {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Parameter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Parameter() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Parameter value)  $default,){
final _that = this;
switch (_that) {
case _Parameter():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Parameter value)?  $default,){
final _that = this;
switch (_that) {
case _Parameter() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String description,  String type,  bool isRequired)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Parameter() when $default != null:
return $default(_that.name,_that.description,_that.type,_that.isRequired);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String description,  String type,  bool isRequired)  $default,) {final _that = this;
switch (_that) {
case _Parameter():
return $default(_that.name,_that.description,_that.type,_that.isRequired);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String description,  String type,  bool isRequired)?  $default,) {final _that = this;
switch (_that) {
case _Parameter() when $default != null:
return $default(_that.name,_that.description,_that.type,_that.isRequired);case _:
  return null;

}
}

}

/// @nodoc


class _Parameter extends Parameter {
  const _Parameter({required this.name, required this.description, required this.type, this.isRequired = true}): super._();
  

@override final  String name;
@override final  String description;
@override final  String type;
@override@JsonKey() final  bool isRequired;

/// Create a copy of Parameter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ParameterCopyWith<_Parameter> get copyWith => __$ParameterCopyWithImpl<_Parameter>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Parameter&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.type, type) || other.type == type)&&(identical(other.isRequired, isRequired) || other.isRequired == isRequired));
}


@override
int get hashCode => Object.hash(runtimeType,name,description,type,isRequired);

@override
String toString() {
  return 'Parameter(name: $name, description: $description, type: $type, isRequired: $isRequired)';
}


}

/// @nodoc
abstract mixin class _$ParameterCopyWith<$Res> implements $ParameterCopyWith<$Res> {
  factory _$ParameterCopyWith(_Parameter value, $Res Function(_Parameter) _then) = __$ParameterCopyWithImpl;
@override @useResult
$Res call({
 String name, String description, String type, bool isRequired
});




}
/// @nodoc
class __$ParameterCopyWithImpl<$Res>
    implements _$ParameterCopyWith<$Res> {
  __$ParameterCopyWithImpl(this._self, this._then);

  final _Parameter _self;
  final $Res Function(_Parameter) _then;

/// Create a copy of Parameter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = null,Object? type = null,Object? isRequired = null,}) {
  return _then(_Parameter(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,isRequired: null == isRequired ? _self.isRequired : isRequired // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
