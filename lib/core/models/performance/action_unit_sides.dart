import 'package:freezed_annotation/freezed_annotation.dart';

part 'action_unit_sides.freezed.dart';

/// Per-side offsets for the seven action units that can act on one side of
/// the face (contract v6): each is a signed amount in [-1, 1], added to the
/// symmetric [ActionUnits] value on that side (the file clamps the sum to
/// [0, 1]). One instance describes one side, the viewer's left or right.
@freezed
sealed class ActionUnitSides with _$ActionUnitSides {
  const factory ActionUnitSides({
    @Default(0.0) double browInnerUp,
    @Default(0.0) double browOuterUp,
    @Default(0.0) double browLower,
    @Default(0.0) double lidTighten,
    @Default(0.0) double cheekRaise,
    @Default(0.0) double lipCornerPull,
    @Default(0.0) double lipCornerDepress,
  }) = _ActionUnitSides;

  const ActionUnitSides._();

  /// No offset on this side.
  static const ActionUnitSides zero = ActionUnitSides();

  /// Per-AU sum, clamped to [-1, 1].
  ActionUnitSides operator +(ActionUnitSides other) => ActionUnitSides(
    browInnerUp: _c(browInnerUp + other.browInnerUp),
    browOuterUp: _c(browOuterUp + other.browOuterUp),
    browLower: _c(browLower + other.browLower),
    lidTighten: _c(lidTighten + other.lidTighten),
    cheekRaise: _c(cheekRaise + other.cheekRaise),
    lipCornerPull: _c(lipCornerPull + other.lipCornerPull),
    lipCornerDepress: _c(lipCornerDepress + other.lipCornerDepress),
  );

  /// Every offset multiplied by [k], clamped to [-1, 1].
  ActionUnitSides scale(double k) => ActionUnitSides(
    browInnerUp: _c(browInnerUp * k),
    browOuterUp: _c(browOuterUp * k),
    browLower: _c(browLower * k),
    lidTighten: _c(lidTighten * k),
    cheekRaise: _c(cheekRaise * k),
    lipCornerPull: _c(lipCornerPull * k),
    lipCornerDepress: _c(lipCornerDepress * k),
  );

  /// Per-AU linear interpolation towards [to] at [t] (exact at 0 and 1),
  /// clamped to [-1, 1].
  ActionUnitSides lerp(ActionUnitSides to, double t) => ActionUnitSides(
    browInnerUp: _mix(browInnerUp, to.browInnerUp, t),
    browOuterUp: _mix(browOuterUp, to.browOuterUp, t),
    browLower: _mix(browLower, to.browLower, t),
    lidTighten: _mix(lidTighten, to.lidTighten, t),
    cheekRaise: _mix(cheekRaise, to.cheekRaise, t),
    lipCornerPull: _mix(lipCornerPull, to.lipCornerPull, t),
    lipCornerDepress: _mix(lipCornerDepress, to.lipCornerDepress, t),
  );
}

double _c(double v) => v.clamp(-1.0, 1.0);

double _mix(double a, double b, double t) => _c(a * (1 - t) + b * t);
