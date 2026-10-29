import 'package:flutter_test/flutter_test.dart';
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
}
