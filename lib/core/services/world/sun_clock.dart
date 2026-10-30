import 'dart:math' as math;

/// Turns the local time and the sun times into the two numbers the scenes
/// blend with: `daylight` (0 at night, 1 around midday, smooth through civil
/// twilight) and `dusk` (a peak of 1 at sunrise and sunset, 0 an hour away).
///
/// Pure and continuous; every value is clamped to 0..1.
class SunClock {
  const SunClock._();

  /// Approximate civil sunrise / sunset at 45° N in local clock time (DST
  /// included), minutes after midnight, for the 15th of each month.
  static const List<({double sunrise, double sunset})> _months =
      <({double sunrise, double sunset})>[
        (sunrise: 8 * 60.0, sunset: 17 * 60.0 + 15), // Jan
        (sunrise: 7 * 60.0 + 30, sunset: 18 * 60.0 + 5), // Feb
        (sunrise: 7 * 60.0, sunset: 19 * 60.0), // Mar
        (sunrise: 7 * 60.0 + 5, sunset: 20 * 60.0 + 45), // Apr
        (sunrise: 6 * 60.0 + 15, sunset: 21 * 60.0 + 20), // May
        (sunrise: 5 * 60.0 + 50, sunset: 21 * 60.0 + 30), // Jun
        (sunrise: 6 * 60.0 + 10, sunset: 21 * 60.0 + 25), // Jul
        (sunrise: 6 * 60.0 + 50, sunset: 20 * 60.0 + 50), // Aug
        (sunrise: 7 * 60.0 + 30, sunset: 20 * 60.0), // Sep
        (sunrise: 8 * 60.0, sunset: 19 * 60.0 + 15), // Oct
        (sunrise: 7 * 60.0 + 30, sunset: 17 * 60.0 + 30), // Nov
        (sunrise: 8 * 60.0 + 10, sunset: 16 * 60.0 + 55), // Dec
      ];

  /// Daylight ramps from 0 at 30 min before the sun event to this value one
  /// hour after sunrise (mirrored at sunset), then to 1 at solar noon.
  static const double _twilightTop = 0.85;

  /// The shortest day a report may describe (minutes of local clock).
  static const double _minDayMinutes = 180;

  /// The clock at [local]. [sunrise] / [sunset] only matter by their time of
  /// day (a report from another day is shifted onto [local]'s day); when
  /// either is null the month table is used.
  static ({double daylight, double dusk}) at(
    DateTime local, {
    DateTime? sunrise,
    DateTime? sunset,
  }) {
    final double t = _minutes(local);
    ({double sunrise, double sunset}) sun = (sunrise != null && sunset != null)
        ? (sunrise: _minutes(sunrise), sunset: _minutes(sunset))
        : _monthSun(local);
    // A report whose sunset does not follow its sunrise by at least 3 h on
    // the local clock (a polar summer, a place in another time zone) cannot
    // be drawn as one day: the month table stands in.
    if (sun.sunset - sun.sunrise < _minDayMinutes) {
      sun = _monthSun(local);
    }
    return (
      daylight: _daylight(t, sun.sunrise, sun.sunset).clamp(0.0, 1.0),
      dusk: _dusk(t, sun.sunrise, sun.sunset).clamp(0.0, 1.0),
    );
  }

  static double _minutes(DateTime time) {
    final DateTime local = time.isUtc ? time.toLocal() : time;
    return local.hour * 60.0 + local.minute + local.second / 60.0;
  }

  static ({double sunrise, double sunset}) _monthSun(DateTime local) {
    final double x = (local.month - 1) + (local.day - 15) / 30.0;
    final int i0 = x.floor();
    final double f = x - i0;
    final ({double sunrise, double sunset}) a = _months[(i0 + 12) % 12];
    final ({double sunrise, double sunset}) b = _months[(i0 + 13) % 12];
    return (
      sunrise: a.sunrise + (b.sunrise - a.sunrise) * f,
      sunset: a.sunset + (b.sunset - a.sunset) * f,
    );
  }

  static double _smoothstep(double x) {
    final double c = x.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  /// The morning curve; the evening is its mirror around solar noon.
  static double _rise(double t, double sunrise, double noon) {
    final double start = sunrise - 30;
    final double top = sunrise + 60;
    if (t <= start) {
      return 0;
    }
    if (t <= top) {
      // Warped so that the sun event itself sits near 0.4, not 0.2.
      final double u = (t - start) / (top - start);
      final double w = 1 - math.pow(1 - u, 1.6).toDouble();
      return _twilightTop * _smoothstep(w);
    }
    if (t >= noon || noon <= top) {
      return 1;
    }
    return _twilightTop +
        (1 - _twilightTop) * _smoothstep((t - top) / (noon - top));
  }

  static double _daylight(double t, double sunrise, double sunset) {
    final double noon = (sunrise + sunset) / 2;
    final double mirrored = t <= noon ? t : sunrise + sunset - t;
    return _rise(mirrored, sunrise, noon);
  }

  static double _dusk(double t, double sunrise, double sunset) {
    double peak(double event) => 1 - _smoothstep((t - event).abs() / 60.0);
    final double a = peak(sunrise);
    final double b = peak(sunset);
    return a > b ? a : b;
  }
}
