import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_voice_notice.dart';
import 'package:yofardev_ai/features/sound/sound.dart';

import '../../../../helpers/golden_test_helper.dart';
import '../../../sound/kokoro/fake_tts_engine_status_service.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    FakeTtsEngineStatusService? engine,
  ) async {
    await tester.pumpWidget(
      GoldenTestHelper.makeTestableWidget(
        locale: const Locale('en'),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: StageVoiceNotice(engine: engine),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no engine: nothing', (WidgetTester tester) async {
    await pump(tester, null);

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('voice'), findsNothing);
  });

  testWidgets('shows while downloading, with size and source', (
    WidgetTester tester,
  ) async {
    final FakeTtsEngineStatusService engine = FakeTtsEngineStatusService(
      const TtsEngineStatus.downloading(0.1),
    );
    await pump(tester, engine);

    expect(find.textContaining('Installing the new voice'), findsOneWidget);
    expect(find.textContaining('Downloading… 10%'), findsOneWidget);
    expect(find.textContaining('132 MB'), findsOneWidget);
    expect(find.textContaining('backup voice'), findsOneWidget);

    engine.emit(const TtsEngineStatus.downloading(0.6));
    await tester.pumpAndSettle();
    expect(find.textContaining('Downloading… 60%'), findsOneWidget);
  });

  testWidgets('hides once ready, and never shows a plain load', (
    WidgetTester tester,
  ) async {
    final FakeTtsEngineStatusService engine = FakeTtsEngineStatusService(
      const TtsEngineStatus.loading(),
    );
    await pump(tester, engine);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    engine.emit(const TtsEngineStatus.extracting());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Installing…'), findsOneWidget);

    engine.emit(const TtsEngineStatus.ready());
    await tester.pumpAndSettle();
    expect(find.textContaining('Installing the new voice'), findsNothing);
  });

  testWidgets('failed: Retry installs again', (WidgetTester tester) async {
    final FakeTtsEngineStatusService engine = FakeTtsEngineStatusService(
      const TtsEngineStatus.failed(NetworkFailure('offline')),
    );
    await pump(tester, engine);

    await tester.tap(find.text('Retry'));
    expect(engine.installs, 1);
  });

  testWidgets('Hide dismisses it for the session', (WidgetTester tester) async {
    final FakeTtsEngineStatusService engine = FakeTtsEngineStatusService(
      const TtsEngineStatus.downloading(0.2),
    );
    await pump(tester, engine);

    await tester.tap(find.byTooltip('Hide'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Installing the new voice'), findsNothing);

    engine.emit(const TtsEngineStatus.downloading(0.3));
    await tester.pumpAndSettle();
    expect(find.textContaining('Installing the new voice'), findsNothing);
  });
}
