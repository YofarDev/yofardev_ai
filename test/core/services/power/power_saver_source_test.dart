import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/power/power_saver_source.dart';

void main() {
  group('BatteryPowerSaverSource', () {
    test('reads the platform value', () async {
      final BatteryPowerSaverSource source = BatteryPowerSaverSource(
        read: () async => true,
      );
      expect(await source.isOn, isTrue);
      await source.dispose();
    });

    test('an error reads as false', () async {
      final BatteryPowerSaverSource source = BatteryPowerSaverSource(
        read: () async => throw UnimplementedError('no battery'),
      );
      expect(await source.isOn, isFalse);
      await source.dispose();
    });

    test(
      'the real platform channel is absent in tests: false, no throw',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        final BatteryPowerSaverSource source = BatteryPowerSaverSource();
        expect(await source.isOn, isFalse);
        await source.dispose();
      },
    );

    test('changes polls while listened to and emits transitions only', () {
      fakeAsync((FakeAsync async) {
        bool value = false;
        final BatteryPowerSaverSource source = BatteryPowerSaverSource(
          read: () async => value,
          pollInterval: const Duration(seconds: 60),
        );
        final List<bool> seen = <bool>[];
        final StreamSubscription<bool> subscription = source.changes.listen(
          seen.add,
        );

        async.elapse(const Duration(seconds: 61));
        expect(seen, isEmpty, reason: 'still off');
        value = true;
        async.elapse(const Duration(seconds: 60));
        async.elapse(const Duration(seconds: 60));
        expect(seen, <bool>[true]);
        value = false;
        async.elapse(const Duration(seconds: 60));
        expect(seen, <bool>[true, false]);

        subscription.cancel();
        async.flushMicrotasks();
        expect(async.periodicTimerCount, 0);
        source.dispose();
      });
    });
  });
}
