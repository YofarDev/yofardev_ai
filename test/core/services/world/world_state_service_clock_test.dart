import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/weather_report.dart';
import 'package:yofardev_ai/core/services/world/world_state_service.dart';

void main() {
  DateTime clock = DateTime(2026, 6, 15, 13, 40);
  late WorldStateService world;

  setUp(() {
    clock = DateTime(2026, 6, 15, 13, 40);
    world = WorldStateService(now: () => clock);
  });
  tearDown(() => world.dispose());

  test('the clock values are computed at construction', () {
    expect(world.daylight.value, closeTo(1, 0.01));
    expect(world.dusk.value, 0);
  });

  test('applyWeather sets the rain and the sun times', () {
    clock = DateTime(2026, 6, 15, 18);
    world.start();
    final double before = world.daylight.value;
    expect(before, greaterThan(0.8));

    // A sun that set at 17:00: it is already dark-ish at 18:00.
    world.applyWeather(
      WeatherReport(
        conditionId: 502,
        sunrise: DateTime(2026, 6, 15, 4),
        sunset: DateTime(2026, 6, 15, 17),
      ),
    );
    expect(world.rain.value, closeTo(0.85, 1e-9));
    expect(world.daylight.value, lessThan(before));
    expect(world.daylight.value, 0);
    expect(world.dusk.value, inInclusiveRange(0.0, 1.0));
    world.pause();
  });

  test('applyWeather without sun times keeps the table', () {
    world.applyWeather(const WeatherReport(conditionId: 800));
    expect(world.rain.value, 0);
    expect(world.daylight.value, closeTo(1, 0.01));
  });

  test('pinClock fixes the clock, null returns to now()', () {
    world.pinClock(DateTime(2026, 6, 15, 0));
    expect(world.daylight.value, 0);
    clock = DateTime(2026, 6, 15, 3);
    expect(world.daylight.value, 0);
    world.pinClock(DateTime(2026, 6, 15, 21, 30));
    expect(world.dusk.value, closeTo(1, 0.01));
    clock = DateTime(2026, 6, 15, 13, 40);
    world.pinClock(null);
    expect(world.daylight.value, closeTo(1, 0.01));
    expect(world.dusk.value, 0);
  });

  test('the minute timer recomputes; pause stops it', () {
    fakeAsync((FakeAsync async) {
      clock = DateTime(2026, 6, 15, 13, 40);
      final WorldStateService w = WorldStateService(now: () => clock);
      w.start();
      expect(w.daylight.value, closeTo(1, 0.01));

      clock = DateTime(2026, 6, 15, 23);
      async.elapse(const Duration(seconds: 59));
      expect(w.daylight.value, closeTo(1, 0.01));
      async.elapse(const Duration(seconds: 2));
      expect(w.daylight.value, 0);

      w.pause();
      clock = DateTime(2026, 6, 15, 13, 40);
      async.elapse(const Duration(minutes: 5));
      expect(w.daylight.value, 0);

      w.start();
      expect(w.daylight.value, closeTo(1, 0.01));
      w.dispose();
    });
  });

  test('start twice does not stack timers', () {
    fakeAsync((FakeAsync async) {
      final WorldStateService w = WorldStateService(now: () => clock);
      int calls = 0;
      w.start();
      w.start();
      w.daylight.addListener(() => calls++);
      clock = DateTime(2026, 6, 15, 23);
      async.elapse(const Duration(minutes: 1));
      expect(calls, 1);
      w.dispose();
    });
  });

  test('no notification for a change under 0.001', () {
    int calls = 0;
    world.daylight.addListener(() => calls++);
    world.pinClock(DateTime(2026, 6, 15, 13, 40));
    world.pinClock(DateTime(2026, 6, 15, 13, 41));
    expect(calls, 0);
    world.pinClock(DateTime(2026, 6, 15, 0));
    expect(calls, 1);
  });

  test('dispose cancels the timer', () {
    fakeAsync((FakeAsync async) {
      final WorldStateService w = WorldStateService(now: () => clock);
      w.start();
      w.dispose();
      expect(async.pendingTimers, isEmpty);
    });
  });
}
