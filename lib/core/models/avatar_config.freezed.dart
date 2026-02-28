// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'avatar_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Avatar _$AvatarFromJson(Map<String, dynamic> json) {
  return _Avatar.fromJson(json);
}

/// @nodoc
mixin _$Avatar {
  AvatarBackgrounds get background => throw _privateConstructorUsedError;
  AvatarHat get hat => throw _privateConstructorUsedError;
  AvatarTop get top => throw _privateConstructorUsedError;
  AvatarGlasses get glasses => throw _privateConstructorUsedError;
  AvatarSpecials get specials => throw _privateConstructorUsedError;
  AvatarCostume get costume => throw _privateConstructorUsedError;

  /// Serializes this Avatar to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Avatar
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AvatarCopyWith<Avatar> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AvatarCopyWith<$Res> {
  factory $AvatarCopyWith(Avatar value, $Res Function(Avatar) then) =
      _$AvatarCopyWithImpl<$Res, Avatar>;
  @useResult
  $Res call({
    AvatarBackgrounds background,
    AvatarHat hat,
    AvatarTop top,
    AvatarGlasses glasses,
    AvatarSpecials specials,
    AvatarCostume costume,
  });
}

/// @nodoc
class _$AvatarCopyWithImpl<$Res, $Val extends Avatar>
    implements $AvatarCopyWith<$Res> {
  _$AvatarCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Avatar
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? background = null,
    Object? hat = null,
    Object? top = null,
    Object? glasses = null,
    Object? specials = null,
    Object? costume = null,
  }) {
    return _then(
      _value.copyWith(
            background: null == background
                ? _value.background
                : background // ignore: cast_nullable_to_non_nullable
                      as AvatarBackgrounds,
            hat: null == hat
                ? _value.hat
                : hat // ignore: cast_nullable_to_non_nullable
                      as AvatarHat,
            top: null == top
                ? _value.top
                : top // ignore: cast_nullable_to_non_nullable
                      as AvatarTop,
            glasses: null == glasses
                ? _value.glasses
                : glasses // ignore: cast_nullable_to_non_nullable
                      as AvatarGlasses,
            specials: null == specials
                ? _value.specials
                : specials // ignore: cast_nullable_to_non_nullable
                      as AvatarSpecials,
            costume: null == costume
                ? _value.costume
                : costume // ignore: cast_nullable_to_non_nullable
                      as AvatarCostume,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AvatarImplCopyWith<$Res> implements $AvatarCopyWith<$Res> {
  factory _$$AvatarImplCopyWith(
    _$AvatarImpl value,
    $Res Function(_$AvatarImpl) then,
  ) = __$$AvatarImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    AvatarBackgrounds background,
    AvatarHat hat,
    AvatarTop top,
    AvatarGlasses glasses,
    AvatarSpecials specials,
    AvatarCostume costume,
  });
}

/// @nodoc
class __$$AvatarImplCopyWithImpl<$Res>
    extends _$AvatarCopyWithImpl<$Res, _$AvatarImpl>
    implements _$$AvatarImplCopyWith<$Res> {
  __$$AvatarImplCopyWithImpl(
    _$AvatarImpl _value,
    $Res Function(_$AvatarImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Avatar
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? background = null,
    Object? hat = null,
    Object? top = null,
    Object? glasses = null,
    Object? specials = null,
    Object? costume = null,
  }) {
    return _then(
      _$AvatarImpl(
        background: null == background
            ? _value.background
            : background // ignore: cast_nullable_to_non_nullable
                  as AvatarBackgrounds,
        hat: null == hat
            ? _value.hat
            : hat // ignore: cast_nullable_to_non_nullable
                  as AvatarHat,
        top: null == top
            ? _value.top
            : top // ignore: cast_nullable_to_non_nullable
                  as AvatarTop,
        glasses: null == glasses
            ? _value.glasses
            : glasses // ignore: cast_nullable_to_non_nullable
                  as AvatarGlasses,
        specials: null == specials
            ? _value.specials
            : specials // ignore: cast_nullable_to_non_nullable
                  as AvatarSpecials,
        costume: null == costume
            ? _value.costume
            : costume // ignore: cast_nullable_to_non_nullable
                  as AvatarCostume,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AvatarImpl extends _Avatar {
  const _$AvatarImpl({
    this.background = AvatarBackgrounds.lake,
    this.hat = AvatarHat.noHat,
    this.top = AvatarTop.pinkHoodie,
    this.glasses = AvatarGlasses.glasses,
    this.specials = AvatarSpecials.onScreen,
    this.costume = AvatarCostume.none,
  }) : super._();

  factory _$AvatarImpl.fromJson(Map<String, dynamic> json) =>
      _$$AvatarImplFromJson(json);

  @override
  @JsonKey()
  final AvatarBackgrounds background;
  @override
  @JsonKey()
  final AvatarHat hat;
  @override
  @JsonKey()
  final AvatarTop top;
  @override
  @JsonKey()
  final AvatarGlasses glasses;
  @override
  @JsonKey()
  final AvatarSpecials specials;
  @override
  @JsonKey()
  final AvatarCostume costume;

  @override
  String toString() {
    return 'Avatar(background: $background, hat: $hat, top: $top, glasses: $glasses, specials: $specials, costume: $costume)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AvatarImpl &&
            (identical(other.background, background) ||
                other.background == background) &&
            (identical(other.hat, hat) || other.hat == hat) &&
            (identical(other.top, top) || other.top == top) &&
            (identical(other.glasses, glasses) || other.glasses == glasses) &&
            (identical(other.specials, specials) ||
                other.specials == specials) &&
            (identical(other.costume, costume) || other.costume == costume));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    background,
    hat,
    top,
    glasses,
    specials,
    costume,
  );

  /// Create a copy of Avatar
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AvatarImplCopyWith<_$AvatarImpl> get copyWith =>
      __$$AvatarImplCopyWithImpl<_$AvatarImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AvatarImplToJson(this);
  }
}

abstract class _Avatar extends Avatar {
  const factory _Avatar({
    final AvatarBackgrounds background,
    final AvatarHat hat,
    final AvatarTop top,
    final AvatarGlasses glasses,
    final AvatarSpecials specials,
    final AvatarCostume costume,
  }) = _$AvatarImpl;
  const _Avatar._() : super._();

  factory _Avatar.fromJson(Map<String, dynamic> json) = _$AvatarImpl.fromJson;

  @override
  AvatarBackgrounds get background;
  @override
  AvatarHat get hat;
  @override
  AvatarTop get top;
  @override
  AvatarGlasses get glasses;
  @override
  AvatarSpecials get specials;
  @override
  AvatarCostume get costume;

  /// Create a copy of Avatar
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AvatarImplCopyWith<_$AvatarImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AvatarConfig _$AvatarConfigFromJson(Map<String, dynamic> json) {
  return _AvatarConfig.fromJson(json);
}

/// @nodoc
mixin _$AvatarConfig {
  AvatarBackgrounds? get background => throw _privateConstructorUsedError;
  AvatarHat? get hat => throw _privateConstructorUsedError;
  AvatarTop? get top => throw _privateConstructorUsedError;
  AvatarGlasses? get glasses => throw _privateConstructorUsedError;
  AvatarSpecials? get specials => throw _privateConstructorUsedError;
  AvatarCostume? get costume => throw _privateConstructorUsedError;
  @SoundEffectConverter()
  SoundEffects? get soundEffect => throw _privateConstructorUsedError;

  /// Serializes this AvatarConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AvatarConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AvatarConfigCopyWith<AvatarConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AvatarConfigCopyWith<$Res> {
  factory $AvatarConfigCopyWith(
    AvatarConfig value,
    $Res Function(AvatarConfig) then,
  ) = _$AvatarConfigCopyWithImpl<$Res, AvatarConfig>;
  @useResult
  $Res call({
    AvatarBackgrounds? background,
    AvatarHat? hat,
    AvatarTop? top,
    AvatarGlasses? glasses,
    AvatarSpecials? specials,
    AvatarCostume? costume,
    @SoundEffectConverter() SoundEffects? soundEffect,
  });
}

/// @nodoc
class _$AvatarConfigCopyWithImpl<$Res, $Val extends AvatarConfig>
    implements $AvatarConfigCopyWith<$Res> {
  _$AvatarConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AvatarConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? background = freezed,
    Object? hat = freezed,
    Object? top = freezed,
    Object? glasses = freezed,
    Object? specials = freezed,
    Object? costume = freezed,
    Object? soundEffect = freezed,
  }) {
    return _then(
      _value.copyWith(
            background: freezed == background
                ? _value.background
                : background // ignore: cast_nullable_to_non_nullable
                      as AvatarBackgrounds?,
            hat: freezed == hat
                ? _value.hat
                : hat // ignore: cast_nullable_to_non_nullable
                      as AvatarHat?,
            top: freezed == top
                ? _value.top
                : top // ignore: cast_nullable_to_non_nullable
                      as AvatarTop?,
            glasses: freezed == glasses
                ? _value.glasses
                : glasses // ignore: cast_nullable_to_non_nullable
                      as AvatarGlasses?,
            specials: freezed == specials
                ? _value.specials
                : specials // ignore: cast_nullable_to_non_nullable
                      as AvatarSpecials?,
            costume: freezed == costume
                ? _value.costume
                : costume // ignore: cast_nullable_to_non_nullable
                      as AvatarCostume?,
            soundEffect: freezed == soundEffect
                ? _value.soundEffect
                : soundEffect // ignore: cast_nullable_to_non_nullable
                      as SoundEffects?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AvatarConfigImplCopyWith<$Res>
    implements $AvatarConfigCopyWith<$Res> {
  factory _$$AvatarConfigImplCopyWith(
    _$AvatarConfigImpl value,
    $Res Function(_$AvatarConfigImpl) then,
  ) = __$$AvatarConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    AvatarBackgrounds? background,
    AvatarHat? hat,
    AvatarTop? top,
    AvatarGlasses? glasses,
    AvatarSpecials? specials,
    AvatarCostume? costume,
    @SoundEffectConverter() SoundEffects? soundEffect,
  });
}

/// @nodoc
class __$$AvatarConfigImplCopyWithImpl<$Res>
    extends _$AvatarConfigCopyWithImpl<$Res, _$AvatarConfigImpl>
    implements _$$AvatarConfigImplCopyWith<$Res> {
  __$$AvatarConfigImplCopyWithImpl(
    _$AvatarConfigImpl _value,
    $Res Function(_$AvatarConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AvatarConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? background = freezed,
    Object? hat = freezed,
    Object? top = freezed,
    Object? glasses = freezed,
    Object? specials = freezed,
    Object? costume = freezed,
    Object? soundEffect = freezed,
  }) {
    return _then(
      _$AvatarConfigImpl(
        background: freezed == background
            ? _value.background
            : background // ignore: cast_nullable_to_non_nullable
                  as AvatarBackgrounds?,
        hat: freezed == hat
            ? _value.hat
            : hat // ignore: cast_nullable_to_non_nullable
                  as AvatarHat?,
        top: freezed == top
            ? _value.top
            : top // ignore: cast_nullable_to_non_nullable
                  as AvatarTop?,
        glasses: freezed == glasses
            ? _value.glasses
            : glasses // ignore: cast_nullable_to_non_nullable
                  as AvatarGlasses?,
        specials: freezed == specials
            ? _value.specials
            : specials // ignore: cast_nullable_to_non_nullable
                  as AvatarSpecials?,
        costume: freezed == costume
            ? _value.costume
            : costume // ignore: cast_nullable_to_non_nullable
                  as AvatarCostume?,
        soundEffect: freezed == soundEffect
            ? _value.soundEffect
            : soundEffect // ignore: cast_nullable_to_non_nullable
                  as SoundEffects?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AvatarConfigImpl extends _AvatarConfig {
  const _$AvatarConfigImpl({
    this.background,
    this.hat,
    this.top,
    this.glasses,
    this.specials,
    this.costume,
    @SoundEffectConverter() this.soundEffect,
  }) : super._();

  factory _$AvatarConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$AvatarConfigImplFromJson(json);

  @override
  final AvatarBackgrounds? background;
  @override
  final AvatarHat? hat;
  @override
  final AvatarTop? top;
  @override
  final AvatarGlasses? glasses;
  @override
  final AvatarSpecials? specials;
  @override
  final AvatarCostume? costume;
  @override
  @SoundEffectConverter()
  final SoundEffects? soundEffect;

  @override
  String toString() {
    return 'AvatarConfig(background: $background, hat: $hat, top: $top, glasses: $glasses, specials: $specials, costume: $costume, soundEffect: $soundEffect)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AvatarConfigImpl &&
            (identical(other.background, background) ||
                other.background == background) &&
            (identical(other.hat, hat) || other.hat == hat) &&
            (identical(other.top, top) || other.top == top) &&
            (identical(other.glasses, glasses) || other.glasses == glasses) &&
            (identical(other.specials, specials) ||
                other.specials == specials) &&
            (identical(other.costume, costume) || other.costume == costume) &&
            (identical(other.soundEffect, soundEffect) ||
                other.soundEffect == soundEffect));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    background,
    hat,
    top,
    glasses,
    specials,
    costume,
    soundEffect,
  );

  /// Create a copy of AvatarConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AvatarConfigImplCopyWith<_$AvatarConfigImpl> get copyWith =>
      __$$AvatarConfigImplCopyWithImpl<_$AvatarConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AvatarConfigImplToJson(this);
  }
}

abstract class _AvatarConfig extends AvatarConfig {
  const factory _AvatarConfig({
    final AvatarBackgrounds? background,
    final AvatarHat? hat,
    final AvatarTop? top,
    final AvatarGlasses? glasses,
    final AvatarSpecials? specials,
    final AvatarCostume? costume,
    @SoundEffectConverter() final SoundEffects? soundEffect,
  }) = _$AvatarConfigImpl;
  const _AvatarConfig._() : super._();

  factory _AvatarConfig.fromJson(Map<String, dynamic> json) =
      _$AvatarConfigImpl.fromJson;

  @override
  AvatarBackgrounds? get background;
  @override
  AvatarHat? get hat;
  @override
  AvatarTop? get top;
  @override
  AvatarGlasses? get glasses;
  @override
  AvatarSpecials? get specials;
  @override
  AvatarCostume? get costume;
  @override
  @SoundEffectConverter()
  SoundEffects? get soundEffect;

  /// Create a copy of AvatarConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AvatarConfigImplCopyWith<_$AvatarConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
