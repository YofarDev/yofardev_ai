/// The sky as a function of the local date, pure (moonshot M9 rulings 12-14,
/// M11 ruling 9): the moon's phase, the festive season and spring / autumn. Nothing is fetched and no clock is
/// read here; `WorldStateService` passes its (possibly pinned) local time.
abstract final class SkyCalendar {
  /// The mean synodic month, in days.
  static const double synodicMonthDays = 29.530588853;

  /// A new moon: 2000-01-06 18:14 UTC. The mean-month model drifts at most
  /// about a day from the real phase, which is all a window moon needs.
  static final DateTime referenceNewMoon = DateTime.utc(2000, 1, 6, 18, 14);

  /// The festive season ends on this day of January (inclusive).
  static const int festiveLastJanuaryDay = 6;

  /// The moon's phase at the instant [local]: 0 new, 0.25 first quarter, 0.5
  /// full, 0.75 last quarter, in `[0, 1]` (the scene's `moonPhase`).
  ///
  /// The northern hemisphere's view (waxing is lit on the right). With
  /// [southern] the same moon is the mirror image, `1 - phase`.
  static double moonPhase(DateTime local, {bool southern = false}) {
    final double days =
        local.toUtc().difference(referenceNewMoon).inMicroseconds /
        Duration.microsecondsPerDay;
    final double cycles = days / synodicMonthDays;
    // fold into [0, 1); the double remainder of a negative is negative
    double phase = cycles - cycles.floorToDouble();
    if (phase >= 1) {
      phase = 0;
    }
    return southern ? 1 - phase : phase;
  }

  /// Days over which a season's dressing arrives (and leaves) at each end of
  /// its window.
  static const int seasonRampDays = 7;

  /// Spring and autumn at the local date [local], each in `[0, 1]` (the
  /// scenes' `spring` / `autumn`, contract v14).
  ///
  /// Meteorological seasons, the northern view: spring 1 March - 31 May,
  /// autumn 1 September - 30 November. Each is 1 inside its window and ramps
  /// linearly over the window's first and last [seasonRampDays] days (1
  /// March is 1/7, 7 March 1; 25 May 1, 31 May 1/7), by the calendar date
  /// only (one value per day, whatever the hour or a DST change). Outside
  /// both windows both are 0, so they never overlap each other nor
  /// [isFestive]. With a [latitude] south of the equator the two swap (the
  /// same hemisphere rule as [moonPhase]'s mirror).
  static ({double spring, double autumn}) season(
    DateTime local, {
    double? latitude,
  }) {
    final double march = _window(local, DateTime.march, DateTime.may);
    final double september = _window(
      local,
      DateTime.september,
      DateTime.november,
    );
    final bool southern = latitude != null && latitude < 0;
    return southern
        ? (spring: september, autumn: march)
        : (spring: march, autumn: september);
  }

  /// The ramped level of the window from the 1st of [firstMonth] to the last
  /// day of [lastMonth] (same year) at the date of [local].
  static double _window(DateTime local, int firstMonth, int lastMonth) {
    // UTC dates: whole days whatever the local DST
    final DateTime day = DateTime.utc(local.year, local.month, local.day);
    final DateTime start = DateTime.utc(local.year, firstMonth);
    // day 0 of the next month = the last day of lastMonth
    final DateTime end = DateTime.utc(local.year, lastMonth + 1, 0);
    if (day.isBefore(start) || day.isAfter(end)) {
      return 0;
    }
    final int fromStart = day.difference(start).inDays + 1;
    final int toEnd = end.difference(day).inDays + 1;
    final int edge = fromStart < toEnd ? fromStart : toEnd;
    return edge >= seasonRampDays ? 1 : edge / seasonRampDays;
  }

  /// Whether the local date is in December.
  static bool isDecember(DateTime local) => local.month == DateTime.december;

  /// Whether the local date is in the festive season: 1 December to 6
  /// January, both inclusive.
  static bool isFestive(DateTime local) =>
      isDecember(local) ||
      (local.month == DateTime.january && local.day <= festiveLastJanuaryDay);
}
