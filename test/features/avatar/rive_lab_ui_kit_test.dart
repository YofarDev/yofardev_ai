import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yofardev_ai/core/design/rive/ui_kit.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit_file.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/rive_lab_screen.dart';

import '../../helpers/golden_test_helper.dart';
import '../../helpers/rive_test_assets.dart';

/// The lab shows a spinner while avatar.riv is missing, so it never settles:
/// pump past the longest kit transition instead.
Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  setUpAll(serveFakeRiveAssets);
  setUp(UiKitFile.resetForTest);

  testWidgets('the UI kit tab previews the kit over the stage', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GoldenTestHelper.makeTestableWidget(child: const RiveLabScreen()),
    );
    await settle(tester);
    expect(find.byType(ComposerOrb), findsNothing);

    await tester.tap(find.text('UI kit'));
    await settle(tester);
    expect(find.byType(ComposerOrb), findsOneWidget);
    expect(find.byType(StatusGlow), findsOneWidget);
    expect(find.byType(ToolIcon), findsOneWidget);
    expect(find.byType(RiveToggle), findsOneWidget);
    expect(find.byType(MarkSting), findsOneWidget);

    // The live toggle flips the shared setting.
    expect(find.text('off'), findsOneWidget);
    await tester.tap(find.byType(RiveToggle));
    await settle(tester);
    expect(find.text('on'), findsOneWidget);

    // Reduce motion reaches the preview through MediaQuery.
    await tester.tap(find.text('Reduce motion'));
    await settle(tester);
    expect(
      MediaQuery.disableAnimationsOf(tester.element(find.byType(ComposerOrb))),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
