import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/power/power_saver_source.dart';
import 'package:yofardev_ai/features/avatar/domain/services/idle_ladder.dart';

class _FakePower implements PowerSaverSource {
  bool on = false;
  final StreamController<bool> controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isOn async => on;

  @override
  Stream<bool> get changes => controller.stream;
}

void main() {
  group('IdleLadder', () {
    late DateTime clock;
    late _FakePower power;
    bool reduce = false;

    IdleLadder build() {
      clock = DateTime(2026, 10, 29, 12);
      power = _FakePower();
      reduce = false;
      return IdleLadder(
        now: () => clock,
        power: power,
        reduceMotion: () => reduce,
      );
    }

    void at(IdleLadder ladder, int seconds) {
      clock = DateTime(2026, 10, 29, 12).add(Duration(seconds: seconds));
      ladder.tick();
    }

    test('stages follow the idle time: 29 s 0, 31 s 1, 121 s 2, 601 s 3', () {
      final IdleLadder ladder = build();
      at(ladder, 29);
      expect(ladder.stage, 0);
      at(ladder, 31);
      expect(ladder.stage, 1);
      at(ladder, 121);
      expect(ladder.stage, 2);
      at(ladder, 601);
      expect(ladder.stage, 3);
      ladder.dispose();
    });

    test('exact thresholds: 30 s, 2 min and 10 min', () {
      final IdleLadder ladder = build();
      at(ladder, 30);
      expect(ladder.stage, 1);
      at(ladder, 120);
      expect(ladder.stage, 2);
      at(ladder, 600);
      expect(ladder.stage, 3);
      ladder.dispose();
    });

    test('the threshold scale stretches or shortens every stage', () {
      final IdleLadder ladder = build();
      expect(ladder.thresholdScale, 1);
      ladder.thresholdScale = 0.7;
      at(ladder, 20);
      expect(ladder.stage, 0);
      at(ladder, 21);
      expect(ladder.stage, 1);
      at(ladder, 84);
      expect(ladder.stage, 2);
      at(ladder, 420);
      expect(ladder.stage, 3);
      ladder.onActivity();
      ladder.thresholdScale = 1.4;
      final DateTime from = clock;
      clock = from.add(const Duration(seconds: 41));
      ladder.tick();
      expect(ladder.stage, 0);
      clock = from.add(const Duration(seconds: 42));
      ladder.tick();
      expect(ladder.stage, 1);
      ladder.dispose();
    });

    test('a scale change re-reads the stage at once', () {
      final IdleLadder ladder = build();
      at(ladder, 25);
      expect(ladder.stage, 0);
      ladder.thresholdScale = 0.7;
      expect(ladder.stage, 1);
      ladder.dispose();
    });

    test('activity goes back to 0 and the count starts over', () {
      final IdleLadder ladder = build();
      at(ladder, 700);
      expect(ladder.stage, 3);
      ladder.onActivity();
      expect(ladder.stage, 0);
      clock = clock.add(const Duration(seconds: 29));
      ladder.tick();
      expect(ladder.stage, 0);
      clock = clock.add(const Duration(seconds: 2));
      ladder.tick();
      expect(ladder.stage, 1);
      ladder.dispose();
    });

    test('stages stream emits changes only', () {
      final IdleLadder ladder = build();
      final List<int> seen = <int>[];
      ladder.stages.listen(seen.add);
      return Future<void>.delayed(Duration.zero).then((_) async {
        at(ladder, 10);
        at(ladder, 31);
        at(ladder, 32);
        at(ladder, 121);
        ladder.onActivity();
        ladder.onActivity();
        await Future<void>.delayed(Duration.zero);
        expect(seen, <int>[1, 2, 0]);
        await ladder.dispose();
      });
    });

    test('power saver on keeps the ladder at stage 0', () async {
      final IdleLadder ladder = build();
      power.on = true;
      await ladder.start();
      at(ladder, 700);
      expect(ladder.stage, 0);
      await ladder.dispose();
    });

    test(
      'power saver switching on drops the stage, off lets it climb',
      () async {
        final IdleLadder ladder = build();
        await ladder.start();
        at(ladder, 200);
        expect(ladder.stage, 2);
        power.controller.add(true);
        await Future<void>.delayed(Duration.zero);
        expect(ladder.stage, 0);
        power.controller.add(false);
        await Future<void>.delayed(Duration.zero);
        expect(ladder.stage, 2);
        await ladder.dispose();
      },
    );

    test('reduce motion keeps the ladder at stage 0', () {
      final IdleLadder ladder = build();
      reduce = true;
      at(ladder, 700);
      expect(ladder.stage, 0);
      reduce = false;
      ladder.tick();
      expect(ladder.stage, 3);
      ladder.dispose();
    });

    test('the periodic check climbs the stages by itself', () {
      fakeAsync((FakeAsync async) {
        clock = DateTime(2026, 10, 29, 12);
        power = _FakePower();
        final IdleLadder ladder = IdleLadder(
          now: () => clock,
          power: power,
          reduceMotion: () => false,
        );
        final List<int> seen = <int>[];
        ladder.stages.listen(seen.add);
        ladder.start();
        async.flushMicrotasks();

        for (int s = 0; s < 125; s++) {
          clock = clock.add(const Duration(seconds: 1));
          async.elapse(const Duration(seconds: 1));
        }
        expect(seen, <int>[1, 2]);

        ladder.dispose();
        async.flushMicrotasks();
        expect(async.periodicTimerCount, 0);
      });
    });
  });
}
