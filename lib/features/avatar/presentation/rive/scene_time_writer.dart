import 'package:flutter/foundation.dart';

import 'avatar_rive_contract.dart';

/// Follows the world clock's `daylight` and `dusk` and writes them to the
/// loaded scene file (`SceneVM`, contract v10), with `night` (contract v13,
/// [nightOf]): the scene view's clock logic, free of Rive so it can be
/// tested.
///
/// `night` is written to every scene: a file without it (all but the beach
/// bind nothing, and older files lack it) ignores the write, as the binding
/// resolves a missing property once and skips it. Without a [daylight]
/// source (no world clock: the lab, tests) `night` stays 0, the v12 look,
/// while `daylight` / `dusk` are still written as 0.
///
/// Like `SceneRainFollower`: [follow] swaps the sources, [load] writes the
/// current values into a fresh file even when they equal what the previous
/// file got, [unload] drops the file. Writes only changes larger than
/// [epsilon].
class SceneTimeFollower {
  ValueListenable<double>? _daylight;
  ValueListenable<double>? _dusk;
  void Function(String name, double value)? _setNumber;
  double? _writtenDaylight;
  double? _writtenDusk;
  double? _writtenNight;

  /// Smallest change worth writing.
  static const double epsilon = 0.001;

  /// How much of the night shows (contract v13): `(1 − daylight) ×
  /// (1 − dusk)`, each clamped to 0..1 (NaN is 0).
  static double nightOf(double daylight, double dusk) {
    final double d = daylight.isNaN ? 0 : daylight.clamp(0.0, 1.0);
    final double k = dusk.isNaN ? 0 : dusk.clamp(0.0, 1.0);
    return (1 - d) * (1 - k);
  }

  /// Follows [daylight] and [dusk] (null: night) in place of the previous
  /// sources, and writes them to the loaded file, if any.
  void follow(
    ValueListenable<double>? daylight,
    ValueListenable<double>? dusk,
  ) {
    if (daylight == _daylight && dusk == _dusk) {
      return;
    }
    _daylight?.removeListener(_write);
    _dusk?.removeListener(_write);
    _daylight = daylight;
    _dusk = dusk;
    daylight?.addListener(_write);
    dusk?.addListener(_write);
    _write();
  }

  /// A scene file loaded: writes the current values to its `setNumber`.
  void load(void Function(String name, double value) setNumber) {
    _setNumber = setNumber;
    _writtenDaylight = null;
    _writtenDusk = null;
    _writtenNight = null;
    _write();
  }

  /// The scene file is gone.
  void unload() => _setNumber = null;

  /// Stops listening.
  void dispose() {
    _daylight?.removeListener(_write);
    _dusk?.removeListener(_write);
    _daylight = null;
    _dusk = null;
    _setNumber = null;
  }

  void _write() {
    final void Function(String name, double value)? set = _setNumber;
    if (set == null) {
      return;
    }
    final double daylight = (_daylight?.value ?? 0).clamp(0.0, 1.0);
    final double dusk = (_dusk?.value ?? 0).clamp(0.0, 1.0);
    final double? lastDaylight = _writtenDaylight;
    if (lastDaylight == null || (daylight - lastDaylight).abs() > epsilon) {
      set(AvatarRiveContract.scenePropDaylight, daylight);
      _writtenDaylight = daylight;
    }
    final double? lastDusk = _writtenDusk;
    if (lastDusk == null || (dusk - lastDusk).abs() > epsilon) {
      set(AvatarRiveContract.scenePropDusk, dusk);
      _writtenDusk = dusk;
    }
    final double night = _daylight == null ? 0 : nightOf(daylight, dusk);
    final double? lastNight = _writtenNight;
    if (lastNight == null || (night - lastNight).abs() > epsilon) {
      set(AvatarRiveContract.scenePropNight, night);
      _writtenNight = night;
    }
  }
}
