import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart' show AccelerometerEvent;
import 'package:yofardev_ai/core/services/motion/parallax_source.dart';
import 'package:yofardev_ai/core/services/power/power_saver_source.dart';

class _FakePower implements PowerSaverSource {
  _FakePower() : on = false;

  bool on;
  final StreamController<bool> controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isOn async => on;

  @override
  Stream<bool> get changes => controller.stream;
}

final DateTime _t0 = DateTime(2026, 10, 29);

AccelerometerEvent _event(double x, double z, int ms) =>
    AccelerometerEvent(x, 9.7, z, _t0.add(Duration(milliseconds: ms)));

void main() {
  late _FakePower power;
  late bool reduceMotion;
  late StreamController<AccelerometerEvent> accel;
  late List<Offset> seen;
  ParallaxSource? source;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  ParallaxSource build({bool withAccel = true}) {
    final ParallaxSource s = ParallaxSource(
      accel: withAccel ? accel.stream : null,
      reduceMotion: () => reduceMotion,
      power: power,
    );
    s.values.listen(seen.add);
    source = s;
    return s;
  }

  setUp(() {
    power = _FakePower();
    reduceMotion = false;
    accel = StreamController<AccelerometerEvent>();
    seen = <Offset>[];
  });

  tearDown(() async {
    await source?.dispose();
    // Never listened to in some tests: close() would not complete.
    unawaited(accel.close());
  });

  group('without an accelerometer', () {
    test('the pointer drives the offset, clamped to -1..1', () async {
      final ParallaxSource s = build(withAccel: false);
      expect(s.usesAccelerometer, isFalse);
      s.pointer(const Offset(0.5, -0.25));
      s.pointer(const Offset(3, -9));
      await settle();
      expect(seen, <Offset>[const Offset(0.5, -0.25), const Offset(1, -1)]);
      expect(s.value, const Offset(1, -1));
    });

    test('a pointer that leaves the stage returns to 0', () async {
      final ParallaxSource s = build(withAccel: false);
      s.pointer(const Offset(0.4, 0.4));
      s.pointer(Offset.zero);
      await settle();
      expect(seen.last, Offset.zero);
    });

    test('moves under the epsilon are not emitted', () async {
      final ParallaxSource s = build(withAccel: false);
      s.pointer(const Offset(0.5, 0));
      s.pointer(const Offset(0.5005, 0));
      await settle();
      expect(seen, hasLength(1));
    });
  });

  group('with an accelerometer', () {
    test('held still it stays at 0 and ignores the pointer', () async {
      final ParallaxSource s = build();
      for (int i = 0; i < 10; i++) {
        accel.add(_event(0, 0.2, i * 20));
      }
      s.pointer(const Offset(0.9, 0.9));
      await settle();
      expect(s.usesAccelerometer, isTrue);
      expect(s.value, Offset.zero);
      expect(seen, isEmpty);
    });

    test(
      'tilting the right edge down moves x up, the top back moves y',
      () async {
        final ParallaxSource s = build();
        accel.add(_event(0, 0.2, 0));
        for (int i = 1; i <= 30; i++) {
          accel.add(_event(-2.5, 0.2, i * 20)); // right edge down
        }
        await settle();
        expect(s.value.dx, greaterThan(0.5));
        expect(s.value.dy.abs(), lessThan(0.1));
        for (int i = 31; i <= 70; i++) {
          accel.add(_event(0, 3.0, i * 20)); // top away from the viewer
        }
        await settle();
        expect(s.value.dy, greaterThan(0.5));
        expect(s.value.dx.abs(), lessThan(0.1));
      },
    );

    test('a big tilt is clamped to 1', () async {
      final ParallaxSource s = build();
      accel.add(_event(0, 0, 0));
      for (int i = 1; i <= 40; i++) {
        accel.add(_event(-9, 0, i * 20));
      }
      await settle();
      expect(s.value.dx, 1);
    });

    test('the rest pose slowly re-centres under a held tilt', () async {
      final ParallaxSource s = build();
      accel.add(_event(0, 0, 0));
      for (int i = 1; i <= 30; i++) {
        accel.add(_event(-3, 0, i * 20));
      }
      await settle();
      final double early = s.value.dx;
      expect(early, greaterThan(0.5));
      // Thirty seconds holding the same pose.
      for (int i = 1; i <= 60; i++) {
        accel.add(_event(-3, 0, 600 + i * 500));
      }
      await settle();
      expect(s.value.dx.abs(), lessThan(0.05));
    });

    test(
      'a stream error reads 0, is logged, and the pointer takes over',
      () async {
        final List<String?> logs = <String?>[];
        final DebugPrintCallback saved = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) => logs.add(message);
        addTearDown(() => debugPrint = saved);

        final ParallaxSource s = build();
        accel.add(_event(0, 0, 0));
        for (int i = 1; i <= 20; i++) {
          accel.add(_event(-3, 0, i * 20));
        }
        await settle();
        expect(s.value.dx, greaterThan(0.5));

        accel.addError(StateError('sensor gone'));
        await settle();
        expect(s.value, Offset.zero);
        expect(s.usesAccelerometer, isFalse);
        expect(seen.last, Offset.zero);
        expect(
          logs.where((String? l) => l!.contains('ParallaxSource')),
          isNotEmpty,
        );

        // Never throws, and falls back to the pointer.
        s.pointer(const Offset(0.3, 0));
        await settle();
        expect(s.value, const Offset(0.3, 0));
      },
    );

    test('a stream that ends falls back to the pointer', () async {
      final ParallaxSource s = build();
      await accel.close();
      await settle();
      expect(s.usesAccelerometer, isFalse);
      s.pointer(const Offset(0.2, 0.2));
      await settle();
      expect(s.value, const Offset(0.2, 0.2));
    });
  });

  group('reduce motion and battery saver', () {
    test('reduce motion reads 0 (pointer)', () async {
      final ParallaxSource s = build(withAccel: false);
      reduceMotion = true;
      s.pointer(const Offset(0.8, 0.8));
      await settle();
      expect(s.value, Offset.zero);
      expect(seen, isEmpty);
    });

    test('reduce motion reads 0 (tilt)', () async {
      final ParallaxSource s = build();
      reduceMotion = true;
      accel.add(_event(0, 0, 0));
      for (int i = 1; i <= 20; i++) {
        accel.add(_event(-3, 0, i * 20));
      }
      await settle();
      expect(s.value, Offset.zero);
    });

    test('battery saver already on at start reads 0', () async {
      power.on = true;
      final ParallaxSource s = build(withAccel: false);
      await settle();
      s.pointer(const Offset(0.8, 0.8));
      await settle();
      expect(s.value, Offset.zero);
    });

    test(
      'battery saver switching on zeroes the offset, off restores it',
      () async {
        final ParallaxSource s = build(withAccel: false);
        s.pointer(const Offset(0.6, 0.1));
        await settle();
        expect(s.value, const Offset(0.6, 0.1));
        power.controller.add(true);
        await settle();
        expect(s.value, Offset.zero);
        power.controller.add(false);
        await settle();
        expect(s.value, const Offset(0.6, 0.1));
      },
    );
  });
}
