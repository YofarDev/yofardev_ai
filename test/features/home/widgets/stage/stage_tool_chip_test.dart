import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yofardev_ai/core/design/components/components.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit_file.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_tool_chip.dart';

import '../../../../helpers/rive_test_assets.dart';
import '../../stage_harness.dart';

void main() {
  late StageHarness h;

  setUp(() {
    serveFakeRiveAssets();
    UiKitFile.resetForTest();
    h = StageHarness();
  });

  Future<void> pumpChip(WidgetTester tester) async {
    await tester.pumpWidget(
      h.app(
        const Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: StageToolChip(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> runTool(WidgetTester tester, String? tool) async {
    h.chat.emit(h.chat.state.copyWith(activeTool: tool));
    await tester.idle();
    await tester.pumpAndSettle();
  }

  testWidgets('shows nothing while no tool runs', (WidgetTester tester) async {
    await pumpChip(tester);
    expect(find.byType(AppPill), findsNothing);
    expect(find.byType(ToolIcon), findsNothing);
  });

  testWidgets('shows the running tool, then leaves when it is done', (
    WidgetTester tester,
  ) async {
    await pumpChip(tester);

    await runTool(tester, 'getCurrentWeather');
    expect(find.text('Checking the weather…'), findsOneWidget);
    final ToolIcon icon = tester.widget<ToolIcon>(find.byType(ToolIcon));
    expect(icon.kind, ToolIconKind.weather);
    expect(icon.running, isTrue);

    await runTool(tester, 'searchGoogle');
    expect(find.text('Searching the web…'), findsOneWidget);
    expect(find.text('Checking the weather…'), findsNothing);

    await runTool(tester, null);
    expect(find.byType(AppPill), findsNothing);
  });

  testWidgets('an unknown tool gets the generic line', (
    WidgetTester tester,
  ) async {
    await pumpChip(tester);
    await runTool(tester, 'somethingNew');
    expect(find.text('Working on it…'), findsOneWidget);
    expect(
      tester.widget<ToolIcon>(find.byType(ToolIcon)).kind,
      ToolIconKind.generic,
    );
  });
}
