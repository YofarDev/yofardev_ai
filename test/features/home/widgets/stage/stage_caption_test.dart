import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yofardev_ai/core/design/rive/ui_kit.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_caption.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

import '../../stage_harness.dart';

const String _line = 'The cat thinks the lamp is a second moon.';

void main() {
  late StageHarness h;
  late ValueNotifier<ComposerOrbState> mode;

  setUp(() {
    h = StageHarness();
    mode = ValueNotifier<ComposerOrbState>(ComposerOrbState.idle);
  });

  tearDown(() => mode.dispose());

  Future<void> pumpCaption(WidgetTester tester) async {
    await tester.pumpWidget(
      h.app(
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: StageCaption(composerMode: mode),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> say(WidgetTester tester, CaptionState state) async {
    h.caption.emit(state);
    await tester.idle();
    await tester.pumpAndSettle();
  }

  testWidgets('shows the spoken sentence when captions are on', (
    WidgetTester tester,
  ) async {
    await pumpCaption(tester);
    expect(find.byKey(StageCaption.lineKey), findsNothing);

    await say(tester, const CaptionState(text: _line, seq: 1));
    expect(find.text(_line), findsOneWidget);
  });

  testWidgets('hides the sentence when captions are off', (
    WidgetTester tester,
  ) async {
    await pumpCaption(tester);
    await say(tester, const CaptionState(text: _line, seq: 1, enabled: false));
    expect(find.text(_line), findsNothing);

    // Turned back on mid-sentence: the current sentence shows.
    await say(tester, const CaptionState(text: _line, seq: 1));
    expect(find.text(_line), findsOneWidget);
  });

  for (final ComposerOrbState hiding in <ComposerOrbState>[
    ComposerOrbState.listening,
    ComposerOrbState.thinking,
  ]) {
    testWidgets('steps aside while the composer is ${hiding.name}', (
      WidgetTester tester,
    ) async {
      await pumpCaption(tester);
      await say(tester, const CaptionState(text: _line, seq: 1));

      if (hiding == ComposerOrbState.thinking) {
        h.talking.emit(const TalkingState.generating());
      }
      mode.value = hiding;
      await tester.idle();
      await tester.pumpAndSettle();
      expect(find.text(_line), findsNothing);

      mode.value = ComposerOrbState.speaking;
      await tester.pumpAndSettle();
      expect(find.text(_line), findsOneWidget);
    });
  }

  testWidgets('stays between two sentences of a streamed reply', (
    WidgetTester tester,
  ) async {
    await pumpCaption(tester);
    h.talking.emit(const TalkingState.speaking());
    mode.value = ComposerOrbState.speaking;
    await say(tester, const CaptionState(text: _line, seq: 1));

    // The sentence ended and the next one is still on its way: the avatar
    // is idle and the composer thinks (the reply is still streaming).
    h.talking.emit(const TalkingState.idle());
    mode.value = ComposerOrbState.thinking;
    await tester.idle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(_line), findsOneWidget);
    final FadeTransition fade = tester.widget<FadeTransition>(
      find
          .ancestor(of: find.text(_line), matching: find.byType(FadeTransition))
          .first,
    );
    expect(fade.opacity.value, 1, reason: 'not fading out');
  });

  testWidgets('a new sentence replaces the previous one', (
    WidgetTester tester,
  ) async {
    await pumpCaption(tester);
    await say(tester, const CaptionState(text: _line, seq: 1));
    await say(tester, const CaptionState(text: 'Second moon, first.', seq: 2));
    expect(find.text(_line), findsNothing);
    expect(find.text('Second moon, first.'), findsOneWidget);
  });

  testWidgets('long sentences stay on two lines', (WidgetTester tester) async {
    await pumpCaption(tester);
    await say(
      tester,
      CaptionState(text: List<String>.filled(30, 'moon').join(' '), seq: 1),
    );
    final Text text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(StageCaption.lineKey),
        matching: find.byType(Text),
      ),
    );
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('is a live region and a tap turns captions off', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpCaption(tester);
    await say(tester, const CaptionState(text: _line, seq: 1));

    expect(
      tester.getSemantics(find.text(_line)),
      isSemantics(
        isLiveRegion: true,
        label: _line,
        hasTapAction: true,
        onTapHint: 'Hide captions',
      ),
    );

    await tester.tap(find.text(_line));
    verify(() => h.captionCubit.toggle()).called(1);
    handle.dispose();
  });
}
