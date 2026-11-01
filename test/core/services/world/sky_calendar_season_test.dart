import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/world/sky_calendar.dart';

typedef _Season = ({double spring, double autumn});

_Season _at(int year, int month, int day, {int hour = 12, double? latitude}) =>
    SkyCalendar.season(DateTime(year, month, day, hour), latitude: latitude);

void main() {
  group('spring (northern view)', () {
    test('the window opens on 1 March at 1/7 and is full on 7 March', () {
      expect(_at(2026, 2, 28).spring, 0);
      for (int day = 1; day <= 7; day++) {
        expect(
          _at(2026, 3, day).spring,
          closeTo(day / 7, 1e-12),
          reason: '$day March',
        );
      }
      expect(_at(2026, 3, 8).spring, 1);
      expect(_at(2026, 4, 15).spring, 1);
    });

    test('the window closes over 25..31 May (1 down to 1/7)', () {
      expect(_at(2026, 5, 24).spring, 1);
      for (int day = 25; day <= 31; day++) {
        expect(
          _at(2026, 5, day).spring,
          closeTo((32 - day) / 7, 1e-12),
          reason: '$day May',
        );
      }
      expect(_at(2026, 6, 1).spring, 0);
    });

    test('a day keeps one value from midnight to 23:59', () {
      final double morning = SkyCalendar.season(DateTime(2026, 3, 3)).spring;
      final double night = SkyCalendar.season(
        DateTime(2026, 3, 3, 23, 59, 59),
      ).spring;
      expect(morning, closeTo(3 / 7, 1e-12));
      expect(night, morning);
    });

    test('leap years change nothing: 29 February is winter', () {
      expect(_at(2028, 2, 29).spring, 0);
      expect(_at(2028, 2, 29).autumn, 0);
      expect(_at(2028, 3, 1).spring, closeTo(1 / 7, 1e-12));
      expect(_at(2028, 3, 7).spring, 1);
      expect(_at(2028, 5, 31).spring, closeTo(1 / 7, 1e-12));
    });
  });

  group('autumn (northern view)', () {
    test('opens on 1 September at 1/7, full from 7 September', () {
      expect(_at(2026, 8, 31).autumn, 0);
      expect(_at(2026, 9, 1).autumn, closeTo(1 / 7, 1e-12));
      expect(_at(2026, 9, 4).autumn, closeTo(4 / 7, 1e-12));
      expect(_at(2026, 9, 7).autumn, 1);
      expect(_at(2026, 10, 31).autumn, 1);
    });

    test('closes over 24..30 November, 0 from 1 December', () {
      expect(_at(2026, 11, 23).autumn, 1);
      for (int day = 24; day <= 30; day++) {
        expect(
          _at(2026, 11, day).autumn,
          closeTo((31 - day) / 7, 1e-12),
          reason: '$day November',
        );
      }
      expect(_at(2026, 12, 1).autumn, 0);
    });
  });

  group('south of the equator', () {
    test('the two swap', () {
      expect(_at(2026, 4, 15, latitude: -33.9).autumn, 1);
      expect(_at(2026, 4, 15, latitude: -33.9).spring, 0);
      expect(_at(2026, 10, 15, latitude: -33.9).spring, 1);
      expect(_at(2026, 10, 15, latitude: -33.9).autumn, 0);
      expect(_at(2026, 9, 2, latitude: -0.1).spring, closeTo(2 / 7, 1e-12));
      expect(_at(2026, 3, 1, latitude: -45).autumn, closeTo(1 / 7, 1e-12));
    });

    test('the equator and the north keep the northern view', () {
      expect(_at(2026, 4, 15, latitude: 0).spring, 1);
      expect(_at(2026, 4, 15, latitude: 48.8).spring, 1);
      expect(_at(2026, 4, 15).spring, 1);
    });
  });

  test('every day of a leap and a common year: in 0..1, never both above 0, '
      'never autumn while festive, ramps by at most 1/7 a day', () {
    for (final int year in <int>[2027, 2028]) {
      for (final double? latitude in <double?>[null, 45, -33]) {
        DateTime day = DateTime(year);
        _Season previous = SkyCalendar.season(
          DateTime(year - 1, 12, 31),
          latitude: latitude,
        );
        while (day.year == year) {
          final _Season s = SkyCalendar.season(day, latitude: latitude);
          final String why = '$day lat $latitude';
          expect(s.spring, inInclusiveRange(0, 1), reason: why);
          expect(s.autumn, inInclusiveRange(0, 1), reason: why);
          expect(s.spring > 0 && s.autumn > 0, isFalse, reason: why);
          if (SkyCalendar.isFestive(day)) {
            expect(s.spring, 0, reason: why);
            expect(s.autumn, 0, reason: why);
          }
          expect(
            (s.spring - previous.spring).abs(),
            lessThanOrEqualTo(1 / 7 + 1e-12),
            reason: why,
          );
          expect(
            (s.autumn - previous.autumn).abs(),
            lessThanOrEqualTo(1 / 7 + 1e-12),
            reason: why,
          );
          previous = s;
          day = DateTime(day.year, day.month, day.day + 1);
        }
      }
    }
  });

  test('a DST change day (last Sunday of March) is still one day', () {
    // 29 March 2026 in Europe: the day is 23 h long; the value is per date.
    expect(_at(2026, 3, 29, hour: 1).spring, 1);
    expect(_at(2026, 3, 29, hour: 23).spring, 1);
    expect(_at(2026, 3, 6, hour: 0).spring, closeTo(6 / 7, 1e-12));
  });
}
