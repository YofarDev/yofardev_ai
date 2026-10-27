import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit_file.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/features/home/screens/home_screen.dart';
import 'package:yofardev_ai/features/home/widgets/home_content_stack.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

import '../../helpers/rive_test_assets.dart';
import 'stage_harness.dart';

/// Pumps [HomeContentStack] itself (not the full HomeScreen): the rebuild
/// scope under test lives in the stack's subtree wiring.
Future<void> pumpHomeContentStack(WidgetTester tester, StageHarness h) async {
  await tester.pumpWidget(
    h.app(
      Scaffold(
        resizeToAvoidBottomInset: false,
        body: HomeContentStack(speech: h.speech, onStartDemo: () {}),
      ),
    ),
  );
  await tester.pump();
}

/// Records the widget type of every dirty element rebuilt after this call.
///
/// Uses [debugOnRebuildDirtyWidget] (a widgets-library hook) rather than
/// swapping [debugPrint]: flutter_test's foundation invariant asserts that
/// `debugPrint` is untouched by tests, which would fail the suite.
List<String> captureRebuilds() {
  final List<String> rebuilds = <String>[];
  debugOnRebuildDirtyWidget = (Element element, bool builtOnce) {
    rebuilds.add(element.widget.runtimeType.toString());
  };
  return rebuilds;
}

/// Runs [change], pumps one frame and returns what that frame rebuilt.
Future<List<String>> rebuildsDuring(
  WidgetTester tester,
  FutureOr<void> Function() change,
) async {
  final List<String> rebuilds = captureRebuilds();
  await change();
  await tester.idle();
  await tester.pump();
  debugOnRebuildDirtyWidget = null;
  return rebuilds;
}

/// Asserts that of the Stage's widgets, [rebuilds] holds exactly [expected].
void expectStageRebuilds(List<String> rebuilds, List<String> expected) {
  for (final String widget in <String>[..._chrome, 'RiveAvatarView']) {
    expect(
      rebuilds.contains(widget),
      expected.contains(widget),
      reason: expected.contains(widget)
          ? '$widget should rebuild'
          : '$widget must not rebuild',
    );
  }
}

/// Emits [state] and records what the next frame rebuilds.
Future<List<String>> rebuildsAfter(
  WidgetTester tester,
  StageHarness h,
  TalkingState state,
) async {
  final List<String> rebuilds = captureRebuilds();
  h.talking.emit(state);
  // idle() flushes the stream microtask so the rebuild happens inside the
  // following pumped frame.
  await tester.idle();
  await tester.pump();
  debugOnRebuildDirtyWidget = null;
  return rebuilds;
}

/// The Stage's widgets that must not depend on the mouth.
const List<String> _chrome = <String>[
  'HomeContentStack',
  'RiveSceneView',
  'StageTopBar',
  'StageToolChip',
  'StageCaption',
  'StageComposer',
  'StatusGlow',
];

void main() {
  late StageHarness h;

  setUp(() {
    serveFakeRiveAssets();
    UiKitFile.resetForTest();
    h = StageHarness();
  });

  tearDown(() {
    debugOnRebuildDirtyWidget = null;
  });

  testWidgets('a mouth change rebuilds only the avatar view', (
    WidgetTester tester,
  ) async {
    await pumpHomeContentStack(tester, h);
    h.talking.emit(const TalkingState.speaking());
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 500));

    final List<String> rebuilds = await rebuildsAfter(
      tester,
      h,
      const TalkingState.speaking(MouthState.open),
    );

    expect(
      rebuilds,
      contains('RiveAvatarView'),
      reason: 'the spy must be proven to fire on TalkingState changes',
    );
    for (final String widget in _chrome) {
      expect(
        rebuilds,
        isNot(contains(widget)),
        reason: 'a mouth-only TalkingState change must not rebuild $widget',
      );
    }
  });

  testWidgets(
    'positive control: a phase change reaches the glow and the composer',
    (WidgetTester tester) async {
      await pumpHomeContentStack(tester, h);

      final List<String> rebuilds = await rebuildsAfter(
        tester,
        h,
        const TalkingState.speaking(),
      );

      expect(rebuilds, contains('RiveAvatarView'));
      expect(rebuilds, contains('StatusGlow'));
      expect(rebuilds, contains('StageComposer'));
      expect(rebuilds, isNot(contains('StageTopBar')));
    },
  );

  testWidgets('a caption update rebuilds only the caption', (
    WidgetTester tester,
  ) async {
    await pumpHomeContentStack(tester, h);
    final List<String> rebuilds = await rebuildsDuring(
      tester,
      () => h.caption.emit(const CaptionState(text: 'Hello there.', seq: 1)),
    );
    // StageCaption's own builder, and nothing else of the Stage.
    expect(rebuilds, contains('BlocBuilder<CaptionCubit, CaptionState>'));
    expectStageRebuilds(rebuilds, <String>[]);
  });

  testWidgets('a tool update rebuilds only the tool chip', (
    WidgetTester tester,
  ) async {
    await pumpHomeContentStack(tester, h);
    final List<String> rebuilds = await rebuildsDuring(
      tester,
      () => h.chat.emit(h.chat.state.copyWith(activeTool: 'searchGoogle')),
    );
    // StageToolChip's own selector, and nothing else of the Stage.
    expect(rebuilds, contains('BlocSelector<ChatCubit, ChatState, String?>'));
    expectStageRebuilds(rebuilds, <String>[]);
  });

  group('the full Home screen', () {
    late HomeScreen home;

    setUp(() => home = HomeScreen(speech: h.speech));

    Future<void> pumpHome(WidgetTester tester) async {
      await tester.pumpWidget(h.app(home));
      await tester.pump();
    }

    testWidgets('a keyboard frame moves the chrome, not the Rive views', (
      WidgetTester tester,
    ) async {
      addTearDown(tester.view.reset);
      await pumpHome(tester);
      final List<String> rebuilds = await rebuildsDuring(
        tester,
        () => tester.view.viewInsets = const FakeViewPadding(bottom: 120),
      );
      expect(rebuilds, contains('_BottomChrome'));
      expect(rebuilds, isNot(contains('HomeContentStack')));
      expect(rebuilds, isNot(contains('_RiveStage')));
      expect(rebuilds, isNot(contains('RiveSceneView')));
      expect(rebuilds, isNot(contains('RiveAvatarView')));
    });

    testWidgets('a scene cross-fade does not rebuild the Stage', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);
      final List<String> rebuilds = await rebuildsDuring(tester, () async {
        await tester.pumpWidget(h.app(home, scene: AvatarScene.deepSpace));
        await tester.pump(const Duration(milliseconds: 100));
      });
      expect(rebuilds, contains('HomeScreen'));
      expect(rebuilds, isNot(contains('HomeContentStack')));
      // The Rive views' own error box (test fallback) reads the theme, so
      // check that nothing above them pushes a rebuild.
      expect(rebuilds, isNot(contains('_RiveStage')));
      expect(
        rebuilds,
        isNot(contains('BlocBuilder<AvatarCubit, AvatarState>')),
      );
    });
  });

  test('getMessage returns the identical cached instance', () {
    final ChatEntry entry = ChatEntry(
      id: 'id',
      entryType: EntryType.yofardev,
      body: '{"text": "hello"}',
      timestamp: DateTime(2026),
    );
    final String first = entry.getMessage();
    final String second = entry.getMessage();
    expect(identical(first, second), isTrue);
    expect(first, 'hello');
  });
}
