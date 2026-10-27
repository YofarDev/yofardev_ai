import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/rive/artboard_activity.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit_artboard.dart';

const Duration _settle = UiKitArtboard.defaultSettle;

void main() {
  late List<bool> calls;
  late ArtboardActivity activity;

  setUp(() {
    calls = <bool>[];
    activity = ArtboardActivity(onActiveChanged: calls.add);
  });

  tearDown(() => activity.dispose());

  test('a static artboard runs after a wake, then pauses once settled', () {
    fakeAsync((FakeAsync async) {
      activity.wake(ambient: false, settle: _settle);
      expect(activity.running, isTrue);
      expect(calls, <bool>[true]);

      async.elapse(_settle - const Duration(milliseconds: 1));
      expect(activity.running, isTrue);
      async.elapse(const Duration(milliseconds: 1));
      expect(activity.running, isFalse);
      expect(calls, <bool>[true, false]);
    });
  });

  test('a new wake reactivates and restarts the settle delay', () {
    fakeAsync((FakeAsync async) {
      activity.wake(ambient: false, settle: _settle);
      async.elapse(const Duration(milliseconds: 600));
      activity.wake(ambient: false, settle: _settle);
      async.elapse(const Duration(milliseconds: 600));
      expect(activity.running, isTrue, reason: 'the delay restarted');
      async.elapse(const Duration(milliseconds: 100));
      expect(activity.running, isFalse);

      activity.wake(ambient: false, settle: _settle);
      expect(activity.running, isTrue);
      expect(calls, <bool>[true, false, true]);
      async.elapse(_settle);
      expect(calls, <bool>[true, false, true, false]);
    });
  });

  test('an ambient artboard keeps running; leaving ambient settles', () {
    fakeAsync((FakeAsync async) {
      activity.wake(ambient: true, settle: _settle);
      async.elapse(const Duration(minutes: 1));
      expect(activity.running, isTrue);
      expect(calls, <bool>[true]);

      activity.wake(ambient: false, settle: _settle);
      expect(activity.running, isTrue);
      async.elapse(_settle);
      expect(activity.running, isFalse);
      expect(calls, <bool>[true, false]);
    });
  });

  test('a custom settle (the mark sting) runs for its own length', () {
    fakeAsync((FakeAsync async) {
      activity.wake(ambient: false, settle: const Duration(seconds: 2));
      async.elapse(const Duration(milliseconds: 1999));
      expect(activity.running, isTrue);
      async.elapse(const Duration(milliseconds: 1));
      expect(activity.running, isFalse);
    });
  });

  test('a paused app always wins, and resuming restores the rule', () {
    fakeAsync((FakeAsync async) {
      activity.wake(ambient: true, settle: _settle);
      activity.appResumed = false;
      expect(activity.running, isFalse);
      activity.wake(ambient: true, settle: _settle);
      expect(activity.running, isFalse, reason: 'a wake does not override');

      activity.appResumed = true;
      expect(activity.running, isTrue);
      expect(calls, <bool>[true, false, true]);

      // Paused while settling: the settle still ends while paused.
      activity.wake(ambient: false, settle: _settle);
      activity.appResumed = false;
      async.elapse(_settle);
      activity.appResumed = true;
      expect(activity.running, isFalse);
    });
  });

  test('dispose cancels the settle timer', () {
    fakeAsync((FakeAsync async) {
      activity.wake(ambient: false, settle: _settle);
      activity.dispose();
      async.elapse(_settle * 2);
      expect(calls, <bool>[true]);
      expect(async.pendingTimers, isEmpty);
    });
  });
}
