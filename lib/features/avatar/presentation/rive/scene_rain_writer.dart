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
