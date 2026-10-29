import 'package:flutter/foundation.dart';

import 'avatar_rive_contract.dart';

/// Writes the rain intensity to `SceneVM.rain` (contract v8), only when it
/// moved by more than [epsilon].
class SceneRainWriter {
  SceneRainWriter(this._setNumber);

  final void Function(String name, double value) _setNumber;

  /// Smallest change worth writing.
  static const double epsilon = 0.001;

  double? _rain;

  /// Forgets what was written (a fresh binding has none of it).
  void reset() => _rain = null;

  /// Writes [rain] (clamped to 0..1); [force] writes it even when unchanged.
  void write(double rain, {bool force = false}) {
    final double value = rain.clamp(0.0, 1.0);
    final double? last = _rain;
    if (!force && last != null && (value - last).abs() <= epsilon) {
      return;
    }
    _setNumber(AvatarRiveContract.scenePropRain, value);
    _rain = value;
  }
}

/// Follows a rain [ValueListenable] and writes it to the loaded scene file:
/// the scene view's rain logic, free of Rive so it can be tested.
///
/// [follow] swaps the source (and its listener); [load] runs when a scene file
/// finishes loading and writes the current rain into that fresh file even if
/// it equals what the previous file got; [unload] drops the file.
class SceneRainFollower {
  ValueListenable<double>? _source;
  SceneRainWriter? _writer;

  /// Follows [source] (null leaves the scene dry) in place of the previous
  /// one, and writes its value to the loaded file, if any.
  void follow(ValueListenable<double>? source) {
    if (source == _source) {
      return;
    }
    _source?.removeListener(_write);
    _source = source;
    source?.addListener(_write);
    _write();
  }

  /// A scene file loaded: writes the current rain to its `setNumber`.
  void load(void Function(String name, double value) setNumber) {
    _writer = SceneRainWriter(setNumber)
      ..write(_source?.value ?? 0, force: true);
  }

  /// The scene file is gone.
  void unload() => _writer = null;

  /// Stops listening.
  void dispose() {
    _source?.removeListener(_write);
    _source = null;
    _writer = null;
  }

  void _write() => _writer?.write(_source?.value ?? 0);
}
