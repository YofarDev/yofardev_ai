// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sound_effects.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SoundEffect _$SoundEffectFromJson(Map<String, dynamic> json) {
  return _SoundEffect.fromJson(json);
}

/// @nodoc
mixin _$SoundEffect {
  String get name => throw _privateConstructorUsedError;
  String get path => throw _privateConstructorUsedError;
  double get volume => throw _privateConstructorUsedError;

  /// Serializes this SoundEffect to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SoundEffect
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SoundEffectCopyWith<SoundEffect> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SoundEffectCopyWith<$Res> {
  factory $SoundEffectCopyWith(
    SoundEffect value,
    $Res Function(SoundEffect) then,
  ) = _$SoundEffectCopyWithImpl<$Res, SoundEffect>;
  @useResult
  $Res call({String name, String path, double volume});
}

/// @nodoc
class _$SoundEffectCopyWithImpl<$Res, $Val extends SoundEffect>
    implements $SoundEffectCopyWith<$Res> {
  _$SoundEffectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SoundEffect
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? name = null, Object? path = null, Object? volume = null}) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            path: null == path
                ? _value.path
                : path // ignore: cast_nullable_to_non_nullable
                      as String,
            volume: null == volume
                ? _value.volume
                : volume // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SoundEffectImplCopyWith<$Res>
    implements $SoundEffectCopyWith<$Res> {
  factory _$$SoundEffectImplCopyWith(
    _$SoundEffectImpl value,
    $Res Function(_$SoundEffectImpl) then,
  ) = __$$SoundEffectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, String path, double volume});
}

/// @nodoc
class __$$SoundEffectImplCopyWithImpl<$Res>
    extends _$SoundEffectCopyWithImpl<$Res, _$SoundEffectImpl>
    implements _$$SoundEffectImplCopyWith<$Res> {
  __$$SoundEffectImplCopyWithImpl(
    _$SoundEffectImpl _value,
    $Res Function(_$SoundEffectImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SoundEffect
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? name = null, Object? path = null, Object? volume = null}) {
    return _then(
      _$SoundEffectImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        path: null == path
            ? _value.path
            : path // ignore: cast_nullable_to_non_nullable
                  as String,
        volume: null == volume
            ? _value.volume
            : volume // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SoundEffectImpl implements _SoundEffect {
  const _$SoundEffectImpl({
    required this.name,
    required this.path,
    this.volume = 1.0,
  });

  factory _$SoundEffectImpl.fromJson(Map<String, dynamic> json) =>
      _$$SoundEffectImplFromJson(json);

  @override
  final String name;
  @override
  final String path;
  @override
  @JsonKey()
  final double volume;

  @override
  String toString() {
    return 'SoundEffect(name: $name, path: $path, volume: $volume)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SoundEffectImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.volume, volume) || other.volume == volume));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, path, volume);

  /// Create a copy of SoundEffect
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SoundEffectImplCopyWith<_$SoundEffectImpl> get copyWith =>
      __$$SoundEffectImplCopyWithImpl<_$SoundEffectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SoundEffectImplToJson(this);
  }
}

abstract class _SoundEffect implements SoundEffect {
  const factory _SoundEffect({
    required final String name,
    required final String path,
    final double volume,
  }) = _$SoundEffectImpl;

  factory _SoundEffect.fromJson(Map<String, dynamic> json) =
      _$SoundEffectImpl.fromJson;

  @override
  String get name;
  @override
  String get path;
  @override
  double get volume;

  /// Create a copy of SoundEffect
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SoundEffectImplCopyWith<_$SoundEffectImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
