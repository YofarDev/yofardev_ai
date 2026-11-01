import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/features/settings/widgets/tts_voice_status_tile.dart';
import 'package:yofardev_ai/features/sound/sound.dart';

import '../../../helpers/golden_test_helper.dart';

void main() {
  Future<int> pump(WidgetTester tester, TtsEngineStatus status) async {
    int installs = 0;
    await tester.pumpWidget(
      GoldenTestHelper.makeTestableWidget(
        locale: const Locale('en'),
        child: TtsVoiceStatusTile(status: status, onInstall: () => installs++),
      ),
    );
    if (find.byType(TextButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(TextButton));
    }
    return installs;
  }

  testWidgets('not installed: Download, the size and the source', (
    WidgetTester tester,
  ) async {
    final int installs = await pump(
      tester,
      const TtsEngineStatus.notInstalled(),
    );

    expect(find.text('Not installed yet'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.textContaining('132 MB'), findsOneWidget);
    expect(find.textContaining('GitHub'), findsOneWidget);
    expect(installs, 1);
  });

  testWidgets('downloading: the percentage and a progress bar', (
    WidgetTester tester,
  ) async {
    await pump(tester, const TtsEngineStatus.downloading(0.426));

    expect(find.text('Downloading… 42%'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.426,
    );
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('installing and loading: indeterminate progress', (
    WidgetTester tester,
  ) async {
    await pump(tester, const TtsEngineStatus.extracting());
    expect(find.text('Installing…'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );

    await pump(tester, const TtsEngineStatus.loading());
    expect(find.text('Loading…'), findsOneWidget);
  });

  testWidgets('failed: the localized cause and Retry', (
    WidgetTester tester,
  ) async {
    final int installs = await pump(
      tester,
      const TtsEngineStatus.failed(NetworkFailure('socket closed')),
    );

    expect(find.textContaining('Install failed'), findsOneWidget);
    expect(find.textContaining('socket closed'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(installs, 1);
  });

  testWidgets('ready: no button, no download note', (
    WidgetTester tester,
  ) async {
    await pump(tester, const TtsEngineStatus.ready());

    expect(find.text('Ready, on this device'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(find.textContaining('132 MB'), findsNothing);
  });

  testWidgets('French strings', (WidgetTester tester) async {
    await tester.pumpWidget(
      GoldenTestHelper.makeTestableWidget(
        locale: const Locale('fr'),
        child: TtsVoiceStatusTile(
          status: const TtsEngineStatus.downloading(0.5),
          onInstall: () {},
        ),
      ),
    );

    expect(find.text('Téléchargement… 50 %'), findsOneWidget);
    expect(find.textContaining('132 Mo'), findsOneWidget);
  });
}
