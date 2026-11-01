import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/weather_report.dart';
import 'package:yofardev_ai/core/services/world/world_state_service.dart';

void main() {
  late WorldStateService world;

  setUp(() => world = WorldStateService());
  tearDown(() => world.dispose());

  test('rain defaults to 0', () {
    expect(world.rain.value, 0);
  });

  test('setRain stores a value in 0..1', () {
    world.setRain(0.4);
    expect(world.rain.value, 0.4);
  });

  test('setRain clamps to 0..1', () {
    world.setRain(2);
    expect(world.rain.value, 1);
    world.setRain(-1);
    expect(world.rain.value, 0);
  });

  test('setRain ignores NaN', () {
    world.setRain(0.5);
    world.setRain(double.nan);
    expect(world.rain.value, 0.5);
  });

  test('listeners hear a change once and an unchanged value not at all', () {
    int calls = 0;
    world.rain.addListener(() => calls++);
    world.setRain(0.7);
    world.setRain(0.7);
    expect(calls, 1);
    world.setRain(5);
    world.setRain(1);
    expect(calls, 2);
  });

  group('fog (M8 ruling 13)', () {
    test('defaults to 0; setFog clamps and ignores NaN', () {
      expect(world.fog.value, 0);
      world.setFog(0.4);
      expect(world.fog.value, 0.4);
      world.setFog(3);
      expect(world.fog.value, 1);
      world.setFog(double.nan);
      expect(world.fog.value, 1);
      world.setFog(-1);
      expect(world.fog.value, 0);
    });

    test('an own-location report sets the fog (and clears it)', () {
      world.applyWeather(const WeatherReport(conditionId: 741));
      expect(world.fog.value, 1);
      expect(world.rain.value, 0);
      world.applyWeather(const WeatherReport(conditionId: 701));
      expect(world.fog.value, 0.5);
      world.applyWeather(const WeatherReport(conditionId: 800));
      expect(world.fog.value, 0);
    });
  });
}
