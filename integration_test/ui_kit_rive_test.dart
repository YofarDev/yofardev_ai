import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rive/rive.dart';
import 'package:yofardev_ai/core/design/design.dart';
import 'package:yofardev_ai/core/design/rive/rive_vm_binding.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit_artboard.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit_contract.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit_file.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/talking_phase.dart';

/// Mounts every UI-kit widget on the REAL `assets/rive/ui/ui_kit.riv`:
/// each one must leave its Flutter fallback for the Rive artboard, take
/// every property change through its view model without throwing, and
/// dispose cleanly.
///
/// Runs on macOS (`flutter test integration_test/ui_kit_rive_test.dart
/// -d macos`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(UiKitFile.resetForTest);

  Future<void> pumpKit(
    WidgetTester tester,
    Widget child, {
    AvatarScene scene = AvatarScene.livingRoom,
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.forScene(scene),
          themeAnimationDuration: Duration.zero,
          home: Scaffold(body: Center(child: child)),
        ),
      ),
    );
    await tester.pump();
  }

  /// Waits (real time) until the artboard under [widget] runs on Rive.
  Future<void> waitForRive(WidgetTester tester, Finder widget) async {
    final Finder rive = find.descendant(
      of: widget,
      matching: find.byType(RiveWidget),
    );
    for (int i = 0; i < 100 && rive.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(rive, findsOneWidget, reason: 'the Rive artboard must replace');
  }

  ViewModelInstance vm(WidgetTester tester, Finder widget) {
    final RiveVmBinding? binding = tester
        .state<UiKitArtboardState>(
          find.descendant(of: widget, matching: find.byType(UiKitArtboard)),
        )
        .binding;
    expect(binding, isNotNull);
    expect(binding!.hasViewModel, isTrue);
    return binding.viewModelInstance!;
  }

  Color accentOf(WidgetTester tester, Finder widget) =>
      tester.element(widget).tokens.scene.accent;

  Future<void> disposeAll(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets('ComposerOrb: every state, level, accent and reduce-motion', (
    WidgetTester tester,
  ) async {
    final Finder orb = find.byType(ComposerOrb);
    await pumpKit(tester, const ComposerOrb(state: ComposerOrbState.idle));
    await waitForRive(tester, orb);

    for (final ComposerOrbState state in ComposerOrbState.values) {
      await pumpKit(tester, ComposerOrb(state: state, level: 0.7));
      await tester.pump(const Duration(milliseconds: 100));
      final ViewModelInstance vmi = vm(tester, orb);
      expect(vmi.enumerator(UiKitContract.orbPropState)!.value, state.name);
      expect(vmi.number(UiKitContract.orbPropLevel)!.value, closeTo(0.7, 1e-6));
    }
    expect(
      vm(tester, orb).color(UiKitContract.orbPropAccent)!.value,
      accentOf(tester, orb),
    );

    // A scene change re-tints in place (same artboard, no reload).
    await pumpKit(
      tester,
      const ComposerOrb(state: ComposerOrbState.speaking),
      scene: AvatarScene.deepSpace,
    );
    await tester.pump();
    expect(
      find.descendant(of: orb, matching: find.byType(RiveWidget)),
      findsOneWidget,
    );
    expect(
      vm(tester, orb).color(UiKitContract.orbPropAccent)!.value,
      accentOf(tester, orb),
    );

    await pumpKit(
      tester,
      const ComposerOrb(state: ComposerOrbState.listening),
      reduceMotion: true,
    );
    expect(
      vm(tester, orb).boolean(UiKitContract.orbPropReduceMotion)!.value,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await disposeAll(tester);
  });

  testWidgets('StatusGlow: every phase and reduce-motion', (
    WidgetTester tester,
  ) async {
    final Finder glow = find.byType(StatusGlow);
    Widget sized(TalkingPhase phase) =>
        SizedBox(width: 465, height: 194, child: StatusGlow(phase: phase));
    await pumpKit(tester, sized(TalkingPhase.idle));
    await waitForRive(tester, glow);

    for (final TalkingPhase phase in TalkingPhase.values) {
      await pumpKit(tester, sized(phase));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        vm(tester, glow).enumerator(UiKitContract.glowPropPhase)!.value,
        phase.name,
      );
    }
    await pumpKit(tester, sized(TalkingPhase.speaking), reduceMotion: true);
    expect(
      vm(tester, glow).boolean(UiKitContract.glowPropReduceMotion)!.value,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await disposeAll(tester);
  });

  testWidgets('ToolIcon: every kind; running holds still without motion', (
    WidgetTester tester,
  ) async {
    final Finder icon = find.byType(ToolIcon);
    await pumpKit(
      tester,
      const ToolIcon(kind: ToolIconKind.search, running: true),
    );
    await waitForRive(tester, icon);

    for (final ToolIconKind kind in ToolIconKind.values) {
      await pumpKit(tester, ToolIcon(kind: kind, running: true));
      await tester.pump(const Duration(milliseconds: 100));
      final ViewModelInstance vmi = vm(tester, icon);
      expect(vmi.enumerator(UiKitContract.toolPropKind)!.value, kind.name);
      expect(vmi.boolean(UiKitContract.toolPropRunning)!.value, isTrue);
    }

    await pumpKit(
      tester,
      const ToolIcon(kind: ToolIconKind.weather, running: true),
      reduceMotion: true,
    );
    expect(
      vm(tester, icon).boolean(UiKitContract.toolPropRunning)!.value,
      isFalse,
    );
    await pumpKit(
      tester,
      const ToolIcon(kind: ToolIconKind.weather, running: false),
    );
    expect(
      vm(tester, icon).boolean(UiKitContract.toolPropRunning)!.value,
      isFalse,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await disposeAll(tester);
  });

  testWidgets('RiveToggle: the value follows the widget and taps flip it', (
    WidgetTester tester,
  ) async {
    final Finder toggle = find.byType(RiveToggle);
    bool value = false;
    Widget build() => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => RiveToggle(
        value: value,
        onChanged: (bool next) => setState(() => value = next),
        semanticLabel: 'Tools',
      ),
    );
    await pumpKit(tester, build());
    await waitForRive(tester, toggle);
    expect(
      vm(tester, toggle).boolean(UiKitContract.togglePropValue)!.value,
      isFalse,
    );

    for (int i = 0; i < 4; i++) {
      await tester.tap(toggle);
      await tester.pump(const Duration(milliseconds: 100));
      expect(value, i.isEven);
      expect(
        vm(tester, toggle).boolean(UiKitContract.togglePropValue)!.value,
        value,
      );
    }
    expect(tester.takeException(), isNull);
    await disposeAll(tester);
  });

  testWidgets('MarkSting: plays repeatedly', (WidgetTester tester) async {
    final GlobalKey<MarkStingState> mark = GlobalKey<MarkStingState>();
    await pumpKit(tester, MarkSting(key: mark));
    await waitForRive(tester, find.byType(MarkSting));

    for (int i = 0; i < 3; i++) {
      mark.currentState!.play();
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.takeException(), isNull);
    await disposeAll(tester);
  });

  testWidgets('every kit widget at once, then all disposed', (
    WidgetTester tester,
  ) async {
    await pumpKit(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 465,
            height: 194,
            child: StatusGlow(phase: TalkingPhase.generating),
          ),
          const ComposerOrb(state: ComposerOrbState.thinking),
          const ToolIcon(kind: ToolIconKind.news, running: true),
          RiveToggle(value: true, onChanged: (_) {}),
          const MarkSting(),
        ],
      ),
    );
    for (final Type type in <Type>[
      StatusGlow,
      ComposerOrb,
      ToolIcon,
      RiveToggle,
      MarkSting,
    ]) {
      await waitForRive(tester, find.byType(type));
    }
    await tester.pump(const Duration(milliseconds: 500));
    await disposeAll(tester);
  });
}
