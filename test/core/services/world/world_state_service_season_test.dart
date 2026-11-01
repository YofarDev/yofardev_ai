import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/weather_report.dart';
import 'package:yofardev_ai/core/services/world/world_state_service.dart';

void main() {
  DateTime clock = DateTime(2026, 4, 15, 12);
  late WorldStateService world;

  setUp(() {
    clock = DateTime(2026, 4, 15, 12);
    world = WorldStateService(now: () => clock);
  });
  tearDown(() => world.dispose());

  group('seasons', () {
    test('computed at construction from the local date', () {
      expect(world.spring.value, 1);
      expect(world.autumn.value, 0);
    });

    test('pinClock moves them, unpinning returns to the clock', () {
      world.pinClock(DateTime(2026, 9, 3, 8));
      expect(world.spring.value, 0);
      expect(world.autumn.value, closeTo(3 / 7, 1e-9));
      world.pinClock(DateTime(2026, 12, 24));
      expect(world.autumn.value, 0);
      expect(world.festive.value, 1);
      world.pinClock(null);
      expect(world.spring.value, 1);
      expect(world.autumn.value, 0);
    });

    test('an own-location report south of the equator swaps them; one '
        'without a latitude keeps the hemisphere', () {
      world.applyWeather(const WeatherReport(conditionId: 800, latitude: -34));
      expect(world.spring.value, 0);
      expect(world.autumn.value, 1);
      world.applyWeather(const WeatherReport(conditionId: 800));
      expect(world.autumn.value, 1);
      world.applyWeather(const WeatherReport(conditionId: 800, latitude: 45));
      expect(world.spring.value, 1);
      expect(world.autumn.value, 0);
    });

    test('the minute tick ramps them in day by day; paused, nothing moves', () {
      fakeAsync((FakeAsync async) {
        clock = DateTime(2026, 2, 28, 23, 59, 30);
        final WorldStateService w = WorldStateService(now: () => clock)
          ..start();
        expect(w.spring.value, 0);
        clock = DateTime(2026, 3, 1, 0, 0, 30);
        async.elapse(const Duration(minutes: 1));
        expect(w.spring.value, closeTo(1 / 7, 1e-9));
        w.pause();
        clock = DateTime(2026, 3, 2, 0, 0, 30);
        async.elapse(const Duration(minutes: 5));
        expect(w.spring.value, closeTo(1 / 7, 1e-9), reason: 'paused');
        w.start();
        expect(w.spring.value, closeTo(2 / 7, 1e-9));
        w.dispose();
      });
    });

    test('lab overrides hold a value; null returns to the calendar', () {
      int notified = 0;
      world.autumn.addListener(() => notified++);
      world.setAutumn(0.6);
      expect(world.autumn.value, 0.6);
      expect(notified, 1);
      world.setSpring(0.25);
      expect(world.spring.value, 0.25);
      world.pinClock(DateTime(2026, 6, 10));
      expect(world.spring.value, 0.25, reason: 'held through a pinned date');
      world.setSpring(4);
      expect(world.spring.value, 1, reason: 'clamped');
      world.setSpring(double.nan);
      expect(world.spring.value, 1, reason: 'NaN ignored');
      world.setSpring(null);
      world.setAutumn(null);
      expect(world.spring.value, 0);
      expect(world.autumn.value, 0);
    });
  });

  group('wind', () {
    test('unknown (null) without a report', () {
      expect(world.wind.value, isNull);
    });

    test('an own-location report sets it from wind.speed / 12', () {
      world.applyWeather(const WeatherReport(conditionId: 803, windSpeed: 6));
      expect(world.wind.value, closeTo(0.5, 1e-9));
      world.applyWeather(const WeatherReport(conditionId: 803, windSpeed: 30));
      expect(world.wind.value, 1);
      // a report without the speed: unknown again
      world.applyWeather(const WeatherReport(conditionId: 803));
      expect(world.wind.value, isNull);
    });

    test('setWind (the lab) clamps, null is unknown, NaN is ignored', () {
      int notified = 0;
      world.wind.addListener(() => notified++);
      world.setWind(0.3);
      expect(world.wind.value, 0.3);
      world.setWind(0.3002);
      expect(notified, 1, reason: 'below epsilon');
      world.setWind(-2);
      expect(world.wind.value, 0);
      world.setWind(double.nan);
      expect(world.wind.value, 0);
      world.setWind(null);
      expect(world.wind.value, isNull);
      expect(notified, 3);
    });
  });
}
