import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/weather_report.dart';

WeatherReport _report(int id, {double mm = 0}) =>
    WeatherReport(conditionId: id, rainMmPerHour: mm);

void main() {
  group('rainIntensity per condition', () {
    final Map<int, double> table = <int, double>{
      200: 1.0,
      232: 1.0,
      300: 0.25,
      321: 0.25,
      500: 0.4,
      501: 0.6,
      502: 0.85,
      504: 0.85,
      511: 0.6,
      520: 0.85,
      531: 0.85,
      600: 0,
      622: 0,
      701: 0,
      781: 0,
      800: 0,
      801: 0,
      804: 0,
    };
    table.forEach((int id, double expected) {
      test('$id -> $expected', () {
        expect(_report(id).rainIntensity, closeTo(expected, 1e-9));
      });
    });
  });

  group('rain.1h override', () {
    test('mm / 4 wins when larger than the condition', () {
      expect(_report(500, mm: 3).rainIntensity, closeTo(0.75, 1e-9));
      expect(_report(800, mm: 2).rainIntensity, closeTo(0.5, 1e-9));
    });

    test('the condition wins when larger than mm / 4', () {
      expect(_report(502, mm: 1).rainIntensity, closeTo(0.85, 1e-9));
    });

    test('is clamped to 1', () {
      expect(_report(500, mm: 20).rainIntensity, 1);
    });
  });

  group('fromOpenWeather', () {
    test('parses id, rain.1h and sun times (unix seconds UTC -> local)', () {
      final WeatherReport r = WeatherReport.fromOpenWeather(<String, dynamic>{
        'weather': <dynamic>[
          <String, dynamic>{'id': 501, 'description': 'moderate rain'},
        ],
        'rain': <String, dynamic>{'1h': 2.5},
        'sys': <String, dynamic>{'sunrise': 1700000000, 'sunset': 1700040000},
      });
      expect(r.conditionId, 501);
      expect(r.rainMmPerHour, 2.5);
      expect(
        r.sunrise,
        DateTime.fromMillisecondsSinceEpoch(
          1700000000 * 1000,
          isUtc: true,
        ).toLocal(),
      );
      expect(r.sunrise!.isUtc, isFalse);
      expect(
        r.sunset,
        DateTime.fromMillisecondsSinceEpoch(
          1700040000 * 1000,
          isUtc: true,
        ).toLocal(),
      );
    });

    test('a missing rain object means 0 mm/h; integers are accepted', () {
      final WeatherReport r = WeatherReport.fromOpenWeather(<String, dynamic>{
        'weather': <dynamic>[
          <String, dynamic>{'id': 800},
        ],
        'sys': <String, dynamic>{},
      });
      expect(r.conditionId, 800);
      expect(r.rainMmPerHour, 0);
      expect(r.sunrise, isNull);
      expect(r.sunset, isNull);

      final WeatherReport r2 = WeatherReport.fromOpenWeather(<String, dynamic>{
        'weather': <dynamic>[
          <String, dynamic>{'id': 500},
        ],
        'rain': <String, dynamic>{'1h': 1},
      });
      expect(r2.rainMmPerHour, 1.0);
    });
  });
}
