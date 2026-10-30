import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/world/sun_clock.dart';

({double daylight, double dusk}) _at(DateTime t, DateTime sr, DateTime ss) =>
    SunClock.at(t, sunrise: sr, sunset: ss);

void main() {
  final DateTime sunrise = DateTime(2026, 6, 15, 6);
  final DateTime sunset = DateTime(2026, 6, 15, 21);

  test('noon is full daylight and no dusk', () {
    final ({double daylight, double dusk}) v = _at(
      DateTime(2026, 6, 15, 13, 30),
      sunrise,
      sunset,
    );
    expect(v.daylight, closeTo(1, 1e-6));
    expect(v.dusk, 0);
  });

  test('midnight is dark', () {
    final ({double daylight, double dusk}) v = _at(
      DateTime(2026, 6, 15, 0),
      sunrise,
      sunset,
    );
    expect(v.daylight, 0);
    expect(v.dusk, 0);
  });

  test('sunset: dusk peaks and daylight is mid', () {
    final ({double daylight, double dusk}) v = _at(sunset, sunrise, sunset);
    expect(v.dusk, closeTo(1, 1e-6));
    expect(v.daylight, inInclusiveRange(0.3, 0.6));
  });

  test('sunrise: dusk peaks and daylight is mid', () {
    final ({double daylight, double dusk}) v = _at(sunrise, sunrise, sunset);
    expect(v.dusk, closeTo(1, 1e-6));
    expect(v.daylight, inInclusiveRange(0.3, 0.6));
  });

  test('dusk is 0 an hour away from the sun', () {
    expect(_at(sunset.add(const Duration(hours: 1)), sunrise, sunset).dusk, 0);
    expect(
      _at(sunset.subtract(const Duration(hours: 1)), sunrise, sunset).dusk,
      0,
    );
    expect(_at(sunrise.add(const Duration(hours: 1)), sunrise, sunset).dusk, 0);
  });

  test('daylight rises monotonically from sunrise - 30 min to noon', () {
    double previous = -1;
    final DateTime start = sunrise.subtract(const Duration(minutes: 30));
    final DateTime noon = DateTime(2026, 6, 15, 13, 30);
    for (
      DateTime t = start;
      !t.isAfter(noon);
      t = t.add(const Duration(minutes: 5))
    ) {
      final double d = _at(t, sunrise, sunset).daylight;
      expect(d, greaterThanOrEqualTo(previous));
      previous = d;
    }
    expect(_at(start, sunrise, sunset).daylight, 0);
    expect(
      _at(sunrise.add(const Duration(hours: 1)), sunrise, sunset).daylight,
      closeTo(0.85, 1e-6),
    );
  });

  test('daylight falls monotonically from noon to sunset + 30 min', () {
    double previous = 2;
    for (
      DateTime t = DateTime(2026, 6, 15, 13, 30);
      !t.isAfter(sunset.add(const Duration(minutes: 30)));
      t = t.add(const Duration(minutes: 5))
    ) {
      final double d = _at(t, sunrise, sunset).daylight;
      expect(d, lessThanOrEqualTo(previous));
      previous = d;
    }
    expect(previous, 0);
  });

  test('values are continuous and clamped over a whole day', () {
    double? last;
    for (int m = 0; m < 24 * 60; m++) {
      final ({double daylight, double dusk}) v = _at(
        DateTime(2026, 6, 15).add(Duration(minutes: m)),
        sunrise,
        sunset,
      );
      expect(v.daylight, inInclusiveRange(0.0, 1.0));
      expect(v.dusk, inInclusiveRange(0.0, 1.0));
      if (last != null) {
        expect((v.daylight - last).abs(), lessThan(0.05));
      }
      last = v.daylight;
    }
  });

  test('sun times from another day are shifted onto the local day', () {
    final ({double daylight, double dusk}) v = SunClock.at(
      DateTime(2026, 6, 15, 21),
      sunrise: DateTime(2026, 6, 1, 6),
      sunset: DateTime(2026, 6, 1, 21),
    );
    expect(v.dusk, closeTo(1, 1e-6));
  });

  group('month table fallback (45 N, local time)', () {
    test('January noon is day, midnight is night', () {
      expect(
        SunClock.at(DateTime(2026, 1, 15, 12, 40)).daylight,
        closeTo(1, 0.01),
      );
      expect(SunClock.at(DateTime(2026, 1, 15, 0)).daylight, 0);
    });

    test('June stays light at 20:00, January is dark at 20:00', () {
      expect(SunClock.at(DateTime(2026, 6, 15, 20)).daylight, greaterThan(0.8));
      expect(SunClock.at(DateTime(2026, 1, 15, 20)).daylight, 0);
    });

    test('dusk peaks near the June sunset (~21:30)', () {
      expect(SunClock.at(DateTime(2026, 6, 15, 21, 30)).dusk, closeTo(1, 1e-6));
    });

    test('is continuous across month boundaries', () {
      final double a = SunClock.at(DateTime(2026, 6, 30, 21, 30)).daylight;
      final double b = SunClock.at(DateTime(2026, 7, 1, 21, 30)).daylight;
      expect((a - b).abs(), lessThan(0.05));
    });

    test('every month gives clamped values', () {
      for (int month = 1; month <= 12; month++) {
        for (int h = 0; h < 24; h++) {
          final ({double daylight, double dusk}) v = SunClock.at(
            DateTime(2026, month, 28, h),
          );
          expect(v.daylight, inInclusiveRange(0.0, 1.0));
          expect(v.dusk, inInclusiveRange(0.0, 1.0));
        }
      }
    });
  });

  test('a report whose sunset does not follow its sunrise uses the table', () {
    final DateTime noon = DateTime(2026, 5, 25, 12);
    final ({double daylight, double dusk}) polar = SunClock.at(
      noon,
      sunrise: DateTime(2026, 5, 25, 3),
      sunset: DateTime(2026, 5, 26, 0, 30),
    );
    expect(polar, SunClock.at(noon));
    expect(polar.daylight, greaterThan(0.9));
  });
}
