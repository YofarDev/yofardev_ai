import 'package:freezed_annotation/freezed_annotation.dart';

part 'light_rig.freezed.dart';

/// One scene's light as data: the key (colour, strength and direction as a
/// viewer-space vector toward the light), the rim, the ambient fill, the fog
/// and how much the flame/lamp flickers. Colours are ARGB ints.
@freezed
sealed class LightRig with _$LightRig {
  const factory LightRig({
    @Default(0xFFFFFFFF) int keyColor,
    @Default(1.0) double keyIntensity,

    /// Direction toward the key light, viewer space, −1..1 (`cos` of the angle).
    @Default(0.0) double keyX,

    /// Direction toward the key light, viewer space, −1..1 (`sin` of the angle).
    @Default(0.0) double keyY,
    @Default(0xFFFFFFFF) int rimColor,
    @Default(0.35) double rimIntensity,
    @Default(0xFF202028) int ambientColor,
    @Default(0.35) double ambientAmount,
    @Default(0x00000000) int fogColor,

    /// 0 steady .. 1 full flame flicker (looped inside the Rive files).
    @Default(0.0) double flicker,
  }) = _LightRig;

  /// Neutral, flat lighting.
  static const LightRig neutral = LightRig();
}
