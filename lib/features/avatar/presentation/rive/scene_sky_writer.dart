import 'package:flutter/foundation.dart';

import 'avatar_rive_contract.dart';

/// Writes the sky calendar to `SceneVM` (contract v12): `moonPhase` (0..1, or
/// -1 for the moon as drawn before v12) and `festive` (0..1), each only when
/// it moved by more than [epsilon].
///
/// A scene file without the property ignores the write (`RiveVmBinding`
/// resolves a missing property once and skips it), so this never has to know
/// which scenes bind them.
class SceneSkyWriter {
  SceneSkyWriter(this._setNumber);

  final void Function(String name, double value) _setNumber;

  /// Smallest change worth writing.
  static const double epsilon = 0.001;

  double? _moon;
  double? _festive;

  /// Writes [moonPhase] and [festive] ([force]: even when unchanged). A NaN
  /// is the default (as drawn, no festive dressing); a moon phase below 0
  /// is -1, one above 1 is 1.
  void write({
    required double moonPhase,
    required double festive,
    bool force = false,
  }) {
    final double moon = moonPhase.isNaN
        ? AvatarRiveContract.moonPhaseDefault
        : (moonPhase < 0
              ? AvatarRiveContract.moonPhaseDefault
              : moonPhase.clamp(
                  AvatarRiveContract.moonPhaseMin,
                  AvatarRiveContract.moonPhaseMax,
                ));
    final double? lastMoon = _moon;
    if (force || lastMoon == null || (moon - lastMoon).abs() > epsilon) {
      _setNumber(AvatarRiveContract.scenePropMoonPhase, moon);
      _moon = moon;
    }
    final double dressing = festive.isNaN
        ? AvatarRiveContract.festiveMin
        : festive.clamp(
            AvatarRiveContract.festiveMin,
            AvatarRiveContract.festiveMax,
          );
    final double? lastFestive = _festive;
    if (force ||
        lastFestive == null ||
        (dressing - lastFestive).abs() > epsilon) {
      _setNumber(AvatarRiveContract.scenePropFestive, dressing);
      _festive = dressing;
    }
  }
}

/// Follows the world's `moonPhase` and `festive` and writes them to the loaded
/// scene file: the scene view's sky logic, free of Rive so it can be tested.
///
/// Like `SceneTimeFollower`: [follow] swaps the sources, [load] writes the
/// current values into a fresh file in full (a scene switch gives the new
/// file the sky), [unload] drops the file. Without a source the moon is
/// as drawn and nothing is festive.
class SceneSkyFollower {
  ValueListenable<double>? _moon;
  ValueListenable<double>? _festive;
  SceneSkyWriter? _writer;

  /// Follows [moonPhase] and [festive] in place of the previous sources, and
  /// writes them to the loaded file, if any.
  void follow(
    ValueListenable<double>? moonPhase,
    ValueListenable<double>? festive,
  ) {
    if (moonPhase == _moon && festive == _festive) {
      return;
    }
    _moon?.removeListener(_write);
    _festive?.removeListener(_write);
    _moon = moonPhase;
    _festive = festive;
    moonPhase?.addListener(_write);
    festive?.addListener(_write);
    _write();
  }

  /// A scene file loaded: writes the current sky to its `setNumber`.
  void load(void Function(String name, double value) setNumber) {
    _writer = SceneSkyWriter(setNumber);
    _write(force: true);
  }

  /// The scene file is gone.
  void unload() => _writer = null;

  /// Stops listening.
  void dispose() {
    _moon?.removeListener(_write);
    _festive?.removeListener(_write);
    _moon = null;
    _festive = null;
    _writer = null;
  }

  void _write({bool force = false}) => _writer?.write(
    moonPhase: _moon?.value ?? AvatarRiveContract.moonPhaseDefault,
    festive: _festive?.value ?? AvatarRiveContract.festiveMin,
    force: force,
  );
}
