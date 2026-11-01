import 'package:flutter/foundation.dart';

import 'avatar_rive_contract.dart';

/// Writes the weather fog to `SceneVM.fog` (contract v11), only when it moved
/// by more than [epsilon].
class SceneFogWriter {
  SceneFogWriter(this._setNumber);

  final void Function(String name, double value) _setNumber;

  /// Smallest change worth writing.
  static const double epsilon = 0.001;

  double? _fog;

  /// Writes [fog] (clamped to 0..1); [force] writes it even when unchanged.
  void write(double fog, {bool force = false}) {
    final double value = fog.isNaN ? 0 : fog.clamp(0.0, 1.0);
    final double? last = _fog;
    if (!force && last != null && (value - last).abs() <= epsilon) {
      return;
    }
    _setNumber(AvatarRiveContract.scenePropFog, value);
    _fog = value;
  }
}

/// Follows a fog [ValueListenable] and writes it to a loaded scene binding,
/// like `SceneRainFollower`: [follow] swaps the source, [load] writes the
/// current fog into a fresh binding even when it equals what the previous one
/// got, [unload] drops it. Free of Rive so it can be tested.
class SceneFogFollower {
  ValueListenable<double>? _source;
  SceneFogWriter? _writer;

  /// Follows [source] (null: no fog) in place of the previous one, and
  /// writes its value to the loaded binding, if any.
  void follow(ValueListenable<double>? source) {
    if (source == _source) {
      return;
    }
    _source?.removeListener(_write);
    _source = source;
    source?.addListener(_write);
    _write();
  }

  /// A binding loaded: writes the current fog to its `setNumber`.
  void load(void Function(String name, double value) setNumber) {
    _writer = SceneFogWriter(setNumber)
      ..write(_source?.value ?? 0, force: true);
  }

  /// The binding is gone.
  void unload() => _writer = null;

  /// Stops listening.
  void dispose() {
    _source?.removeListener(_write);
    _source = null;
    _writer = null;
  }

  void _write() => _writer?.write(_source?.value ?? 0);
}
