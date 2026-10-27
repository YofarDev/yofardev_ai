import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yofardev_ai/core/design/components/components.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit_file.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/demo_script.dart';
import 'package:yofardev_ai/features/chat/chat.dart';
import 'package:yofardev_ai/features/home/screens/home_screen.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_composer.dart';

import '../../helpers/rive_test_assets.dart';
import 'stage_harness.dart';

void main() {
  late StageHarness h;

  setUp(() {
    serveFakeRiveAssets();
    UiKitFile.resetForTest();
    h = StageHarness();
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    double keyboard = 0,
    double bottomInset = 34,
  }) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1
      ..padding = FakeViewPadding(top: 47, bottom: bottomInset)
      ..viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(h.app(HomeScreen(speech: h.speech)));
    await tester.pump();
  }

  /// The composer's glass pill.
  Rect composerPill(WidgetTester tester) => tester.getRect(
    find.descendant(
      of: find.byType(StageComposer),
      matching: find.byType(GlassPanel),
    ),
  );

  testWidgets('the old Home chrome is gone', (WidgetTester tester) async {
    await pumpHome(tester);
    expect(find.byType(StageComposer), findsOneWidget);
    expect(find.byType(AiTextInput), findsNothing);
    expect(find.byType(FloatingStopButton), findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).resizeToAvoidBottomInset,
      isFalse,
    );
  });

  testWidgets('the composer waits for the chat to load', (
    WidgetTester tester,
  ) async {
    h.chat.state = h.chat.state.copyWith(initializing: true);
    await pumpHome(tester);
    expect(find.byType(StageComposer), findsNothing);

    h.chat.emit(h.chat.state.copyWith(initializing: false));
    await tester.idle();
    await tester.pump();
    expect(find.byType(StageComposer), findsOneWidget);
  });

  testWidgets('the composer sits above the system bar', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);
    expect(composerPill(tester).bottom, 844 - 34 - 12);
  });

  testWidgets('the composer sits above the keyboard', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester, keyboard: 300);
    expect(composerPill(tester).bottom, 844 - 300 - 12);
  });

  testWidgets('a new chat loads its avatar and resets the talking state', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);
    const Chat fresh = Chat(id: 'chat-2');
    h.chat.emit(h.chat.state.copyWith(currentChat: fresh, chatCreated: true));
    await tester.idle();
    await tester.pump();
    h.chat.emit(h.chat.state.copyWith(chatCreated: false));
    await tester.idle();
    await tester.pump();

    verify(() => h.avatarCubit.loadAvatar('chat-2')).called(1);
    verify(() => h.talkingCubit.init()).called(1);
  });

  testWidgets('debug builds: a triple tap on the stage plays the demo', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);
    for (int i = 0; i < 3; i++) {
      await tester.tapAt(const Offset(195, 250));
      await tester.pump(const Duration(milliseconds: 100));
    }
    verify(
      () => h.demoCubit.startDemoMode(
        chatId: 'chat-1',
        script: DemoScripts.beachDemo,
      ),
    ).called(1);
  });
}
