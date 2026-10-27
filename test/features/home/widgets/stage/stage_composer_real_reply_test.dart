import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit_file.dart';
import 'package:yofardev_ai/core/models/talking_phase.dart';
import 'package:yofardev_ai/core/services/llm/llm_stream_chunk.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/features/chat/chat.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_composer.dart';
import 'package:yofardev_ai/features/settings/settings.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

import '../../../../helpers/golden_test_helper.dart';
import '../../../../helpers/rive_test_assets.dart';
import '../../stage_harness.dart' show QuietSpeechInputService;
import 'real_reply_rig.dart';

class _MockSettingsCubit extends Mock implements SettingsCubit {}

void main() {
  late RealReplyRig rig;
  late _MockSettingsCubit settings;

  setUpAll(() async {
    await GoldenTestHelper.init();
    await initializeDateFormatting('en', null);
    Intl.defaultLocale = 'en';
    RealReplyRig.registerFallbacks();
  });

  setUp(() {
    serveFakeRiveAssets();
    UiKitFile.resetForTest();
    settings = _MockSettingsCubit();
    when(
      () => settings.state,
    ).thenReturn(const SettingsState(currentLanguage: 'en'));
    when(
      () => settings.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
  });

  Future<void> pumpComposer(WidgetTester tester) async {
    // Built inside the test body: the cubits' subscriptions must live in
    // the test's fake-async zone, or their events never run under pump().
    rig = RealReplyRig();
    addTearDown(rig.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <SingleChildWidget>[
          BlocProvider<ChatCubit>.value(value: rig.chat),
          BlocProvider<TalkingCubit>.value(value: rig.talking),
          BlocProvider<SettingsCubit>.value(value: settings),
        ],
        child: Provider<InterruptionService>.value(
          value: rig.interruption,
          child: GoldenTestHelper.makeTestableWidget(
            locale: const Locale('en'),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: StageComposer(speech: QuietSpeechInputService()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  ComposerOrbState orbState(WidgetTester tester) =>
      tester.widget<ComposerOrb>(find.byType(ComposerOrb)).state;

  /// Runs pending microtasks and stream deliveries, then a frame, without
  /// advancing the clock.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 5; i++) {
      await tester.idle();
      await tester.pump();
    }
  }

  Future<void> send(WidgetTester tester, String prompt) async {
    await tester.enterText(find.byType(TextField), prompt);
    await tester.pump();
    await tester.tap(find.byType(ComposerOrb));
    await settle(tester);
  }

  testWidgets('Stop while thinking returns to idle at once and the next '
      'prompt works', (WidgetTester tester) async {
    await pumpComposer(tester);
    await send(tester, 'Hello');
    expect(rig.requests, hasLength(1));
    expect(rig.requests[0].hasListener, isTrue);
    expect(orbState(tester), ComposerOrbState.thinking);
    expect(rig.talking.state.phase, TalkingPhase.generating);

    // The provider has not sent a single chunk (first-token latency, a
    // reasoning phase): Stop must not wait for one.
    await tester.tap(find.byType(ComposerOrb));
    await settle(tester);

    expect(orbState(tester), ComposerOrbState.idle);
    expect(rig.talking.state.phase, TalkingPhase.idle);
    expect(rig.chat.state.status, isNot(ChatStatus.typing));
    expect(rig.chat.state.status, isNot(ChatStatus.streaming));
    expect(rig.requests[0].hasListener, isFalse, reason: 'request cancelled');

    // The next prompt goes out...
    await send(tester, 'Again');
    expect(rig.requests, hasLength(2));
    expect(orbState(tester), ComposerOrbState.thinking);

    // ...and the old stream, though its flag was reset by the new reply,
    // never resumes into the TTS queue.
    rig.requests[0].add(
      const LlmStreamChunk.text(
        content: '{"message": "Stale sentence."}',
        isComplete: true,
      ),
    );
    rig.answer(1, 'Fresh sentence.');
    await settle(tester);
    expect(rig.synthesizer.texts, <String>['Fresh sentence.']);
  });

  testWidgets('a reply whose speech fails to synthesize leaves thinking', (
    WidgetTester tester,
  ) async {
    await pumpComposer(tester);
    rig.synthesizer.fails = true;
    await send(tester, 'Hello');
    rig.answer(0, 'Hi there.');
    await settle(tester);
    await tester.pump(TalkingCubit.idleCooldown * 2);
    await settle(tester);

    expect(rig.synthesizer.texts, <String>['Hi there.']);
    expect(rig.talking.state.phase, TalkingPhase.idle);
    expect(orbState(tester), ComposerOrbState.idle);
  });

  testWidgets('an empty reply leaves thinking', (WidgetTester tester) async {
    await pumpComposer(tester);
    await send(tester, 'Hello');
    // The provider ends the reply without a word.
    rig.requests[0].add(const LlmStreamChunk.complete());
    unawaited(rig.requests[0].close());
    await settle(tester);
    await tester.pump(TalkingCubit.idleCooldown * 2);
    await settle(tester);

    expect(rig.synthesizer.texts, isEmpty);
    expect(rig.talking.state.phase, TalkingPhase.idle);
    expect(orbState(tester), ComposerOrbState.idle);
  });
}
