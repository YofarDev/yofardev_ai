import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';

import 'package:yofardev_ai/core/design/rive/ui_kit.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit_file.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/features/chat/chat.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_composer.dart';
import 'package:yofardev_ai/features/settings/settings.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

import '../../../../helpers/golden_test_helper.dart';
import '../../../../helpers/rive_test_assets.dart';
import '../../../chat/bloc/chat_reply_failure_harness.dart';
import '../../stage_harness.dart';

/// The composer on the REAL chat and talking cubits: a reply that fails
/// must bring the orb back to idle (error flash, then idle), never leave it
/// thinking.
void main() {
  setUpAll(ReplyRig.registerFallbacks);

  setUp(() {
    serveFakeRiveAssets();
    UiKitFile.resetForTest();
  });

  for (final ReplyEnd end in <ReplyEnd>[ReplyEnd.error, ReplyEnd.thrown]) {
    testWidgets('a failed reply (${end.name}): thinking → error → idle', (
      WidgetTester tester,
    ) async {
      final ReplyRig rig = ReplyRig(end);
      final StageHarness h = StageHarness();
      final List<ComposerOrbState> modes = <ComposerOrbState>[];
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: <SingleChildWidget>[
            BlocProvider<ChatCubit>.value(value: rig.chat),
            BlocProvider<TalkingCubit>.value(value: rig.talking),
            BlocProvider<SettingsCubit>.value(value: h.settingsCubit),
          ],
          child: Provider<InterruptionService>.value(
            value: rig.interruption,
            child: GoldenTestHelper.makeTestableWidget(
              locale: const Locale('en'),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: StageComposer(
                  speech: h.speech,
                  onModeChanged: modes.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Hello?');
      await tester.pump();
      await tester.tap(find.byType(ComposerOrb));
      await tester.pump();
      await tester.pump();
      expect(rig.streaming.started.isCompleted, isTrue);
      expect(modes.last, ComposerOrbState.thinking);

      rig.streaming.release.complete();
      await tester.idle();
      await tester.pump();
      await tester.pump();
      expect(modes.last, ComposerOrbState.error);

      await tester.pump(StageComposer.errorFlash);
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(modes.last, ComposerOrbState.idle);
      expect(
        tester.widget<ComposerOrb>(find.byType(ComposerOrb)).state,
        ComposerOrbState.idle,
      );

      // The cubits stream into the widget tree: close them after it is gone.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(rig.close);
    });
  }
}
