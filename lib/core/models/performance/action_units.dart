import 'package:freezed_annotation/freezed_annotation.dart';

part 'action_units.freezed.dart';

/// 14 Facial-Action-Coding-System style blend weights, each in [0, 1].
@freezed
sealed class ActionUnits with _$ActionUnits {
  const factory ActionUnits({
    // Brows
    @Default(0.0) double browInnerUp,
    @Default(0.0) double browOuterUp,
    @Default(0.0) double browLower,
    // Eyelids
    @Default(0.0) double lidTighten,
    @Default(0.0) double upperLidRaise,
    // Mid face
    @Default(0.0) double cheekRaise,
    @Default(0.0) double noseWrinkle,
    // Lip corners
    @Default(0.0) double lipCornerPull,
    @Default(0.0) double lipCornerDepress,
    // Mouth shape
    @Default(0.0) double lipStretch,
    @Default(0.0) double lipPucker,
    @Default(0.0) double lipPress,
    @Default(0.0) double jawDrop,
    @Default(0.0) double dimpler,
  }) = _ActionUnits;

  /// Fully relaxed face (every AU at zero).
  static const ActionUnits neutral = ActionUnits();

  const ActionUnits._();

  /// Per-AU sum, clamped to [0, 1].
  ActionUnits operator +(ActionUnits other) => ActionUnits(
    browInnerUp: (browInnerUp + other.browInnerUp).clamp(0.0, 1.0),
    browOuterUp: (browOuterUp + other.browOuterUp).clamp(0.0, 1.0),
    browLower: (browLower + other.browLower).clamp(0.0, 1.0),
    lidTighten: (lidTighten + other.lidTighten).clamp(0.0, 1.0),
    upperLidRaise: (upperLidRaise + other.upperLidRaise).clamp(0.0, 1.0),
    cheekRaise: (cheekRaise + other.cheekRaise).clamp(0.0, 1.0),
    noseWrinkle: (noseWrinkle + other.noseWrinkle).clamp(0.0, 1.0),
    lipCornerPull: (lipCornerPull + other.lipCornerPull).clamp(0.0, 1.0),
    lipCornerDepress: (lipCornerDepress + other.lipCornerDepress).clamp(
      0.0,
      1.0,
    ),
    lipStretch: (lipStretch + other.lipStretch).clamp(0.0, 1.0),
    lipPucker: (lipPucker + other.lipPucker).clamp(0.0, 1.0),
    lipPress: (lipPress + other.lipPress).clamp(0.0, 1.0),
    jawDrop: (jawDrop + other.jawDrop).clamp(0.0, 1.0),
    dimpler: (dimpler + other.dimpler).clamp(0.0, 1.0),
  );

  /// Every AU multiplied by [k], clamped to [0, 1].
  ActionUnits scale(double k) => ActionUnits(
    browInnerUp: (browInnerUp * k).clamp(0.0, 1.0),
    browOuterUp: (browOuterUp * k).clamp(0.0, 1.0),
    browLower: (browLower * k).clamp(0.0, 1.0),
    lidTighten: (lidTighten * k).clamp(0.0, 1.0),
    upperLidRaise: (upperLidRaise * k).clamp(0.0, 1.0),
    cheekRaise: (cheekRaise * k).clamp(0.0, 1.0),
    noseWrinkle: (noseWrinkle * k).clamp(0.0, 1.0),
    lipCornerPull: (lipCornerPull * k).clamp(0.0, 1.0),
    lipCornerDepress: (lipCornerDepress * k).clamp(0.0, 1.0),
    lipStretch: (lipStretch * k).clamp(0.0, 1.0),
    lipPucker: (lipPucker * k).clamp(0.0, 1.0),
    lipPress: (lipPress * k).clamp(0.0, 1.0),
    jawDrop: (jawDrop * k).clamp(0.0, 1.0),
    dimpler: (dimpler * k).clamp(0.0, 1.0),
  );
}
