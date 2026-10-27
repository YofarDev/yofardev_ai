import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';

import 'package:yofardev_ai/core/design/theme/app_theme.dart';
import 'package:yofardev_ai/core/l10n/generated/app_localizations.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/demo_script.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/core/services/speech/speech_input_service.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/chat/chat.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_tts_state.dart';
import 'package:yofardev_ai/features/demo/demo.dart';
import 'package:yofardev_ai/features/settings/settings.dart';
import 'package:yofardev_ai/features/talking/talking.dart';

class MockChatCubit extends Mock implements ChatCubit {}

class MockChatTtsCubit extends Mock implements ChatTtsCubit {}

class MockTalkingCubit extends Mock implements TalkingCubit {}

class MockAvatarCubit extends Mock implements AvatarCubit {}

class MockSettingsCubit extends Mock implements SettingsCubit {}

class MockCaptionCubit extends Mock implements CaptionCubit {}

class MockDemoCubit extends Mock implements DemoCubit {}

class MockInterruptionService extends Mock implements InterruptionService {}

/// Speech input that is supported and never hears anything.
class QuietSpeechInputService implements SpeechInputService {
  @override
  bool get isSupported => true;

  @override
  Stream<double> get soundLevel => const Stream<double>.empty();

  @override
  Stream<String> get partialWords => const Stream<String>.empty();

  @override
  Future<SpeechStartResult> start({required String localeId}) async =>
      SpeechStartResult.started;

  @override
  Future<String> stop() async => '';

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

/// A mocked cubit's state, changed by the test with [emit].
class Driven<S> {
  Driven(this.state);

  S state;
  final StreamController<S> controller = StreamController<S>.broadcast();

  void emit(S next) {
    state = next;
    controller.add(next);
  }
}

const Avatar stageAvatar = Avatar();
const Chat stageChat = Chat(id: 'chat-1', avatar: stageAvatar);

/// Every cubit and service the Stage reads, as driven mocks, and the app
/// around a widget under test.
class StageHarness {
  StageHarness() {
    _registerFallbacks();
    when(() => chatCubit.state).thenAnswer((_) => chat.state);
    when(() => chatCubit.stream).thenAnswer((_) => chat.controller.stream);
    when(() => chatCubit.createNewChat()).thenAnswer((_) async {});
    when(() => chatCubit.resetStatus()).thenReturn(null);

    when(() => talkingCubit.state).thenAnswer((_) => talking.state);
    when(
      () => talkingCubit.stream,
    ).thenAnswer((_) => talking.controller.stream);
    when(() => talkingCubit.init()).thenAnswer((_) async {});

    when(() => captionCubit.state).thenAnswer((_) => caption.state);
    when(
      () => captionCubit.stream,
    ).thenAnswer((_) => caption.controller.stream);
    when(() => captionCubit.toggle()).thenAnswer((_) async {});

    when(() => settingsCubit.state).thenAnswer((_) => settings.state);
    when(
      () => settingsCubit.stream,
    ).thenAnswer((_) => settings.controller.stream);
    when(
      () => settingsCubit.setCurrentLanguage(any()),
    ).thenAnswer((_) async {});

    when(() => avatarCubit.state).thenAnswer((_) => avatar.state);
    when(() => avatarCubit.stream).thenAnswer((_) => avatar.controller.stream);
    when(
      () => avatarCubit.setValuesBasedOnScreenWidth(
        screenWidth: any(named: 'screenWidth'),
      ),
    ).thenReturn(null);
    when(() => avatarCubit.onScreenSizeChanged(any())).thenReturn(null);
    when(() => avatarCubit.loadAvatar(any())).thenReturn(null);

    when(() => demoCubit.state).thenReturn(const DemoState());
    when(
      () => demoCubit.stream,
    ).thenAnswer((_) => const Stream<DemoState>.empty());
    when(
      () => demoCubit.startDemoMode(
        chatId: any(named: 'chatId'),
        script: any(named: 'script'),
      ),
    ).thenAnswer((_) async {});

    when(() => chatTtsCubit.state).thenReturn(const ChatTtsState());
    when(
      () => chatTtsCubit.stream,
    ).thenAnswer((_) => const Stream<ChatTtsState>.empty());
    when(
      () => chatTtsCubit.prepareWaitingSentences(any()),
    ).thenAnswer((_) async {});

    when(() => interruption.interrupt()).thenAnswer((_) async {});
  }

  /// Mocktail `any()` fallbacks (registering twice is harmless).
  static void _registerFallbacks() {
    registerFallbackValue(const Avatar());
    registerFallbackValue(const Chat());
    registerFallbackValue(DemoScripts.beachDemo);
  }

  final MockChatCubit chatCubit = MockChatCubit();
  final MockChatTtsCubit chatTtsCubit = MockChatTtsCubit();
  final MockTalkingCubit talkingCubit = MockTalkingCubit();
  final MockAvatarCubit avatarCubit = MockAvatarCubit();
  final MockSettingsCubit settingsCubit = MockSettingsCubit();
  final MockCaptionCubit captionCubit = MockCaptionCubit();
  final MockDemoCubit demoCubit = MockDemoCubit();
  final MockInterruptionService interruption = MockInterruptionService();
  final QuietSpeechInputService speech = QuietSpeechInputService();

  final Driven<ChatState> chat = Driven<ChatState>(
    const ChatState(
      currentChat: stageChat,
      openedChat: stageChat,
      status: ChatStatus.success,
      initializing: false,
    ),
  );
  final Driven<TalkingState> talking = Driven<TalkingState>(
    const TalkingState.idle(),
  );
  final Driven<CaptionState> caption = Driven<CaptionState>(
    const CaptionState(),
  );
  final Driven<SettingsState> settings = Driven<SettingsState>(
    const SettingsState(currentLanguage: 'en'),
  );
  final Driven<AvatarState> avatar = Driven<AvatarState>(
    const AvatarState(avatar: Avatar(), avatarConfig: AvatarConfig()),
  );

  Widget _providers(Widget child) => MultiBlocProvider(
    providers: <SingleChildWidget>[
      BlocProvider<ChatCubit>.value(value: chatCubit),
      BlocProvider<ChatTtsCubit>.value(value: chatTtsCubit),
      BlocProvider<TalkingCubit>.value(value: talkingCubit),
      BlocProvider<AvatarCubit>.value(value: avatarCubit),
      BlocProvider<SettingsCubit>.value(value: settingsCubit),
      BlocProvider<CaptionCubit>.value(value: captionCubit),
      BlocProvider<DemoCubit>.value(value: demoCubit),
    ],
    child: Provider<InterruptionService>.value(
      value: interruption,
      child: child,
    ),
  );

  /// [home] in the app, themed for [scene].
  Widget app(
    Widget home, {
    AvatarScene scene = AvatarScene.livingRoom,
    Locale locale = const Locale('en'),
  }) => _providers(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forScene(scene),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  /// The app on [router].
  Widget routerApp(GoRouter router, {Locale locale = const Locale('en')}) =>
      _providers(
        MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
}
