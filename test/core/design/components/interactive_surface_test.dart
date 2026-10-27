import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yofardev_ai/core/design/components/interactive_surface.dart';

import 'component_test_harness.dart';

void main() {
  late InteractiveStates last;
  int taps = 0;

  setUp(() {
    last = (hovered: false, pressed: false, focused: false);
    taps = 0;
  });

  Widget surface({required bool enabled}) {
    return componentHarness(
      InteractiveSurface(
        onTap: enabled ? () => taps++ : null,
        builder: (BuildContext context, InteractiveStates states) {
          last = states;
          return const SizedBox(width: 100, height: 100);
        },
      ),
    );
  }

  group('InteractiveSurface', () {
    testWidgets('tap fires once and pressed is true only while down', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(surface(enabled: true));
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(InteractiveSurface)),
      );
      await tester.pump();
      expect(last.pressed, isTrue);
      expect(taps, 0);

      await gesture.up();
      await tester.pump();
      expect(last.pressed, isFalse);
      expect(taps, 1);
    });

    testWidgets('cancelling the gesture clears pressed without a tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(surface(enabled: true));
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(InteractiveSurface)),
      );
      await tester.pump();
      expect(last.pressed, isTrue);

      await gesture.moveBy(const Offset(0, 300));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(last.pressed, isFalse);
      expect(taps, 0);
    });

    testWidgets('mouse hover sets and clears hovered', (
      WidgetTester tester,
    ) async {
      // Hover highlights are only shown in the "traditional" (pointer and
      // keyboard) focus mode, which the test platform does not select itself.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await tester.pumpWidget(surface(enabled: true));
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(1, 1));
      addTearDown(mouse.removePointer);

      await mouse.moveTo(tester.getCenter(find.byType(InteractiveSurface)));
      await tester.pump();
      expect(last.hovered, isTrue);

      await mouse.moveTo(const Offset(1, 1));
      await tester.pump();
      expect(last.hovered, isFalse);
    });

    testWidgets('keyboard focus then Enter fires exactly once', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(surface(enabled: true));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(last.focused, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('disabled ignores taps, hover and focus', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(surface(enabled: false));
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(1, 1));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(InteractiveSurface)));
      await tester.pump();
      await tester.tap(find.byType(InteractiveSurface));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(taps, 0);
      expect(last, (hovered: false, pressed: false, focused: false));
    });

    testWidgets('a non-null callback swapped to null stops taps', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(surface(enabled: true));
      await tester.tap(find.byType(InteractiveSurface));
      expect(taps, 1);

      await tester.pumpWidget(surface(enabled: false));
      await tester.tap(find.byType(InteractiveSurface));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('becoming disabled mid-press returns to idle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(surface(enabled: true));
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(InteractiveSurface)),
      );
      await tester.pump();
      expect(last.pressed, isTrue);

      await tester.pumpWidget(surface(enabled: false));
      expect(last.pressed, isFalse);

      await gesture.up();
      await tester.pump();
      expect(last, (hovered: false, pressed: false, focused: false));
      expect(taps, 0);

      // Re-enabling must not resurrect the stale pressed flag.
      await tester.pumpWidget(surface(enabled: true));
      expect(last.pressed, isFalse);
    });
  });
}
