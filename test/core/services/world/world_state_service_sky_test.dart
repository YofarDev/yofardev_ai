import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/weather_report.dart';
import 'package:yofardev_ai/core/services/world/sky_calendar.dart';
import 'package:yofardev_ai/core/services/world/world_state_service.dart';

void main() {
  DateTime clock = DateTime(2026, 10, 26, 22);
  late WorldStateService world;

  setUp(() {
    clock = DateTime(2026, 10, 26, 22);
    world = WorldStateService(now: () => clock);
  });
  tearDown(() => world.dispose());

  test('the sky is computed at construction', () {
    expect(world.moonPhase.value, closeTo(0.5, 1 / 29.53));
    expect(world.festive.value, 0);
    expect(world.localDay.value, DateTime(2026, 10, 26));
  });

  test('the moon follows the calendar, pinClock pins it', () {
    world.pinClock(DateTime(2026, 11, 24, 21));
    expect(world.moonPhase.value, closeTo(0.5, 1 / 29.53));
    world.pinClock(DateTime(2026, 12, 9, 21));
    expect(world.moonPhase.value, lessThan(0.05));
    expect(world.localDay.value, DateTime(2026, 12, 9));
    world.pinClock(null);
    expect(world.localDay.value, DateTime(2026, 10, 26));
  });

  test('festive is 1 from 1 Dec to 6 Jan and pinClock moves it', () {
    world.pinClock(DateTime(2026, 11, 30, 23, 59));
    expect(world.festive.value, 0);
    world.pinClock(DateTime(2026, 12, 1));
    expect(world.festive.value, 1);
    world.pinClock(DateTime(2027, 1, 6, 23, 59));
    expect(world.festive.value, 1);
    world.pinClock(DateTime(2027, 1, 7));
    expect(world.festive.value, 0);
  });

  test('an own-location report south of the equator mirrors the moon', () {
    final double north = world.moonPhase.value;
    world.applyWeather(const WeatherReport(conditionId: 800, latitude: -33.9));
    expect(world.moonPhase.value, closeTo(1 - north, 0.002));
    expect(
      world.moonPhase.value,
      closeTo(SkyCalendar.moonPhase(clock, southern: true), 0.002),
    );
    world.applyWeather(const WeatherReport(conditionId: 800, latitude: 48.8));
    expect(world.moonPhase.value, closeTo(north, 0.002));
  });

  test('a report without a latitude keeps the last hemisphere', () {
    final double north = world.moonPhase.value;
    world.applyWeather(const WeatherReport(conditionId: 800, latitude: -10));
    world.applyWeather(const WeatherReport(conditionId: 800));
    expect(world.moonPhase.value, closeTo(1 - north, 0.002));
  });

  test('the minute tick rolls the calendar over midnight', () {
    fakeAsync((FakeAsync async) {
      clock = DateTime(2026, 12, 31, 23, 59, 30);
      final WorldStateService w = WorldStateService(now: () => clock);
      w.start();
      expect(w.festive.value, 1);
      expect(w.localDay.value, DateTime(2026, 12, 31));

      clock = DateTime(2027, 1, 1, 0, 0, 30);
      async.elapse(const Duration(minutes: 1));
      expect(w.festive.value, 1, reason: '1 January is still festive');
      expect(w.localDay.value, DateTime(2027, 1, 1));

      clock = DateTime(2027, 1, 7, 0, 5);
      async.elapse(const Duration(minutes: 1));
      expect(w.festive.value, 0);
      w.dispose();
    });
  });

  test('the moon notifies on a real change only, and across a new moon', () {
    int calls = 0;
    world.moonPhase.addListener(() => calls++);
    world.pinClock(DateTime(2026, 10, 26, 22, 1));
    expect(calls, 0, reason: 'a minute moves the moon by 2e-5');
    world.pinClock(DateTime(2026, 11, 3));
    expect(calls, 1);
  });

  test('setMoonPhase / setFestive hold hand-set values over the tick', () {
    fakeAsync((FakeAsync async) {
      final WorldStateService w = WorldStateService(now: () => clock);
      w.start();
      w.setMoonPhase(0.25);
      w.setFestive(1);
      async.elapse(const Duration(minutes: 3));
      expect(w.moonPhase.value, 0.25);
      expect(w.festive.value, 1);

      w.setMoonPhase(-5);
      expect(w.moonPhase.value, -1, reason: 'below 0 = as drawn');
      w.setMoonPhase(7);
      expect(w.moonPhase.value, 1);
      w.setMoonPhase(double.nan);
      expect(w.moonPhase.value, 1);

      w.setMoonPhase(null);
      w.setFestive(null);
      expect(w.moonPhase.value, closeTo(0.5, 1 / 29.53));
      expect(w.festive.value, 0);
      w.dispose();
    });
  });

  test('localNow is the pinned time, else the clock', () {
    expect(world.localNow, clock);
    world.pinClock(DateTime(2026, 12, 24, 20));
    expect(world.localNow, DateTime(2026, 12, 24, 20));
  });
}
