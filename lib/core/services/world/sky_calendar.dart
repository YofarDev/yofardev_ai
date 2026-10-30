/// The sky as a function of the local date, pure (moonshot M9 rulings 12-14):
/// the moon's phase and the festive season. Nothing is fetched and no clock is
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

  /// Whether the local date is in December.
  static bool isDecember(DateTime local) => local.month == DateTime.december;

  /// Whether the local date is in the festive season: 1 December to 6
  /// January, both inclusive.
  static bool isFestive(DateTime local) =>
      isDecember(local) ||
      (local.month == DateTime.january && local.day <= festiveLastJanuaryDay);
}
