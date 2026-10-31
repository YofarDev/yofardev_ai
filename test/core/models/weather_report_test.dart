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

  group('temperature (M8 tablet card)', () {
    test('main.temp is parsed in °C', () {
      final WeatherReport r = WeatherReport.fromOpenWeather(<String, dynamic>{
        'weather': <dynamic>[
          <String, dynamic>{'id': 500},
        ],
        'main': <String, dynamic>{'temp': 18.4},
      });
      expect(r.temperatureC, 18.4);
      final WeatherReport r2 = WeatherReport.fromOpenWeather(<String, dynamic>{
        'weather': <dynamic>[
          <String, dynamic>{'id': 800},
        ],
        'main': <String, dynamic>{'temp': -3},
      });
      expect(r2.temperatureC, -3.0);
    });

    test('no main object: no temperature', () {
      final WeatherReport r = WeatherReport.fromOpenWeather(<String, dynamic>{
        'weather': <dynamic>[
          <String, dynamic>{'id': 800},
        ],
      });
      expect(r.temperatureC, isNull);
    });
  });

  group('fogIntensity per condition (M8 ruling 13)', () {
    final Map<int, double> table = <int, double>{
      701: 0.5,
      711: 0.3,
      721: 0.35,
      731: 0.25,
      741: 1.0,
      751: 0.25,
      761: 0.25,
      762: 0,
      771: 0,
      781: 0,
      500: 0,
      800: 0,
      804: 0,
    };
    table.forEach((int id, double expected) {
      test('$id -> $expected', () {
        expect(
          WeatherReport(conditionId: id).fogIntensity,
          closeTo(expected, 1e-9),
        );
      });
    });
  });

  group('latitude', () {
    Map<String, dynamic> body(Map<String, dynamic> extra) => <String, dynamic>{
      'weather': <Map<String, dynamic>>[
        <String, dynamic>{'id': 800},
      ],
      ...extra,
    };

    test('is read from coord.lat (negative south)', () {
      expect(
        WeatherReport.fromOpenWeather(
          body(<String, dynamic>{
            'coord': <String, dynamic>{'lon': 151.2, 'lat': -33.87},
          }),
        ).latitude,
        closeTo(-33.87, 1e-9),
      );
      expect(
        WeatherReport.fromOpenWeather(
          body(<String, dynamic>{
            'coord': <String, dynamic>{'lon': 2.3, 'lat': 48},
          }),
        ).latitude,
        48,
      );
    });

    test('is null without coord', () {
      expect(
        WeatherReport.fromOpenWeather(body(<String, dynamic>{})).latitude,
        isNull,
      );
    });
  });

  group('wind (M11 ruling 11)', () {
    Map<String, dynamic> body(Map<String, dynamic> extra) => <String, dynamic>{
      'weather': <Map<String, dynamic>>[
        <String, dynamic>{'id': 803},
      ],
      ...extra,
    };

    test('wind.speed (m/s, units=metric) is parsed; ints are accepted', () {
      // the shape of a real OpenWeather 2.5 /weather answer
      final WeatherReport r = WeatherReport.fromOpenWeather(<String, dynamic>{
        'coord': <String, dynamic>{'lon': 2.35, 'lat': 48.85},
        'weather': <Map<String, dynamic>>[
          <String, dynamic>{'id': 803, 'main': 'Clouds'},
        ],
        'main': <String, dynamic>{'temp': 11.2, 'humidity': 81},
        'wind': <String, dynamic>{'speed': 6.17, 'deg': 230, 'gust': 11.3},
        'sys': <String, dynamic>{'sunrise': 1700000000, 'sunset': 1700040000},
      });
      expect(r.windSpeed, closeTo(6.17, 1e-9));
      expect(
        WeatherReport.fromOpenWeather(
          body(<String, dynamic>{
            'wind': <String, dynamic>{'speed': 3},
          }),
        ).windSpeed,
        3.0,
      );
    });

    test('no wind object, no speed or a non-number: unknown', () {
      expect(
        WeatherReport.fromOpenWeather(body(<String, dynamic>{})).windSpeed,
        isNull,
      );
      expect(
        WeatherReport.fromOpenWeather(
          body(<String, dynamic>{
            'wind': <String, dynamic>{'deg': 90},
          }),
        ).windSpeed,
        isNull,
      );
      expect(
        WeatherReport.fromOpenWeather(
          body(<String, dynamic>{'wind': 'calm'}),
        ).windSpeed,
        isNull,
      );
      expect(const WeatherReport(conditionId: 800).windIntensity, isNull);
    });

    test('windIntensity = clamp(speed / 12, 0, 1)', () {
      final Map<double, double> table = <double, double>{
        0: 0,
        3: 0.25,
        6: 0.5,
        9: 0.75,
        12: 1,
        20: 1,
        -1: 0,
      };
      table.forEach((double speed, double expected) {
        expect(
          WeatherReport(conditionId: 800, windSpeed: speed).windIntensity,
          closeTo(expected, 1e-9),
          reason: '$speed m/s',
        );
      });
      expect(
        const WeatherReport(
          conditionId: 800,
          windSpeed: double.nan,
        ).windIntensity,
        isNull,
      );
    });
  });
}
