import 'package:flutter/foundation.dart' show visibleForTesting;

/// Writes a drag handle's numbers to `SceneVM` (contract v12): only the
/// numbers that changed since the last write. While [write]'s `animating` is
/// true a change smaller than [epsilon] waits (a 20 s fade does not write
/// every frame); a settled write is exact, so a spring always lands on its
/// default.
class SceneDragWriter {
  /// [defaults] are what the file holds before the first write: nothing is
  /// written for them.
  SceneDragWriter(this._setNumber, {Map<String, double>? defaults})
    : _written = <String, double>{...?defaults};

  final void Function(String name, double value) _setNumber;
  final Map<String, double> _written;

  /// Smallest change worth writing while something animates.
  static const double epsilon = 0.0005;

  /// How many numbers were written so far.
  @visibleForTesting
  int writes = 0;

  /// Writes what changed in [values].
  void write(Map<String, double> values, {bool animating = false}) {
    for (final MapEntry<String, double> entry in values.entries) {
      final double? last = _written[entry.key];
      final double value = entry.value;
      if (last == value) {
        continue;
      }
      if (animating && last != null && (value - last).abs() <= epsilon) {
        continue;
      }
      _setNumber(entry.key, value);
      _written[entry.key] = value;
      writes++;
    }
  }
}
