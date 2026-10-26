import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:yofardev_ai/core/design/theme/app_theme.dart';
import 'package:yofardev_ai/core/l10n/generated/app_localizations.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';
import 'package:yofardev_ai/core/models/task_llm_config.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/core/repositories/settings_repository.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_cubit.dart';
import 'package:yofardev_ai/features/avatar/presentation/bloc/avatar_state.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_state.dart';
import 'package:yofardev_ai/features/home/widgets/home_content_stack.dart';
import 'package:yofardev_ai/features/settings/settings.dart';
import 'package:yofardev_ai/features/talking/data/repositories/talking_repository_impl.dart';
import 'package:yofardev_ai/features/talking/domain/services/tts_playback_service.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_cubit.dart';
import 'package:yofardev_ai/features/talking/presentation/bloc/talking_state.dart';

class MockAvatarCubit extends Mock implements AvatarCubit {}

class MockChatCubit extends Mock implements ChatCubit {}

class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<Result<String?>> getLanguage() async => Result<String?>.ok('en');
  @override
  Future<Result<void>> setLanguage(String language) async =>
      Result<void>.ok(null);
  @override
  Future<Result<bool>> getSoundEffects() async => Result<bool>.ok(true);
  @override
  Future<Result<void>> setSoundEffects(bool enabled) async =>
      Result<void>.ok(null);
  @override
  Future<Result<String?>> getUsername() async => Result<String?>.ok(null);
  @override
  Future<Result<void>> setUsername(String username) async =>
      Result<void>.ok(null);
  @override
  Future<Result<String>> getSystemPrompt() async => Result<String>.ok('');
  @override
  Future<Result<void>> setSystemPrompt(String prompt) async =>
      Result<void>.ok(null);
  @override
  Future<Result<ChatPersona>> getPersona() async =>
      Result<ChatPersona>.ok(ChatPersona.normal);
  @override
  Future<Result<void>> setPersona(ChatPersona persona) async =>
      Result<void>.ok(null);
  @override
  Future<Result<TaskLlmConfig>> getTaskLlmConfig() async =>
      Result<TaskLlmConfig>.ok(const TaskLlmConfig());
  @override
  Future<Result<void>> setTaskLlmConfig(TaskLlmConfig config) async =>
      Result<void>.ok(null);
  @override
  Future<Result<String?>> getGoogleSearchKey() async =>
      Result<String?>.ok(null);
  @override
  Future<Result<void>> setGoogleSearchKey(String key) async =>
      Result<void>.ok(null);
  @override
  Future<Result<String?>> getGoogleSearchEngineId() async =>
      Result<String?>.ok(null);
  @override
  Future<Result<void>> setGoogleSearchEngineId(String id) async =>
      Result<void>.ok(null);
  @override
  Future<Result<bool>> getGoogleSearchEnabled() async => Result<bool>.ok(true);
  @override
  Future<Result<void>> setGoogleSearchEnabled(bool enabled) async =>
      Result<void>.ok(null);
  @override
  Future<Result<String?>> getOpenWeatherKey() async => Result<String?>.ok(null);
  @override
  Future<Result<void>> setOpenWeatherKey(String key) async =>
      Result<void>.ok(null);
  @override
  Future<Result<bool>> getOpenWeatherEnabled() async => Result<bool>.ok(true);
  @override
  Future<Result<void>> setOpenWeatherEnabled(bool enabled) async =>
      Result<void>.ok(null);
  @override
  Future<Result<String?>> getNewYorkTimesKey() async =>
      Result<String?>.ok(null);
  @override
  Future<Result<void>> setNewYorkTimesKey(String key) async =>
      Result<void>.ok(null);
  @override
  Future<Result<bool>> getNewYorkTimesEnabled() async => Result<bool>.ok(true);
  @override
  Future<Result<void>> setNewYorkTimesEnabled(bool enabled) async =>
      Result<void>.ok(null);
  @override
  Future<Result<bool>> getMemoryEnabled() async => Result<bool>.ok(true);
  @override
  Future<Result<void>> setMemoryEnabled(bool enabled) async =>
      Result<void>.ok(null);
}

/// Real [TalkingCubit]: its deps are all cheap, real constructibles.
TalkingCubit createRealTalkingCubit() {
  return TalkingCubit(
    TalkingRepositoryImpl(),
    InterruptionService(),
    TtsPlaybackService(TalkingRepositoryImpl()),
    AppLifecycleService(),
  );
}

/// Serves non-rive bytes for every `.riv` asset key: the flutter tester has
/// no packaged assets, and decoding real rive bytes aborts the tester's
/// native rive runtime. The widget's decode failure is handled by its own
/// error path (`File.asset` resolves to null), which is all this test needs:
/// the rebuild spy only observes widget rebuilds, not rive rendering.
void mockRiveAssets() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (Object? message) async {
        final String? key = const StringCodec().decodeMessage(
          message as ByteData?,
        );
        if (key != null &&
            key.startsWith('assets/rive/') &&
            key.endsWith('.riv')) {
          return ByteData(4);
        }
        return null;
      });
}

/// Pumps [HomeContentStack] itself (not the full [HomeScreen]): the full
/// HomeScreen harness needs six cubits plus DI-bound services, while the
/// rebuild defect under test lives in HomeContentStack's subtree wiring.
Future<void> pumpHomeContentStack(
  WidgetTester tester, {
  required TalkingCubit talkingCubit,
}) async {
  mockRiveAssets();
  final MockAvatarCubit avatarCubit = MockAvatarCubit();
  when(
    () => avatarCubit.stream,
  ).thenAnswer((_) => const Stream<AvatarState>.empty());
  when(() => avatarCubit.state).thenReturn(
    const AvatarState(avatar: Avatar(), avatarConfig: AvatarConfig()),
  );

  final MockChatCubit chatCubit = MockChatCubit();
  when(
    () => chatCubit.stream,
  ).thenAnswer((_) => const Stream<ChatState>.empty());
  when(() => chatCubit.state).thenReturn(ChatState.initial());

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<ChatCubit>.value(value: chatCubit),
        BlocProvider<TalkingCubit>.value(value: talkingCubit),
        BlocProvider<AvatarCubit>.value(value: avatarCubit),
        BlocProvider<SettingsCubit>.value(
          value: SettingsCubit(
            settingsRepository: _FakeSettingsRepository(),
            llmService: LlmService(),
          ),
        ),
      ],
      child: Provider<InterruptionService>.value(
        value: InterruptionService(),
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HomeContentStack(
              chatsState: ChatState.initial(),
              onTripleTap: () {},
            ),
          ),
        ),
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

void main() {
  tearDown(() {
    debugOnRebuildDirtyWidget = null;
  });

  testWidgets('mouth-state changes do not rebuild the text input', (
    WidgetTester tester,
  ) async {
    final TalkingCubit talkingCubit = createRealTalkingCubit();
    addTearDown(talkingCubit.close);

    await pumpHomeContentStack(tester, talkingCubit: talkingCubit);

    final List<String> rebuilds = captureRebuilds();
    talkingCubit.emit(const TalkingState.speaking());
    // idle() flushes the bloc stream microtask so the rebuild happens
    // inside the following pumped frame.
    await tester.idle();
    await tester.pump();
    debugOnRebuildDirtyWidget = null;

    expect(
      rebuilds.contains('AiTextInput'),
      isFalse,
      reason: 'mouth-only TalkingState changes must not rebuild the input',
    );
  });

  testWidgets(
    'positive control: mouth-state changes do rebuild the avatar view',
    (WidgetTester tester) async {
      final TalkingCubit talkingCubit = createRealTalkingCubit();
      addTearDown(talkingCubit.close);

      await pumpHomeContentStack(tester, talkingCubit: talkingCubit);

      final List<String> events = <String>[];
      talkingCubit.stream.listen((TalkingState _) => events.add('evt'));
      final List<String> rebuilds = captureRebuilds();
      talkingCubit.emit(const TalkingState.speaking());
      await tester.idle();
      await tester.pump();
      debugOnRebuildDirtyWidget = null;

      expect(
        rebuilds.contains('RiveAvatarView'),
        isTrue,
        reason: 'the spy must be proven to fire on TalkingState changes',
      );
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
