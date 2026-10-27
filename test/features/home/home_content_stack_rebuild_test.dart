import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit_file.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';
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
