import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:yofardev_ai/core/design/rive/ui_kit.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit_artboard.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit_contract.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit_file.dart';
import 'package:yofardev_ai/core/models/talking_phase.dart';

import '../../../helpers/golden_test_helper.dart';
import '../../../helpers/rive_test_assets.dart';

/// Pumps [child] in the app harness, then lets the (failing) `ui_kit.riv`
/// load finish so the widgets settle on their fallbacks.
Future<void> pumpKit(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    GoldenTestHelper.makeTestableWidget(child: Center(child: child)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await GoldenTestHelper.init();
    serveFakeRiveAssets();
  });

  setUp(UiKitFile.resetForTest);

  group('contract mirror', () {
    test('enum names equal the contract value lists, in order', () {
      expect(
        ComposerOrbState.values.map((ComposerOrbState s) => s.name),
        orderedEquals(UiKitContract.orbStateValues),
      );
      expect(
        ToolIconKind.values.map((ToolIconKind k) => k.name),
        orderedEquals(UiKitContract.toolKindValues),
      );
      expect(
        TalkingPhase.values.map((TalkingPhase p) => p.name),
        orderedEquals(UiKitContract.glowPhaseValues),
      );
    });
  });

  group('UiKitFile', () {
    testWidgets('an undecodable file loads as null, once, shared', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        final Future<Object?> first = UiKitFile.load();
        final Future<Object?> second = UiKitFile.load();
        expect(identical(first, second), isTrue);
        expect(await first, isNull);
        expect(identical(UiKitFile.load(), first), isTrue);
      });
    });
  });

  group('fallbacks', () {
    testWidgets('every widget pumps its fallback without errors', (
      WidgetTester tester,
    ) async {
      await pumpKit(
        tester,
        Wrap(
          children: <Widget>[
            const ComposerOrb(state: ComposerOrbState.idle),
            const SizedBox(
              width: 200,
              height: 80,
              child: StatusGlow(phase: TalkingPhase.speaking),
            ),
            const ToolIcon(kind: ToolIconKind.search, running: true),
            RiveToggle(value: true, onChanged: (_) {}),
            const MarkSting(),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(UiKitArtboard), findsNWidgets(5));
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StatusGlow),
          matching: find.byType(AnimatedOpacity),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(RiveToggle),
          matching: find.byType(AnimatedAlign),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(MarkSting),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ComposerOrb shows a different icon per state', (
      WidgetTester tester,
    ) async {
      const Map<ComposerOrbState, IconData> expected =
          <ComposerOrbState, IconData>{
            ComposerOrbState.idle: Icons.mic,
            ComposerOrbState.typing: Icons.arrow_upward,
            ComposerOrbState.listening: Icons.graphic_eq,
            ComposerOrbState.thinking: Icons.more_horiz,
            ComposerOrbState.speaking: Icons.stop,
            ComposerOrbState.error: Icons.priority_high,
          };
      expect(expected.keys, unorderedEquals(ComposerOrbState.values));
      expect(expected.values.toSet(), hasLength(expected.length));
      for (final MapEntry<ComposerOrbState, IconData> entry
          in expected.entries) {
        await pumpKit(tester, ComposerOrb(state: entry.key, level: 0.5));
        expect(find.byIcon(entry.value), findsOneWidget, reason: '$entry');
      }
    });

    testWidgets('ComposerOrb settles with animations disabled', (
      WidgetTester tester,
    ) async {
      await pumpKit(
        tester,
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: ComposerOrb(state: ComposerOrbState.thinking),
        ),
      );
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('ToolIcon falls back to one Material icon per kind', (
      WidgetTester tester,
    ) async {
      const Map<ToolIconKind, IconData> expected = <ToolIconKind, IconData>{
        ToolIconKind.search: Icons.search,
        ToolIconKind.weather: Icons.wb_sunny,
        ToolIconKind.news: Icons.newspaper,
        ToolIconKind.memory: Icons.psychology,
        ToolIconKind.generic: Icons.auto_awesome,
      };
      for (final MapEntry<ToolIconKind, IconData> entry in expected.entries) {
        await pumpKit(tester, ToolIcon(kind: entry.key, running: false));
        expect(find.byIcon(entry.value), findsOneWidget, reason: '$entry');
      }
    });
  });

  group('RiveToggle', () {
    for (final bool value in <bool>[false, true]) {
      testWidgets('tap calls onChanged(${!value})', (
        WidgetTester tester,
      ) async {
        final List<bool> changes = <bool>[];
        await pumpKit(tester, RiveToggle(value: value, onChanged: changes.add));
        await tester.tap(find.byType(RiveToggle));
        expect(changes, <bool>[!value]);
      });
    }

    testWidgets('has a 48 dp hit area and toggled semantics', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKit(
        tester,
        RiveToggle(value: true, onChanged: (_) {}, semanticLabel: 'Tools'),
      );
      final Size size = tester.getSize(find.byType(RiveToggle));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Tools')),
        isSemantics(label: 'Tools', hasToggledState: true, isToggled: true),
      );
      handle.dispose();
    });
  });

  group('MarkSting', () {
    testWidgets('play() is a no-op while the fallback is shown', (
      WidgetTester tester,
    ) async {
      final GlobalKey<MarkStingState> key = GlobalKey<MarkStingState>();
      await pumpKit(tester, MarkSting(key: key));
      key.currentState!.play();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  testGoldens('UI kit fallbacks', (WidgetTester tester) async {
    await tester.pumpWidgetBuilder(
      GoldenTestHelper.makeTestableWidget(
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: <Widget>[
              for (final ComposerOrbState state in ComposerOrbState.values)
                ComposerOrb(state: state, level: 0.5),
              const SizedBox(
                width: 160,
                height: 64,
                child: StatusGlow(phase: TalkingPhase.speaking),
              ),
              for (final ToolIconKind kind in ToolIconKind.values)
                ToolIcon(kind: kind, running: false),
              RiveToggle(value: false, onChanged: (_) {}),
              RiveToggle(value: true, onChanged: (_) {}),
              const MarkSting(size: 64),
            ],
          ),
        ),
      ),
      surfaceSize: const Size(1000, 120),
    );
    final BuildContext context = tester.element(find.byType(MarkSting));
    await tester.runAsync(
      () => precacheImage(const AssetImage(MarkSting.iconAssetPath), context),
    );
    await tester.pumpAndSettle();
    await GoldenTestHelper.matchGolden(tester, 'ui_kit_fallbacks');
  });
}
