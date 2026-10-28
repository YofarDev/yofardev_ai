import 'package:freezed_annotation/freezed_annotation.dart';

part 'light_rig.freezed.dart';

/// Scene lighting: key/rim/ambient colours and intensities plus atmosphere.
@freezed
sealed class LightRig with _$LightRig {
  const factory LightRig({
    @Default(0.0) double keyDirection,
    @Default(0xFFFFFFFF) int keyColor,
    @Default(1.0) double keyIntensity,
    @Default(0xFFFFFFFF) int rimColor,
    @Default(0.35) double rimIntensity,
    @Default(0xFF202028) int ambientColor,
    @Default(0.0) double fog,
    @Default(0) int flickerSeed,
    @Default(0.0) double flickerAmount,
  }) = _LightRig;

  /// Neutral, flat lighting.
  static const LightRig neutral = LightRig();
}
