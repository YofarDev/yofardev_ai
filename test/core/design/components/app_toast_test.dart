import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:yofardev_ai/core/design/components/components.dart';

import '../../../helpers/golden_test_helper.dart';

/// A screen whose buttons show toasts.
Widget _host({required List<String> messages, bool error = false}) {
  return GoldenTestHelper.makeTestableWidget(
    child: Builder(
      builder: (BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final String message in messages)
              TextButton(
                onPressed: () => showAppToast(context, message, error: error),
                child: Text('show $message'),
              ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await GoldenTestHelper.init();
  });

  group('showAppToast', () {
    testWidgets('shows the message, then dismisses itself after 3 s', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(messages: <String>['Hello']));
      await tester.tap(find.text('show Hello'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Hello'), findsOneWidget);
      expect(find.byType(AppToast), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2500));
      expect(find.text('Hello'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsNothing);
      expect(find.byType(AppToast), findsNothing);
    });

    testWidgets('one at a time: a new toast replaces the previous one', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(messages: <String>['First', 'Second']));
      await tester.tap(find.text('show First'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('show Second'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);

      // The replaced toast's timer must not dismiss the new one early.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Second'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsNothing);
    });

    testWidgets('is announced as a live region', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(messages: <String>['Heads up']));
      await tester.tap(find.text('show Heads up'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        tester.getSemantics(find.byType(AppToast)),
        isSemantics(isLiveRegion: true, label: 'Heads up'),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('slides in quickly when animations are disabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _host(messages: <String>['Still']),
        ),
      );
      await tester.tap(find.text('show Still'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      final FadeTransition fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byType(AppToast),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 1);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  });

  group('AppToast goldens', () {
    testGoldens('neutral and error pills', (WidgetTester tester) async {
      await tester.pumpWidgetBuilder(
        GoldenTestHelper.makeTestableWidget(
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AppToast(message: "Voice input isn't available here."),
                SizedBox(height: 16),
                AppToast(
                  message: 'Something went wrong. Try again.',
                  error: true,
                ),
              ],
            ),
          ),
        ),
        surfaceSize: const Size(400, 160),
      );
      await GoldenTestHelper.matchGolden(tester, 'app_toast_pills');
    });
  });
}
