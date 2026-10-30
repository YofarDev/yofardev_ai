import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/world/sky_calendar.dart';

void main() {
  const double day = 1 / SkyCalendar.synodicMonthDays;

  // Distance on the phase circle.
  double apart(double a, double b) {
    final double d = (a - b).abs() % 1;
    return d > 0.5 ? 1 - d : d;
  }

  group('moonPhase', () {
    test('the reference new moon is phase 0', () {
      expect(
        SkyCalendar.moonPhase(SkyCalendar.referenceNewMoon),
        closeTo(0, 1e-9),
      );
      // local time zones: the same instant
      expect(
        SkyCalendar.moonPhase(SkyCalendar.referenceNewMoon.toLocal()),
        closeTo(0, 1e-9),
      );
    });

    test('half a month later is full, a quarter is a quarter', () {
      final DateTime start = SkyCalendar.referenceNewMoon;
      Duration month(double f) => Duration(
        microseconds: (SkyCalendar.synodicMonthDays * f * 86400e6).round(),
      );
      expect(
        SkyCalendar.moonPhase(start.add(month(0.25))),
        closeTo(0.25, 1e-6),
      );
      expect(SkyCalendar.moonPhase(start.add(month(0.5))), closeTo(0.5, 1e-6));
      expect(
        SkyCalendar.moonPhase(start.add(month(0.75))),
        closeTo(0.75, 1e-6),
      );
      expect(
        SkyCalendar.moonPhase(start.add(month(1.25))),
        closeTo(0.25, 1e-6),
      );
    });

    test('known full moons are within a day of 0.5', () {
      for (final DateTime fullMoon in <DateTime>[
        DateTime(2026, 10, 26, 12),
        DateTime(2026, 11, 24, 12),
      ]) {
        expect(
          (SkyCalendar.moonPhase(fullMoon) - 0.5).abs(),
          lessThanOrEqualTo(day),
          reason: '$fullMoon',
        );
      }
    });

    test('known new moons (2026-11-09, 2026-12-09) are within a day of 0', () {
      for (final DateTime newMoon in <DateTime>[
        DateTime(2026, 11, 9, 12),
        DateTime(2026, 12, 9, 12),
      ]) {
        expect(
          apart(SkyCalendar.moonPhase(newMoon), 0),
          lessThanOrEqualTo(day * 1.5),
          reason: '$newMoon',
        );
      }
    });

    test('dates before the reference fold into 0..1', () {
      final double phase = SkyCalendar.moonPhase(DateTime.utc(1969, 7, 20, 20));
      expect(phase, inInclusiveRange(0.0, 1.0));
      // the Moon landing was a waxing moon, a day short of first quarter
      expect(phase, inInclusiveRange(0.15, 0.25));
    });

    test('is continuous across a new moon (0.99 to 0.01, no jump)', () {
      // sample every 30 min across the new moon of 2026-11-10
      DateTime t = DateTime.utc(2026, 11, 9, 12);
      double? previous;
      bool wrapped = false;
      for (int i = 0; i < 96; i++) {
        final double p = SkyCalendar.moonPhase(t);
        if (previous != null) {
          if (p < previous) {
            wrapped = true;
          }
          expect(apart(p, previous), lessThan(0.001));
        }
        previous = p;
        t = t.add(const Duration(minutes: 30));
      }
      expect(wrapped, isTrue, reason: 'the window must contain a new moon');
    });

    test('never reaches 1 in the north, and the south mirrors it', () {
      DateTime t = DateTime.utc(2026, 1, 1);
      for (int i = 0; i < 24 * 400; i += 7) {
        final double north = SkyCalendar.moonPhase(t);
        final double south = SkyCalendar.moonPhase(t, southern: true);
        expect(north, inInclusiveRange(0.0, 1.0));
        expect(north, lessThan(1));
        expect(south, closeTo(1 - north, 1e-12));
        t = t.add(const Duration(hours: 7));
      }
    });

    test('a full moon is full in both hemispheres', () {
      final DateTime full = DateTime.utc(2026, 10, 26, 4);
      expect(SkyCalendar.moonPhase(full, southern: true), closeTo(0.5, day));
    });
  });

  group('festive season', () {
    test('1 Dec to 6 Jan, inclusive, by the local date', () {
      expect(SkyCalendar.isFestive(DateTime(2026, 11, 30, 23, 59)), isFalse);
      expect(SkyCalendar.isFestive(DateTime(2026, 12, 1)), isTrue);
      expect(SkyCalendar.isFestive(DateTime(2026, 12, 25, 12)), isTrue);
      expect(SkyCalendar.isFestive(DateTime(2026, 12, 31, 23, 59)), isTrue);
      expect(SkyCalendar.isFestive(DateTime(2027, 1, 1)), isTrue);
      expect(SkyCalendar.isFestive(DateTime(2027, 1, 6, 23, 59)), isTrue);
      expect(SkyCalendar.isFestive(DateTime(2027, 1, 7)), isFalse);
      expect(SkyCalendar.isFestive(DateTime(2027, 6, 15)), isFalse);
    });

    test('31 Dec to 1 Jan keeps festive, 7 Jan drops it', () {
      final DateTime newYearsEve = DateTime(2026, 12, 31, 23, 59, 59);
      expect(SkyCalendar.isFestive(newYearsEve), isTrue);
      expect(
        SkyCalendar.isFestive(newYearsEve.add(const Duration(seconds: 1))),
        isTrue,
      );
      expect(SkyCalendar.isFestive(DateTime(2027, 1, 7, 0, 0, 0)), isFalse);
    });

    test('December is 1 to 31 December only', () {
      expect(SkyCalendar.isDecember(DateTime(2026, 11, 30, 23, 59)), isFalse);
      expect(SkyCalendar.isDecember(DateTime(2026, 12, 1)), isTrue);
      expect(SkyCalendar.isDecember(DateTime(2026, 12, 31, 23, 59)), isTrue);
      expect(SkyCalendar.isDecember(DateTime(2027, 1, 1)), isFalse);
      expect(SkyCalendar.isDecember(DateTime(2027, 1, 3)), isFalse);
    });

    test('a leap year changes nothing', () {
      expect(SkyCalendar.isFestive(DateTime(2028, 1, 6)), isTrue);
      expect(SkyCalendar.isFestive(DateTime(2028, 1, 7)), isFalse);
    });
  });
}
