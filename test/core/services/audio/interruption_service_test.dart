import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';

void main() {
  group('InterruptionService', () {
    late InterruptionService service;

    setUp(() {
      service = InterruptionService();
    });

    tearDown(() {
      service.dispose();
    });

    test('should not be interrupted initially', () {
      expect(service.isInterrupted, false);
    });

    test(
      'should broadcast interruption event when interrupt() is called',
      () async {
        final List<void> events = <void>[];
        final StreamSubscription<void> subscription = service.interruptionStream
            .listen(events.add);

        await service.interrupt();

        expect(events.length, 1);
        expect(service.isInterrupted, true);

        await subscription.cancel();
      },
    );

    test('should reset interruption state when reset() is called', () async {
      await service.interrupt();
      expect(service.isInterrupted, true);

      service.reset();
      expect(service.isInterrupted, false);
    });

    test('should handle multiple interruptions gracefully', () async {
      final List<void> events = <void>[];
      final StreamSubscription<void> subscription = service.interruptionStream
          .listen(events.add);

      await service.interrupt();
      await service.interrupt();
      await service.interrupt();

      expect(events.length, 3);
      expect(service.isInterrupted, true);

      await subscription.cancel();
    });
  });
}
