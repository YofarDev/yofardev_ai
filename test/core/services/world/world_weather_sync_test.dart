import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/weather_report.dart';
import 'package:yofardev_ai/core/services/power/power_saver_source.dart';
import 'package:yofardev_ai/core/services/world/world_state_service.dart';
import 'package:yofardev_ai/core/services/world/world_weather_sync.dart';

class _FakePower implements PowerSaverSource {
  _FakePower(this.on);
  bool on;
  @override
  Future<bool> get isOn async => on;
  @override
  Stream<bool> get changes => const Stream<bool>.empty();
}

void main() {
  late WorldStateService world;
  late _FakePower power;
  String? key;
  bool permission = true;
  int fetches = 0;
  int permissionChecks = 0;
  String? lastKey;
  WeatherReport? next;

  WorldWeatherSync build() => WorldWeatherSync(
    world: world,
    power: power,
    readApiKey: () async => key,
    hasLocationPermission: () async {
      permissionChecks++;
      return permission;
    },
    fetchOwnLocation: (String k) async {
      fetches++;
      lastKey = k;
      return next;
    },
  );

  setUp(() {
    world = WorldStateService(now: () => DateTime(2026, 6, 15, 12));
    power = _FakePower(false);
    key = 'k';
    permission = true;
    fetches = 0;
    permissionChecks = 0;
    lastKey = null;
    next = const WeatherReport(conditionId: 502);
  });
  tearDown(() => world.dispose());

  test('fetches once on start and applies the report', () {
    fakeAsync((FakeAsync async) {
      final WorldWeatherSync sync = build()..start();
      async.flushMicrotasks();
      expect(fetches, 1);
      expect(lastKey, 'k');
      expect(world.rain.value, closeTo(0.85, 1e-9));
      sync.dispose();
    });
  });

  test('a quick pause and resume does not fetch again', () {
    fakeAsync((FakeAsync async) {
      final WorldWeatherSync sync = build()..start();
      async.flushMicrotasks();
      sync.pause();
      sync.start();
      async.flushMicrotasks();
      expect(fetches, 1);
      sync.dispose();
    });
  });

  test('a failed fetch does not hold off the next resume', () {
    fakeAsync((FakeAsync async) {
      next = null;
      final WorldWeatherSync sync = build()..start();
      async.flushMicrotasks();
      sync.pause();
      sync.start();
      async.flushMicrotasks();
      expect(fetches, 2);
      sync.dispose();
    });
  });

  test('every 30 minutes while active, not after pause', () {
    fakeAsync((FakeAsync async) {
      final WorldWeatherSync sync = build()..start();
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 29));
      expect(fetches, 1);
      async.elapse(const Duration(minutes: 1));
      expect(fetches, 2);
      async.elapse(const Duration(minutes: 60));
      expect(fetches, 4);
      sync.pause();
      async.elapse(const Duration(hours: 3));
      expect(fetches, 4);
      sync.dispose();
    });
  });

  test('never fetches without a key (null or empty)', () {
    fakeAsync((FakeAsync async) {
      key = null;
      final WorldWeatherSync sync = build()..start();
      async.elapse(const Duration(hours: 2));
      key = '';
      async.elapse(const Duration(hours: 2));
      expect(fetches, 0);
      expect(permissionChecks, 0);
      sync.dispose();
    });
  });

  test('never fetches without an already granted permission', () {
    fakeAsync((FakeAsync async) {
      permission = false;
      final WorldWeatherSync sync = build()..start();
      async.elapse(const Duration(hours: 2));
      expect(fetches, 0);
      expect(permissionChecks, greaterThan(0));
      sync.dispose();
    });
  });

  test('never fetches with battery saver on, resumes when it is off', () {
    fakeAsync((FakeAsync async) {
      power.on = true;
      final WorldWeatherSync sync = build()..start();
      async.elapse(const Duration(hours: 2));
      expect(fetches, 0);
      power.on = false;
      async.elapse(const Duration(minutes: 30));
      expect(fetches, 1);
      sync.dispose();
    });
  });

  test('a null report (failed fetch) leaves the world alone', () {
    fakeAsync((FakeAsync async) {
      next = null;
      world.setRain(0.3);
      final WorldWeatherSync sync = build()..start();
      async.flushMicrotasks();
      expect(fetches, 1);
      expect(world.rain.value, 0.3);
      sync.dispose();
    });
  });

  test('a throwing dependency does not break later refreshes', () {
    fakeAsync((FakeAsync async) {
      int reads = 0;
      final WorldWeatherSync sync = WorldWeatherSync(
        world: world,
        power: power,
        readApiKey: () async {
          reads++;
          if (reads == 1) {
            throw StateError('boom');
          }
          return 'k';
        },
        hasLocationPermission: () async => true,
        fetchOwnLocation: (String k) async {
          fetches++;
          return next;
        },
      )..start();
      async.flushMicrotasks();
      expect(fetches, 0);
      async.elapse(const Duration(minutes: 30));
      expect(fetches, 1);
      sync.dispose();
    });
  });

  test('does nothing before start', () {
    fakeAsync((FakeAsync async) {
      final WorldWeatherSync sync = build();
      async.elapse(const Duration(hours: 2));
      expect(fetches, 0);
      sync.dispose();
    });
  });
}
