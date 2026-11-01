import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/performance/performance.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';

void main() {
  group('TabletWeather.fromCondition (M8 ruling 14)', () {
    final Map<int, TabletWeather> table = <int, TabletWeather>{
      200: TabletWeather.storm,
      232: TabletWeather.storm,
      300: TabletWeather.rain,
      321: TabletWeather.rain,
      500: TabletWeather.rain,
      531: TabletWeather.rain,
      600: TabletWeather.snow,
      622: TabletWeather.snow,
      701: TabletWeather.fog,
      741: TabletWeather.fog,
      781: TabletWeather.fog,
      800: TabletWeather.clear,
      801: TabletWeather.clouds,
      804: TabletWeather.clouds,
      100: TabletWeather.none,
      900: TabletWeather.none,
    };
    table.forEach((int id, TabletWeather glyph) {
      test('$id -> ${glyph.name}', () {
        expect(TabletWeather.fromCondition(id), glyph);
      });
    });
  });

  test('the glyph names match the contract enum in order', () {
    expect(
      TabletWeather.values.map((TabletWeather w) => w.name).toList(),
      AvatarRiveContract.tabletWeatherValues,
    );
  });

  group('TabletWeatherReading', () {
    test('rounds the temperature and clamps it to −40..50', () {
      TabletWeatherReading r(double t) =>
          TabletWeatherReading(conditionId: 800, temperatureC: t);
      expect(r(18.4).roundedTemp, 18);
      expect(r(18.5).roundedTemp, 19);
      expect(r(-3.6).roundedTemp, -4);
      expect(r(-60).roundedTemp, -40);
      expect(r(70).roundedTemp, 50);
      expect(r(double.nan).roundedTemp, 0);
    });

    test('its glyph follows the condition', () {
      expect(
        const TabletWeatherReading(conditionId: 501, temperatureC: 18).glyph,
        TabletWeather.rain,
      );
    });
  });
}
