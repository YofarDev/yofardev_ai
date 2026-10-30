import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/weather_report.dart';
import 'sky_calendar.dart';
import 'sun_clock.dart';

/// The state of the world the scenes show, app-wide: the weather's [rain] and
/// [fog], the time of day ([daylight], [dusk]) and the sky's calendar
/// ([moonPhase], [festive], [localDay]).
///
/// The rain and the fog come from the weather tool and `WorldWeatherSync`
/// through [applyWeather], for the user's own location only (the debug UI
/// lab and the capture harness use [setRain], [setFog] and [pinClock]). The
/// clock and the calendar are recomputed once a minute while [start]ed, and
/// whenever the clock is pinned. The moon is mirrored (`1 - phase`) once an
/// own-location report put the user south of the equator.
class WorldStateService {
  WorldStateService({DateTime Function()? now}) : _now = now ?? DateTime.now {
    _recompute();
  }

  /// `SceneVM.moonPhase` default: the moon as drawn before contract v12.
  static const double _moonAsDrawn = -1;

  /// Values closer than this to the current one do not notify.
  static const double _epsilon = 0.001;

  final DateTime Function() _now;
  final ValueNotifier<double> _rain = ValueNotifier<double>(0);
  final ValueNotifier<double> _fog = ValueNotifier<double>(0);
  final ValueNotifier<double> _daylight = ValueNotifier<double>(0);
  final ValueNotifier<double> _dusk = ValueNotifier<double>(0);
  final ValueNotifier<double> _moonPhase = ValueNotifier<double>(_moonAsDrawn);
  final ValueNotifier<double> _festive = ValueNotifier<double>(0);
  late final ValueNotifier<DateTime> _localDay = ValueNotifier<DateTime>(
    _dayOf(_now()),
  );

  Timer? _timer;
  DateTime? _pinned;
  DateTime? _sunrise;
  DateTime? _sunset;
  double? _latitude;
  double? _moonOverride;
  double? _festiveOverride;

  /// Steady rain intensity, 0 (dry) to 1 (downpour). Default 0.
  ValueListenable<double> get rain => _rain;

  /// Weather fog or mist, 0 (clear) to 1 (thick fog). Default 0.
  ValueListenable<double> get fog => _fog;

  /// 0 at night, 1 around midday, smooth through twilight (see [SunClock]).
  ValueListenable<double> get daylight => _daylight;

  /// 1 at sunrise and sunset, 0 an hour away from them.
  ValueListenable<double> get dusk => _dusk;

  /// The moon's phase for `SceneVM.moonPhase`: 0 new, 0.25 first quarter, 0.5
  /// full, 0.75 last quarter; -1 draws the moon as it was before v12 (only
  /// a hand-set value gives that). From the calendar ([SkyCalendar]) and the
  /// hemisphere of the last own-location report (south: mirrored).
  ValueListenable<double> get moonPhase => _moonPhase;

  /// 1 from 1 December to 6 January (the local date), else 0.
  ValueListenable<double> get festive => _festive;

  /// The local calendar day (midnight), for the avatar's December outfit.
  ValueListenable<DateTime> get localDay => _localDay;

  /// The local time the world shows now: the pinned one, else the clock's.
  DateTime get localNow => _pinned ?? _now();

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

  /// Holds the moon at [phase] (the UI lab; below 0 means as drawn, -1)
  /// instead of the calendar's; null returns to the calendar.
  void setMoonPhase(double? phase) {
    if (phase != null && phase.isNaN) {
      return;
    }
    _moonOverride = phase == null
        ? null
        : (phase < 0 ? _moonAsDrawn : phase.clamp(0.0, 1.0));
    _recompute();
  }

  /// Holds the festive dressing at [value] (0..1, the UI lab) instead of the
  /// calendar's; null returns to the calendar.
  void setFestive(double? value) {
    if (value != null && value.isNaN) {
      return;
    }
    _festiveOverride = value?.clamp(0.0, 1.0);
    _recompute();
  }

  /// Applies a weather report for the user's own location: the rain and the
  /// fog from the condition and the sun times for the clock.
  void applyWeather(WeatherReport report) {
    setRain(report.rainIntensity);
    setFog(report.fogIntensity);
    _sunrise = report.sunrise;
    _sunset = report.sunset;
    _latitude = report.latitude ?? _latitude;
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
    final DateTime local = localNow;
    final ({double daylight, double dusk}) values = SunClock.at(
      local,
      sunrise: _sunrise,
      sunset: _sunset,
    );
    _set(_daylight, values.daylight);
    _set(_dusk, values.dusk);
    final double? latitude = _latitude;
    _set(
      _moonPhase,
      _moonOverride ??
          SkyCalendar.moonPhase(
            local,
            southern: latitude != null && latitude < 0,
          ),
    );
    _set(
      _festive,
      _festiveOverride ?? (SkyCalendar.isFestive(local) ? 1.0 : 0.0),
    );
    final DateTime day = _dayOf(local);
    if (day != _localDay.value) {
      _localDay.value = day;
    }
  }

  static DateTime _dayOf(DateTime local) =>
      DateTime(local.year, local.month, local.day);

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
    _moonPhase.dispose();
    _festive.dispose();
    _localDay.dispose();
  }
}
