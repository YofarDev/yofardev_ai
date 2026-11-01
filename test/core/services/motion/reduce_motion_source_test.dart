import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/motion/reduce_motion_source.dart';

/// M11 ruling 18: the system's reduce-motion switch is followed live, not
/// read once at startup.
void main() {
  test('set notifies on a change only', () {
    final ReduceMotionSource source = ReduceMotionSource();
    addTearDown(source.dispose);
    int notified = 0;
    source.addListener(() => notified++);
    expect(source.value, isFalse);
    source.set(false);
    expect(notified, 0);
    source.set(true);
    expect(source.value, isTrue);
    expect(notified, 1);
    source.set(true);
    expect(notified, 1);
  });

  testWidgets('the platform source follows the accessibility features live', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final ReduceMotionSource source = ReduceMotionSource.platform(
      binding: tester.binding,
      dispatcher: tester.platformDispatcher,
    );
    addTearDown(source.dispose);
    final List<bool> heard = <bool>[];
    source.addListener(() => heard.add(source.value));
    expect(source.value, isFalse);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pump();
    expect(source.value, isTrue);
    expect(heard, <bool>[true]);

    // another feature changing alone is no reduce-motion change
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          disableAnimations: true,
          highContrast: true,
        );
    await tester.pump();
    expect(heard, <bool>[true]);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    await tester.pump();
    expect(source.value, isFalse);
    expect(heard, <bool>[true, false]);
  });

  testWidgets('a disposed platform source stops listening', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final ReduceMotionSource source = ReduceMotionSource.platform(
      binding: tester.binding,
      dispatcher: tester.platformDispatcher,
    );
    source.dispose();
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('it starts from the flag already set', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final ReduceMotionSource source = ReduceMotionSource.platform(
      binding: tester.binding,
      dispatcher: tester.platformDispatcher,
    );
    addTearDown(source.dispose);
    expect(source.value, isTrue);
    // the widgets read the same flag
    late bool widgetFlag;
    await tester.pumpWidget(
      Builder(
        builder: (BuildContext context) {
          widgetFlag = MediaQuery.disableAnimationsOf(context);
          return const SizedBox();
        },
      ),
    );
    expect(widgetFlag, isTrue);
  });
}
