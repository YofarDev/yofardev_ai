import 'package:flutter/foundation.dart';

import 'avatar_rive_contract.dart';

/// Writes the seasons to `SceneVM` (contract v14, M11 ruling 9): `spring`
/// and `autumn` (0..1 each), each only when it moved by more than
/// [epsilon].
///
/// A scene file without the property ignores the write (`RiveVmBinding`
/// resolves a missing property once and skips it), so this never has to know
/// which scenes bind them (forestCabin, campfire, livingRoom and
/// trainCompartment do).
class SceneSeasonWriter {
  SceneSeasonWriter(this._setNumber);

  final void Function(String name, double value) _setNumber;

  /// Smallest change worth writing.
  static const double epsilon = 0.001;

  double? _spring;
  double? _autumn;

  /// Writes [spring] and [autumn] ([force]: even when unchanged), clamped to
  /// 0..1; a NaN is the default 0.
  void write({
    required double spring,
    required double autumn,
    bool force = false,
  }) {
    _spring = _one(AvatarRiveContract.scenePropSpring, spring, _spring, force);
    _autumn = _one(AvatarRiveContract.scenePropAutumn, autumn, _autumn, force);
  }

  double _one(String name, double value, double? last, bool force) {
    final double next = value.isNaN
        ? AvatarRiveContract.seasonMin
        : value.clamp(
            AvatarRiveContract.seasonMin,
            AvatarRiveContract.seasonMax,
          );
    if (force || last == null || (next - last).abs() > epsilon) {
      _setNumber(name, next);
      return next;
    }
    return last;
  }
}

/// Follows the world's `spring` and `autumn` and writes them to the loaded
/// scene file: the scene view's season logic, free of Rive so it can be
/// tested.
///
/// Like `SceneSkyFollower`: [follow] swaps the sources, [load] writes the
/// current values into a fresh file in full (a scene switch gives the new
/// file the season), [unload] drops the file. Without a source both are 0
/// (the v13 look).
class SceneSeasonFollower {
  ValueListenable<double>? _spring;
  ValueListenable<double>? _autumn;
  SceneSeasonWriter? _writer;

  /// Follows [spring] and [autumn] in place of the previous sources, and
  /// writes them to the loaded file, if any.
  void follow(
    ValueListenable<double>? spring,
    ValueListenable<double>? autumn,
  ) {
    if (spring == _spring && autumn == _autumn) {
      return;
    }
    _spring?.removeListener(_write);
    _autumn?.removeListener(_write);
    _spring = spring;
    _autumn = autumn;
    spring?.addListener(_write);
    autumn?.addListener(_write);
    _write();
  }

  /// A scene file loaded: writes the current seasons to its `setNumber`.
  void load(void Function(String name, double value) setNumber) {
    _writer = SceneSeasonWriter(setNumber);
    _write(force: true);
  }

  /// The scene file is gone.
  void unload() => _writer = null;

  /// Stops listening.
  void dispose() {
    _spring?.removeListener(_write);
    _autumn?.removeListener(_write);
    _spring = null;
    _autumn = null;
    _writer = null;
  }

  void _write({bool force = false}) => _writer?.write(
    spring: _spring?.value ?? AvatarRiveContract.seasonMin,
    autumn: _autumn?.value ?? AvatarRiveContract.seasonMin,
    force: force,
  );
}
