import 'package:flutter/foundation.dart';

/// The state of the world the scenes show, app-wide.
///
/// For now that is the weather's [rain]. World sync (M7-M9) will feed it from
/// the weather tool; until then only the debug UI lab sets it.
class WorldStateService {
  final ValueNotifier<double> _rain = ValueNotifier<double>(0);

  /// Steady rain intensity, 0 (dry) to 1 (downpour). Default 0.
  ValueListenable<double> get rain => _rain;

  /// Sets the rain intensity, clamped to 0..1. NaN is ignored.
  void setRain(double value) {
    if (value.isNaN) {
      return;
    }
    _rain.value = value.clamp(0.0, 1.0);
  }

  void dispose() => _rain.dispose();
}
