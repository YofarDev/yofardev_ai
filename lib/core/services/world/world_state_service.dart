import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/weather_report.dart';
import 'sun_clock.dart';

/// The state of the world the scenes show, app-wide: the weather's [rain] and
/// [fog] and the time of day ([daylight], [dusk]).
///
/// The rain and the fog come from the weather tool and `WorldWeatherSync`
/// through [applyWeather], for the user's own location only (the debug UI
/// lab and the capture harness use [setRain], [setFog] and [pinClock]). The clock is recomputed once a minute while [start]ed.
class WorldStateService {
  WorldStateService({DateTime Function()? now}) : _now = now ?? DateTime.now {
    _recompute();
  }

  /// Values closer than this to the current one do not notify.
  static const double _epsilon = 0.001;

  final DateTime Function() _now;
  final ValueNotifier<double> _rain = ValueNotifier<double>(0);
  final ValueNotifier<double> _fog = ValueNotifier<double>(0);
  final ValueNotifier<double> _daylight = ValueNotifier<double>(0);
  final ValueNotifier<double> _dusk = ValueNotifier<double>(0);

  Timer? _timer;
  DateTime? _pinned;
  DateTime? _sunrise;
  DateTime? _sunset;

  /// Steady rain intensity, 0 (dry) to 1 (downpour). Default 0.
  ValueListenable<double> get rain => _rain;

  /// Weather fog or mist, 0 (clear) to 1 (thick fog). Default 0.
  ValueListenable<double> get fog => _fog;

  /// 0 at night, 1 around midday, smooth through twilight (see [SunClock]).
  ValueListenable<double> get daylight => _daylight;

  /// 1 at sunrise and sunset, 0 an hour away from them.
  ValueListenable<double> get dusk => _dusk;

  /// Sets the rain intensity, clamped to 0..1. NaN is ignored.
  void setRain(double value) {
    if (value.isNaN) {
      return;
    }
    _rain.value = value.clamp(0.0, 1.0);
  }

  /// Sets the fog, clamped to 0..1. NaN is ignored.
  void setFog(double value) {
    if (value.isNaN) {
      return;
    }
    _fog.value = value.clamp(0.0, 1.0);
  }

  /// Applies a weather report for the user's own location: the rain and the
  /// fog from the condition and the sun times for the clock.
  void applyWeather(WeatherReport report) {
    setRain(report.rainIntensity);
    setFog(report.fogIntensity);
    _sunrise = report.sunrise;
    _sunset = report.sunset;
    _recompute();
  }

  /// Starts the minute timer (and recomputes now). Safe to call again.
  void start() {
    _timer?.cancel();
    _recompute();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (Timer _) => _recompute(),
    );
  }

  /// Stops the minute timer (the app is paused); [start] resumes it.
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  /// Computes the clock values from the fixed [local] time instead of
  /// `now()`; null returns to the real clock. For the UI lab and the harness.
  void pinClock(DateTime? local) {
    _pinned = local;
    _recompute();
  }

  void _recompute() {
    final ({double daylight, double dusk}) values = SunClock.at(
      _pinned ?? _now(),
      sunrise: _sunrise,
      sunset: _sunset,
    );
    _set(_daylight, values.daylight);
    _set(_dusk, values.dusk);
  }

  void _set(ValueNotifier<double> notifier, double value) {
    if ((notifier.value - value).abs() > _epsilon) {
      notifier.value = value;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _rain.dispose();
    _fog.dispose();
    _daylight.dispose();
    _dusk.dispose();
  }
}
