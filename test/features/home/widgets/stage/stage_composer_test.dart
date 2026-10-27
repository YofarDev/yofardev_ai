import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';

import 'package:yofardev_ai/core/design/rive/ui_kit.dart';
import 'package:yofardev_ai/core/design/rive/ui_kit_file.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/core/services/speech/speech_input_service.dart';
import 'package:yofardev_ai/features/chat/chat.dart';
import 'package:yofardev_ai/features/home/widgets/stage/stage_composer.dart';
import 'package:yofardev_ai/features/settings/settings.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

import '../../../../helpers/golden_test_helper.dart';
import '../../../../helpers/rive_test_assets.dart';

class MockChatCubit extends Mock implements ChatCubit {}

class MockTalkingCubit extends Mock implements TalkingCubit {}

class MockSettingsCubit extends Mock implements SettingsCubit {}

class MockInterruptionService extends Mock implements InterruptionService {}

/// Speech input driven by the test: [startResult] answers [start], [words]
/// answers [stop], and [level] / [partial] feed the streams.
class FakeSpeechInputService implements SpeechInputService {
  FakeSpeechInputService({this.isSupported = true});

  @override
  final bool isSupported;

  SpeechStartResult startResult = SpeechStartResult.started;
  String words = '';

  /// When set, [start] waits for the test to complete its completer.
  bool holdStarts = false;
  final List<Completer<SpeechStartResult>> heldStarts =
      <Completer<SpeechStartResult>>[];

  /// When set, [stop] answers with this completer's future.
  Completer<String>? stopGate;
  final List<String> calls = <String>[];
  final StreamController<double> level = StreamController<double>.broadcast();
  final StreamController<String> partial = StreamController<String>.broadcast();

  /// Fire to end the session as the recognizer does on its own.
  final StreamController<void> ended = StreamController<void>.broadcast();

  @override
  Stream<double> get soundLevel => level.stream;

  @override
  Stream<String> get partialWords => partial.stream;

  @override
  Stream<void> get sessionEnded => ended.stream;

  @override
  Future<SpeechStartResult> start({required String localeId}) async {
    calls.add('start:$localeId');
    if (holdStarts) {
      final Completer<SpeechStartResult> held = Completer<SpeechStartResult>();
      heldStarts.add(held);
      return held.future;
    }
    return startResult;
  }

  @override
  Future<String> stop() async {
    calls.add('stop');
    return stopGate?.future ?? words;
  }

  @override
  Future<void> cancel() async => calls.add('cancel');

  @override
  Future<void> dispose() async {
    await level.close();
    await partial.close();
    await ended.close();
  }
}

/// A mocked cubit whose state the test can change with [emit].
class _Driven<S> {
  _Driven(this.state);

  S state;
  final StreamController<S> controller = StreamController<S>.broadcast();

  void emit(S next) {
    state = next;
    controller.add(next);
  }
}

const Avatar _avatar = Avatar();
const Chat _chat = Chat(id: 'chat-1', avatar: _avatar);

void main() {
  late MockChatCubit chatCubit;
  late MockTalkingCubit talkingCubit;
  late MockSettingsCubit settingsCubit;
  late MockInterruptionService interruption;
  late FakeSpeechInputService speech;
  late _Driven<ChatState> chat;
  late _Driven<TalkingState> talking;

  setUpAll(() async {
    await GoldenTestHelper.init();
    registerFallbackValue(const Avatar());
    registerFallbackValue(const Chat());
  });

  setUp(() {
    serveFakeRiveAssets();
    UiKitFile.resetForTest();
    chatCubit = MockChatCubit();
    talkingCubit = MockTalkingCubit();
    settingsCubit = MockSettingsCubit();
    interruption = MockInterruptionService();
    speech = FakeSpeechInputService();

    chat = _Driven<ChatState>(
      const ChatState(
        currentChat: _chat,
        openedChat: _chat,
        status: ChatStatus.success,
      ),
    );
    when(() => chatCubit.state).thenAnswer((_) => chat.state);
    when(() => chatCubit.stream).thenAnswer((_) => chat.controller.stream);
    when(
      () => chatCubit.streamResponse(
        any(),
        onlyText: any(named: 'onlyText'),
        attachedImage: any(named: 'attachedImage'),
        avatar: any(named: 'avatar'),
        currentChat: any(named: 'currentChat'),
        language: any(named: 'language'),
        functionCallingEnabled: any(named: 'functionCallingEnabled'),
      ),
    ).thenAnswer((_) async {});
    when(() => chatCubit.resetStatus()).thenReturn(null);
    when(() => chatCubit.toggleFunctionCalling()).thenReturn(null);

    talking = _Driven<TalkingState>(const TalkingState.idle());
    when(() => talkingCubit.state).thenAnswer((_) => talking.state);
    when(
      () => talkingCubit.stream,
    ).thenAnswer((_) => talking.controller.stream);

    when(
      () => settingsCubit.state,
    ).thenReturn(const SettingsState(currentLanguage: 'en'));
    when(
      () => settingsCubit.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());

    when(() => interruption.interrupt()).thenAnswer((_) async {});
  });

  Future<void> pumpComposer(
    WidgetTester tester, {
    Future<File?> Function()? pickImage,
    bool reduceMotion = false,
    ValueChanged<ComposerOrbState>? onModeChanged,
  }) async {
    final Widget app = MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<ChatCubit>.value(value: chatCubit),
        BlocProvider<TalkingCubit>.value(value: talkingCubit),
        BlocProvider<SettingsCubit>.value(value: settingsCubit),
      ],
      child: Provider<InterruptionService>.value(
        value: interruption,
        child: GoldenTestHelper.makeTestableWidget(
          locale: const Locale('en'),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: pickImage == null
                  ? StageComposer(speech: speech, onModeChanged: onModeChanged)
                  : StageComposer(
                      speech: speech,
                      pickImage: pickImage,
                      onModeChanged: onModeChanged,
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      reduceMotion
          ? MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: app,
            )
          : app,
    );
    await tester.pump();
  }

  ComposerOrbState orbState(WidgetTester tester) =>
      tester.widget<ComposerOrb>(find.byType(ComposerOrb)).state;

  Finder orbButton(String label) => find.bySemanticsLabel(label);

  /// Lets the toast leave and its timers run out.
  Future<void> drain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('idle: the orb is a talk button with the hint in the field', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComposer(tester);
    expect(orbState(tester), ComposerOrbState.idle);
    expect(orbButton('Talk'), findsOneWidget);
    expect(find.text('Ask anything…'), findsOneWidget);
    expect(tester.getSize(orbButton('Talk')), const Size(48, 48));
    handle.dispose();
  });

  testWidgets('reports each mode change once, after its frame', (
    WidgetTester tester,
  ) async {
    final List<ComposerOrbState> modes = <ComposerOrbState>[];
    await pumpComposer(tester, onModeChanged: modes.add);
    expect(modes, <ComposerOrbState>[ComposerOrbState.idle]);

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Hello there');
    await tester.pump();
    expect(modes.last, ComposerOrbState.typing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    expect(modes.last, ComposerOrbState.listening);

    await tester.tap(find.byType(ComposerOrb));
    await tester.idle();
    await tester.pump();
    expect(modes.last, ComposerOrbState.idle);

    talking.emit(const TalkingState.generating());
    await tester.idle();
    await tester.pump();
    expect(modes, <ComposerOrbState>[
      ComposerOrbState.idle,
      ComposerOrbState.typing,
      ComposerOrbState.idle,
      ComposerOrbState.listening,
      ComposerOrbState.idle,
      ComposerOrbState.thinking,
    ]);
  });

  testWidgets('typing shows send semantics and submits like AiTextInput', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComposer(tester);
    await tester.enterText(find.byType(TextField), 'Is the cat judging me?');
    await tester.pump();
    expect(orbState(tester), ComposerOrbState.typing);
    expect(orbButton('Send'), findsOneWidget);

    await tester.tap(orbButton('Send'));
    await tester.pump();

    verify(
      () => chatCubit.streamResponse(
        'Is the cat judging me?',
        onlyText: false,
        attachedImage: null,
        avatar: _avatar,
        currentChat: _chat,
        language: 'en',
        functionCallingEnabled: true,
      ),
    ).called(1);
    verify(() => chatCubit.resetStatus()).called(1);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    handle.dispose();
  });

  testWidgets('the keyboard send action submits too', (
    WidgetTester tester,
  ) async {
    await pumpComposer(tester);
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    verify(
      () => chatCubit.streamResponse(
        'Hello',
        onlyText: false,
        attachedImage: null,
        avatar: _avatar,
        currentChat: _chat,
        language: 'en',
        functionCallingEnabled: true,
      ),
    ).called(1);
  });

  testWidgets('thinking while the request is in flight', (
    WidgetTester tester,
  ) async {
    final Completer<void> reply = Completer<void>();
    when(
      () => chatCubit.streamResponse(
        any(),
        onlyText: any(named: 'onlyText'),
        attachedImage: any(named: 'attachedImage'),
        avatar: any(named: 'avatar'),
        currentChat: any(named: 'currentChat'),
        language: any(named: 'language'),
        functionCallingEnabled: any(named: 'functionCallingEnabled'),
      ),
    ).thenAnswer((_) => reply.future);
    await pumpComposer(tester);
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    expect(orbState(tester), ComposerOrbState.thinking);
    verifyNever(() => chatCubit.resetStatus());

    reply.complete();
    await tester.pump();
    verify(() => chatCubit.resetStatus()).called(1);
    expect(orbState(tester), ComposerOrbState.idle);
  });

  testWidgets('speaking: the orb is a stop button that interrupts', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComposer(tester);
    talking.emit(const TalkingState.speaking());
    await tester.idle();
    await tester.pump();
    expect(orbState(tester), ComposerOrbState.speaking);
    expect(orbButton('Stop'), findsOneWidget);
    // The composer stays on screen while the avatar speaks.
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(orbButton('Stop'));
    await tester.pump();
    verify(() => interruption.interrupt()).called(1);
    expect(speech.calls, isEmpty);
    handle.dispose();
  });

  testWidgets('streaming reply: the orb stops it too', (
    WidgetTester tester,
  ) async {
    await pumpComposer(tester);
    chat.emit(chat.state.copyWith(status: ChatStatus.streaming));
    // idle() delivers the stream event before the frame is pumped.
    await tester.idle();
    await tester.pump();
    expect(orbState(tester), ComposerOrbState.thinking);
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    verify(() => interruption.interrupt()).called(1);
  });

  testWidgets('permission denied shows the toast and goes back to idle', (
    WidgetTester tester,
  ) async {
    speech.startResult = SpeechStartResult.permissionDenied;
    await pumpComposer(tester);
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(speech.calls, <String>['start:en_US']);
    expect(
      find.text('Allow the microphone in settings to talk to me.'),
      findsOneWidget,
    );
    expect(orbState(tester), ComposerOrbState.idle);
    await drain(tester);
  });

  testWidgets('unavailable recognizer shows its toast', (
    WidgetTester tester,
  ) async {
    speech.startResult = SpeechStartResult.unavailable;
    await pumpComposer(tester);
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text("Voice input isn't available here."), findsOneWidget);
    expect(orbState(tester), ComposerOrbState.idle);
    await drain(tester);
  });

  testWidgets('listening shows the partial words, then submits on stop', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    speech.words = 'what is the cat looking at';
    await pumpComposer(tester);
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    expect(orbState(tester), ComposerOrbState.listening);
    // Nothing heard yet: a tap only ends the session.
    expect(orbButton('Stop'), findsOneWidget);
    // The field and "+" collapse: only the orb is left.
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);

    speech.partial.add('what is the cat');
    speech.level.add(0.7);
    await tester.idle();
    await tester.pump();
    expect(find.text('what is the cat'), findsOneWidget);
    expect(tester.widget<ComposerOrb>(find.byType(ComposerOrb)).level, 0.7);

    await tester.tap(orbButton('Send'));
    await tester.pump();
    expect(speech.calls, <String>['start:en_US', 'stop']);
    verify(
      () => chatCubit.streamResponse(
        'what is the cat looking at',
        onlyText: false,
        attachedImage: null,
        avatar: _avatar,
        currentChat: _chat,
        language: 'en',
        functionCallingEnabled: true,
      ),
    ).called(1);
    await tester.pumpAndSettle();
    expect(find.text('what is the cat'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    handle.dispose();
  });

  testWidgets('listening stopped with no words sends nothing', (
    WidgetTester tester,
  ) async {
    await pumpComposer(tester);
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    expect(speech.calls, <String>['start:en_US', 'stop']);
    verifyNever(
      () => chatCubit.streamResponse(
        any(),
        onlyText: any(named: 'onlyText'),
        attachedImage: any(named: 'attachedImage'),
        avatar: any(named: 'avatar'),
        currentChat: any(named: 'currentChat'),
        language: any(named: 'language'),
        functionCallingEnabled: any(named: 'functionCallingEnabled'),
      ),
    );
    expect(orbState(tester), ComposerOrbState.idle);
  });

  testWidgets('French settings listen in fr_FR', (WidgetTester tester) async {
    when(
      () => settingsCubit.state,
    ).thenReturn(const SettingsState(currentLanguage: 'fr'));
    await pumpComposer(tester);
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    expect(speech.calls, <String>['start:fr_FR']);
  });

  testWidgets('without speech support the idle orb focuses the field', (
    WidgetTester tester,
  ) async {
    speech = FakeSpeechInputService(isSupported: false);
    await pumpComposer(tester);
    expect(orbState(tester), ComposerOrbState.idle);
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    expect(speech.calls, isEmpty);
    final EditableText editable = tester.widget<EditableText>(
      find.byType(EditableText),
    );
    expect(editable.focusNode.hasFocus, isTrue);
  });

  testWidgets('a failed reply flashes the error orb and shows a toast', (
    WidgetTester tester,
  ) async {
    await pumpComposer(tester);
    chat.emit(
      chat.state.copyWith(
        status: ChatStatus.error,
        error: const NetworkFailure('timeout'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(orbState(tester), ComposerOrbState.error);
    expect(find.text('Network error'), findsOneWidget);

    // The error orb is disabled: a tap does nothing.
    final SemanticsHandle handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(orbButton('Talk')),
      isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
    );
    handle.dispose();
    await tester.tap(find.byType(ComposerOrb), warnIfMissed: false);
    await tester.pump();
    expect(speech.calls, isEmpty);
    verifyNever(() => interruption.interrupt());

    await tester.pump(const Duration(milliseconds: 400));
    expect(orbState(tester), ComposerOrbState.idle);
    await drain(tester);
  });

  testWidgets('the + menu toggles tools', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComposer(tester);
    await tester.tap(orbButton('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Tools'), findsOneWidget);
    expect(find.byType(RiveToggle), findsOneWidget);
    expect(tester.widget<RiveToggle>(find.byType(RiveToggle)).value, isTrue);

    await tester.tap(find.byType(RiveToggle));
    await tester.pump();
    verify(() => chatCubit.toggleFunctionCalling()).called(1);
    handle.dispose();
  });

  testWidgets('an attached image goes with the next prompt', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComposer(
      tester,
      pickImage: () async => File('/tmp/stage-composer-test.png'),
    );
    await tester.tap(orbButton('More options'));
    await tester.pumpAndSettle();
    await tester.tap(orbButton('Attach an image'));
    await tester.pumpAndSettle();
    expect(find.byType(RiveToggle), findsNothing, reason: 'menu closed');
    expect(find.text('Describe this image'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete'), findsOneWidget);
    expect(orbState(tester), ComposerOrbState.typing);

    await tester.tap(orbButton('Send'));
    await tester.pump();
    verify(
      () => chatCubit.streamResponse(
        'Describe this image',
        onlyText: false,
        attachedImage: '/tmp/stage-composer-test.png',
        avatar: _avatar,
        currentChat: _chat,
        language: 'en',
        functionCallingEnabled: true,
      ),
    ).called(1);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Delete'), findsNothing);
    handle.dispose();
  });

  testWidgets('disposing while listening cancels the session', (
    WidgetTester tester,
  ) async {
    await pumpComposer(tester);
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(speech.calls, <String>['start:en_US', 'cancel']);
  });

  void stubStreamResponse(Future<void> Function() answer) {
    when(
      () => chatCubit.streamResponse(
        any(),
        onlyText: any(named: 'onlyText'),
        attachedImage: any(named: 'attachedImage'),
        avatar: any(named: 'avatar'),
        currentChat: any(named: 'currentChat'),
        language: any(named: 'language'),
        functionCallingEnabled: any(named: 'functionCallingEnabled'),
      ),
    ).thenAnswer((_) => answer());
  }

  int streamResponseCalls() => verify(
    () => chatCubit.streamResponse(
      any(),
      onlyText: any(named: 'onlyText'),
      attachedImage: any(named: 'attachedImage'),
      avatar: any(named: 'avatar'),
      currentChat: any(named: 'currentChat'),
      language: any(named: 'language'),
      functionCallingEnabled: any(named: 'functionCallingEnabled'),
    ),
  ).callCount;

  testWidgets('taps while stop() resolves are ignored: one session, no mic '
      'flicker', (WidgetTester tester) async {
    speech.stopGate = Completer<String>();
    await pumpComposer(tester);
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    expect(orbState(tester), ComposerOrbState.listening);

    // A quick second (and third) tap while the words are on their way.
    await tester.tap(find.byType(ComposerOrb), warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.byType(ComposerOrb), warnIfMissed: false);
    await tester.pump();
    expect(orbState(tester), ComposerOrbState.listening);
    expect(speech.calls, <String>['start:en_US', 'stop']);

    speech.stopGate!.complete('hello');
    await tester.pump();
    expect(speech.calls, <String>['start:en_US', 'stop']);
    expect(streamResponseCalls(), 1);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('a late start() result does not end a newer session', (
    WidgetTester tester,
  ) async {
    speech.holdStarts = true;
    await pumpComposer(tester);
    await tester.tap(find.byType(ComposerOrb)); // session A, start pending
    await tester.pump();
    await tester.tap(find.byType(ComposerOrb)); // stop A (no words)
    await tester.pump();
    await tester.tap(find.byType(ComposerOrb)); // session B, start pending
    await tester.pump();
    expect(speech.calls, <String>['start:en_US', 'stop', 'start:en_US']);

    speech.heldStarts[0].complete(SpeechStartResult.permissionDenied);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(orbState(tester), ComposerOrbState.listening);
    expect(
      find.text('Allow the microphone in settings to talk to me.'),
      findsNothing,
    );

    speech.heldStarts[1].complete(SpeechStartResult.started);
    await tester.pump();
    expect(orbState(tester), ComposerOrbState.listening);
  });

  testWidgets('the recognizer ending on its own sends what it heard', (
    WidgetTester tester,
  ) async {
    speech.words = 'what is the weather';
    await pumpComposer(tester);
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    speech.partial.add('what is the weather');
    await tester.idle();
    await tester.pump();
    expect(orbState(tester), ComposerOrbState.listening);

    // The user paused: the platform recognizer finalized and stopped.
    speech.ended.add(null);
    await tester.idle();
    await tester.pump();

    expect(speech.calls, <String>['start:en_US', 'stop']);
    verify(
      () => chatCubit.streamResponse(
        'what is the weather',
        onlyText: false,
        attachedImage: null,
        avatar: _avatar,
        currentChat: _chat,
        language: 'en',
        functionCallingEnabled: true,
      ),
    ).called(1);
    expect(orbState(tester), isNot(ComposerOrbState.listening));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('the recognizer ending with nothing heard goes back to idle', (
    WidgetTester tester,
  ) async {
    await pumpComposer(tester);
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    expect(orbState(tester), ComposerOrbState.listening);

    speech.ended.add(null);
    await tester.idle();
    await tester.pump();

    expect(orbState(tester), ComposerOrbState.idle);
    expect(speech.calls, <String>['start:en_US', 'stop']);
    verifyNever(
      () => chatCubit.streamResponse(
        any(),
        onlyText: any(named: 'onlyText'),
        attachedImage: any(named: 'attachedImage'),
        avatar: any(named: 'avatar'),
        currentChat: any(named: 'currentChat'),
        language: any(named: 'language'),
        functionCallingEnabled: any(named: 'functionCallingEnabled'),
      ),
    );
  });

  testWidgets('a session end after a stop tap is not handled twice', (
    WidgetTester tester,
  ) async {
    speech.stopGate = Completer<String>();
    await pumpComposer(tester);
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();

    speech.ended.add(null);
    await tester.idle();
    await tester.pump();
    speech.stopGate!.complete('hello');
    await tester.pump();

    expect(speech.calls, <String>['start:en_US', 'stop']);
    expect(streamResponseCalls(), 1);
  });

  testWidgets('a throwing streamResponse still resets and allows the next '
      'prompt', (WidgetTester tester) async {
    stubStreamResponse(() async => throw StateError('closed'));
    await pumpComposer(tester);
    await tester.enterText(find.byType(TextField), 'First');
    await tester.pump();
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    verify(() => chatCubit.resetStatus()).called(1);
    expect(orbState(tester), ComposerOrbState.idle);

    stubStreamResponse(() async {});
    await tester.enterText(find.byType(TextField), 'Second');
    await tester.pump();
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    verify(
      () => chatCubit.streamResponse(
        'Second',
        onlyText: false,
        attachedImage: null,
        avatar: _avatar,
        currentChat: _chat,
        language: 'en',
        functionCallingEnabled: true,
      ),
    ).called(1);
    verify(() => chatCubit.resetStatus()).called(1);
  });

  testWidgets('the chat status is reset even if the composer is gone', (
    WidgetTester tester,
  ) async {
    final Completer<void> reply = Completer<void>();
    stubStreamResponse(() => reply.future);
    await pumpComposer(tester);
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    reply.complete();
    await tester.pump();
    verify(() => chatCubit.resetStatus()).called(1);
  });

  Offset orbShakeOffset(WidgetTester tester) {
    final Transform transform = tester.widget<Transform>(
      find
          .ancestor(
            of: find.byType(ComposerOrb),
            matching: find.byType(Transform),
          )
          .first,
    );
    return Offset(
      transform.transform.getTranslation().x,
      transform.transform.getTranslation().y,
    );
  }

  Future<void> failReply(WidgetTester tester) async {
    chat.emit(
      chat.state.copyWith(
        status: ChatStatus.error,
        error: const NetworkFailure('timeout'),
      ),
    );
    await tester.idle();
    await tester.pump();
  }

  testWidgets('the error orb shakes', (WidgetTester tester) async {
    await pumpComposer(tester);
    await failReply(tester);
    await tester.pump(const Duration(milliseconds: 40));
    expect(orbShakeOffset(tester).dx.abs(), greaterThan(1));
    await drain(tester);
  });

  testWidgets('no shake when animations are disabled', (
    WidgetTester tester,
  ) async {
    await pumpComposer(tester, reduceMotion: true);
    await failReply(tester);
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(orbShakeOffset(tester), Offset.zero);
    }
    expect(orbState(tester), ComposerOrbState.error);
    await drain(tester);
  });

  testWidgets('a repeated error state does not toast again', (
    WidgetTester tester,
  ) async {
    await pumpComposer(tester);
    await failReply(tester);
    await tester.pump(const Duration(seconds: 2));
    // Same status, another field changed: no new toast.
    chat.emit(chat.state.copyWith(activeTool: 'searchGoogle'));
    await tester.idle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text('Network error'), findsNothing);
  });

  testGoldens('the composer in each mode', (WidgetTester tester) async {
    final Completer<void> reply = Completer<void>();
    when(
      () => chatCubit.streamResponse(
        any(),
        onlyText: any(named: 'onlyText'),
        attachedImage: any(named: 'attachedImage'),
        avatar: any(named: 'avatar'),
        currentChat: any(named: 'currentChat'),
        language: any(named: 'language'),
        functionCallingEnabled: any(named: 'functionCallingEnabled'),
      ),
    ).thenAnswer((_) => reply.future);
    await tester.binding.setSurfaceSize(const Size(400, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpComposer(tester);
    Future<void> shoot(String mode) => GoldenTestHelper.matchGolden(
      tester,
      'stage_composer_$mode',
      customPump: (WidgetTester tester) => tester.pump(),
    );

    await shoot('idle');

    await tester.enterText(find.byType(TextField), 'Is the cat judging me?');
    await tester.pumpAndSettle();
    await shoot('typing');
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ComposerOrb));
    await tester.pump();
    speech.partial.add('So what is the cat actually looking at');
    speech.level.add(0.6);
    await tester.idle();
    await tester.pumpAndSettle();
    await shoot('listening');
    speech.words = 'So what is the cat actually looking at';
    await tester.tap(find.byType(ComposerOrb));
    await tester.pumpAndSettle();
    await shoot('thinking');

    reply.complete();
    talking.emit(const TalkingState.speaking());
    await tester.idle();
    await tester.pumpAndSettle();
    await shoot('speaking');

    talking.emit(const TalkingState.idle());
    chat.emit(
      chat.state.copyWith(
        status: ChatStatus.error,
        error: const NetworkFailure('timeout'),
      ),
    );
    await tester.idle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    await shoot('error');
    await drain(tester);
  });
}
