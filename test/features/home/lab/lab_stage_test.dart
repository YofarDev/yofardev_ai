import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/looks/looks.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/talking_phase.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_caption.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_composer_mock.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_config.dart';
import 'package:yofardev_ai/features/home/widgets/lab/lab_stage_preview.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

/// Fake builder: no font is ever loaded.
TextTheme _fakeTextTheme(LookFonts fonts, ColorScheme scheme) =>
    ThemeData.dark().textTheme;

/// Records every stage build so tests can check what the Rive layer would
/// receive, without decoding any Rive file.
class _StageProbe {
  final List<(AvatarScene, TalkingPhase)> builds =
      <(AvatarScene, TalkingPhase)>[];
  int mounts = 0;

  (AvatarScene, TalkingPhase) get last => builds.last;

  Widget build(
    BuildContext context,
    AvatarScene scene,
    TalkingState talking,
    FaceFrame? _,
  ) {
    builds.add((scene, talking.phase));
    return _ProbeStage(probe: this);
  }
}

class _ProbeStage extends StatefulWidget {
  const _ProbeStage({required this.probe});

  final _StageProbe probe;

  @override
  State<_ProbeStage> createState() => _ProbeStageState();
}

class _ProbeStageState extends State<_ProbeStage> {
  @override
  void initState() {
    super.initState();
    widget.probe.mounts++;
  }

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Color(0xFF333344), child: SizedBox.expand());
}

LabConfig _config({
  LabLayout layout = LabLayout.stageChips,
  LabComposerState composer = LabComposerState.idle,
  AvatarScene scene = AvatarScene.livingRoom,
}) => LabConfig.initial.copyWith(
  tab: LabTab.stage,
  layout: layout,
  composer: composer,
  scene: scene,
);

Widget _harness(
  LabConfig config,
  _StageProbe probe, {
  bool disableAnimations = false,
}) {
  return MaterialApp(
    theme: buildLookTheme(
      UiLooks.storybook,
      config.scene,
      textThemeBuilder: _fakeTextTheme,
    ),
    home: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: Scaffold(
          body: LabStagePreview(config: config, stageBuilder: probe.build),
        ),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  LabConfig config,
  _StageProbe probe, {
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _harness(config, probe, disableAnimations: disableAnimations),
  );
  await tester.pump();
}

Finder _label(String label) => find.bySemanticsLabel(label);

void main() {
  group('layouts', () {
    testWidgets('stage chips: history and more on top, caption, composer', (
      WidgetTester tester,
    ) async {
      final _StageProbe probe = _StageProbe();
      await _pump(tester, _config(), probe);

      expect(_label('History'), findsOneWidget);
      expect(_label('More'), findsOneWidget);
      expect(_label('Add attachment'), findsOneWidget);
      expect(find.byType(LabCaption), findsOneWidget);
      expect(find.byType(LabComposerMock), findsOneWidget);
      // The chips sit at the top, outside the composer.
      expect(
        find.descendant(
          of: find.byType(LabComposerMock),
          matching: _label('History'),
        ),
        findsNothing,
      );
      expect(
        tester.getCenter(_label('History')).dy,
        lessThan(tester.getCenter(find.byType(LabComposerMock)).dy),
      );
    });

    testWidgets('dock: history and more live inside the one composer dock', (
      WidgetTester tester,
    ) async {
      final _StageProbe probe = _StageProbe();
      await _pump(tester, _config(layout: LabLayout.dock), probe);

      for (final String label in <String>['History', 'More']) {
        expect(
          find.descendant(
            of: find.byType(LabComposerMock),
            matching: _label(label),
          ),
          findsOneWidget,
          reason: label,
        );
      }
      expect(_label('Add attachment'), findsNothing);
      expect(find.byType(LabCaption), findsOneWidget);
    });

    testWidgets('curtain: composer only, a tap on the stage toggles chips', (
      WidgetTester tester,
    ) async {
      final _StageProbe probe = _StageProbe();
      await _pump(tester, _config(layout: LabLayout.curtain), probe);

      expect(find.byType(LabComposerMock), findsOneWidget);
      expect(find.byType(LabCaption), findsOneWidget);
      expect(_label('History'), findsNothing);
      expect(_label('More'), findsNothing);

      final Offset stage = tester.getTopLeft(find.byType(LabStagePreview));
      await tester.tapAt(stage + const Offset(60, 200));
      await tester.pumpAndSettle();
      expect(_label('History'), findsOneWidget);
      expect(_label('More'), findsOneWidget);

      await tester.tapAt(stage + const Offset(60, 200));
      await tester.pumpAndSettle();
      expect(_label('History'), findsNothing);
    });

    testWidgets('each scene has its own caption, two lines max', (
      WidgetTester tester,
    ) async {
      final Set<String> captions = <String>{};
      for (final AvatarScene scene in AvatarScene.values) {
        final _StageProbe probe = _StageProbe();
        await _pump(tester, _config(scene: scene), probe);
        final String caption = LabCaption.sampleFor(scene);
        expect(caption.length, lessThanOrEqualTo(70), reason: caption);
        expect(find.text(caption), findsOneWidget, reason: scene.name);
        expect(tester.widget<Text>(find.text(caption)).maxLines, 2);
        captions.add(caption);
      }
      expect(captions, hasLength(AvatarScene.values.length));
      expect(
        LabCaption.sampleFor(AvatarScene.livingRoom),
        'The cat thinks the lamp is a second moon.',
      );
    });
  });

  group('composer states', () {
    testWidgets('idle: placeholder and mic', (WidgetTester tester) async {
      final _StageProbe probe = _StageProbe();
      await _pump(tester, _config(), probe);
      expect(find.text('Ask anything'), findsOneWidget);
      expect(_label('Voice input'), findsOneWidget);
      expect(_label('Send'), findsNothing);
      expect(_label('Stop'), findsNothing);
    });

    testWidgets('typing: text and send', (WidgetTester tester) async {
      final _StageProbe probe = _StageProbe();
      await _pump(tester, _config(composer: LabComposerState.typing), probe);
      expect(find.text('Ask anything'), findsNothing);
      expect(_label('Send'), findsOneWidget);
      expect(_label('Voice input'), findsNothing);
    });

    testWidgets('speaking: stop replaces send in the same slot', (
      WidgetTester tester,
    ) async {
      final _StageProbe probe = _StageProbe();
      await _pump(tester, _config(composer: LabComposerState.typing), probe);
      final Rect sendRect = tester.getRect(_label('Send'));

      await tester.pumpWidget(
        _harness(_config(composer: LabComposerState.speaking), probe),
      );
      // Speaking keeps the mouth moving, so never settles: wait out the swap.
      await tester.pump(const Duration(seconds: 1));
      expect(_label('Stop'), findsOneWidget);
      expect(_label('Send'), findsNothing);
      expect(tester.getRect(_label('Stop')), sendRect);
    });

    testWidgets('listening: live words above a collapsed pill', (
      WidgetTester tester,
    ) async {
      final _StageProbe probe = _StageProbe();
      await _pump(tester, _config(composer: LabComposerState.listening), probe);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(LabComposerMock.liveWordsKey), findsOneWidget);
      expect(_label('Listening'), findsOneWidget);
      expect(find.text('Ask anything'), findsNothing);
      expect(
        tester.getCenter(find.byKey(LabComposerMock.liveWordsKey)).dy,
        lessThan(tester.getCenter(_label('Listening')).dy),
      );
    });

    testWidgets('the avatar phase follows the composer', (
      WidgetTester tester,
    ) async {
      final _StageProbe probe = _StageProbe();
      await _pump(tester, _config(), probe);
      expect(probe.last, (AvatarScene.livingRoom, TalkingPhase.idle));

      await tester.pumpWidget(
        _harness(_config(composer: LabComposerState.thinking), probe),
      );
      expect(probe.last.$2, TalkingPhase.generating);

      await tester.pumpWidget(
        _harness(
          _config(
            composer: LabComposerState.speaking,
            scene: AvatarScene.beach,
          ),
          probe,
          disableAnimations: true,
        ),
      );
      expect(probe.last, (AvatarScene.beach, TalkingPhase.speaking));
    });
  });

  testWidgets('the stage survives scene, layout and composer changes', (
    WidgetTester tester,
  ) async {
    final _StageProbe probe = _StageProbe();
    await _pump(tester, _config(), probe);
    expect(probe.mounts, 1);

    for (final LabConfig config in <LabConfig>[
      _config(layout: LabLayout.dock),
      _config(layout: LabLayout.curtain, scene: AvatarScene.campfire),
      _config(composer: LabComposerState.listening),
      _config(composer: LabComposerState.speaking),
    ]) {
      await tester.pumpWidget(_harness(config, probe));
      await tester.pump();
    }
    expect(probe.mounts, 1);
  });

  group('animations', () {
    for (final LabComposerState state in <LabComposerState>[
      LabComposerState.listening,
      LabComposerState.thinking,
      LabComposerState.speaking,
    ]) {
      testWidgets('${state.name} animates by default', (
        WidgetTester tester,
      ) async {
        final _StageProbe probe = _StageProbe();
        await _pump(tester, _config(composer: state), probe);
        await tester.pump(const Duration(seconds: 2));
        expect(tester.hasRunningAnimations, isTrue);
      });

      testWidgets('${state.name} runs nothing with disableAnimations', (
        WidgetTester tester,
      ) async {
        final _StageProbe probe = _StageProbe();
        await _pump(
          tester,
          _config(composer: state),
          probe,
          disableAnimations: true,
        );
        await tester.pump(const Duration(seconds: 2));
        expect(tester.hasRunningAnimations, isFalse);
      });
    }

    testWidgets('stops repeating when the state leaves listening', (
      WidgetTester tester,
    ) async {
      final _StageProbe probe = _StageProbe();
      await _pump(tester, _config(composer: LabComposerState.listening), probe);
      await tester.pumpWidget(_harness(_config(), probe));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
