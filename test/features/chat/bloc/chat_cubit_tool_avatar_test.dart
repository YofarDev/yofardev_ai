import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_ai/core/models/avatar_config.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';
import 'package:yofardev_ai/core/models/demo_script.dart';
import 'package:yofardev_ai/core/models/function_info.dart';
import 'package:yofardev_ai/core/models/llm_config.dart';
import 'package:yofardev_ai/core/repositories/settings_repository.dart';
import 'package:yofardev_ai/core/services/agent/avatar_tool.dart';
import 'package:yofardev_ai/core/services/agent/tool_registry.dart';
import 'package:yofardev_ai/core/services/app_lifecycle_service.dart';
import 'package:yofardev_ai/core/services/audio/interruption_service.dart';
import 'package:yofardev_ai/core/services/llm/fake_llm_service.dart';
import 'package:yofardev_ai/core/services/llm/llm_service_interface.dart';
import 'package:yofardev_ai/core/services/prompt_datasource.dart';
import 'package:yofardev_ai/core/services/stream_processor/stream_processor_service.dart';
import 'package:yofardev_ai/features/avatar/avatar.dart';
import 'package:yofardev_ai/features/chat/data/datasources/chat_local_datasource.dart';
import 'package:yofardev_ai/features/chat/data/repositories/yofardev_repository_impl.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_entry_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_streaming_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/chat_title_service.dart';
import 'package:yofardev_ai/features/chat/domain/services/global_memory_service.dart';
import 'package:yofardev_ai/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:yofardev_ai/features/demo/demo.dart';
import 'package:yofardev_ai/core/services/settings_local_datasource.dart';

class _MockLlmService extends Mock implements LlmServiceInterface {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockAvatarAnimationService extends Mock
    implements AvatarAnimationService {}

class _MockChatTitleService extends Mock implements ChatTitleService {}

class _MockGlobalMemoryService extends Mock implements GlobalMemoryService {}

class _MockDemoService extends Mock implements DemoService {}

class _FakePromptDatasource implements PromptDatasource {
  @override
  Future<String> getSystemPrompt() async => 'system';
}

class _FakeChatEntryService implements ChatEntryService {
  @override
  Future<ChatEntry> createUserEntry({
    required String prompt,
    required Avatar avatar,
    String? attachedImage,
  }) async => ChatEntry(
    id: 'user',
    entryType: EntryType.user,
    body: prompt,
    timestamp: DateTime.now(),
  );
}

/// The real tool list, offered without reading any setting.
class _OpenToolRegistry extends ToolRegistry {
  _OpenToolRegistry(AppLifecycleService lifecycle)
    : super(
        appLifecycleService: lifecycle,
        tools: <AgentTool>[AvatarTool(lifecycle)],
      );

  @override
  Future<List<FunctionInfo>> getFunctionInfos(
    SettingsRepository settingsRepository,
  ) async => functionInfos;
}

/// A reply whose LLM calls `change_avatar` must leave the tool's avatar in
/// the stored chat (and in the cubit's chat): the reply's own chat was
/// captured when the message was sent, before the tool ran.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('en', null);
    Intl.defaultLocale = 'en';
  });

  late AppLifecycleService lifecycle;
  late ChatLocalDatasource datasource;
  late ChatCubit cubit;
  late FakeLlmService llm;

  const Chat seeded = Chat(
    id: 'chat-1',
    avatar: Avatar(background: AvatarScene.livingRoom),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    lifecycle = AppLifecycleService();
    final SettingsLocalDatasource settings = SettingsLocalDatasource();
    datasource = ChatLocalDatasource(
      settingsDatasource: settings,
      promptDatasource: _FakePromptDatasource(),
    );
    await datasource.updateChat(chatId: seeded.id, updatedChat: seeded);
    final YofardevRepositoryImpl repository = YofardevRepositoryImpl(
      chatDatasource: datasource,
    );

    final _MockLlmService delegate = _MockLlmService();
    when(() => delegate.init()).thenAnswer((_) async {});
    when(() => delegate.getCurrentConfig()).thenReturn(
      const LlmConfig(
        id: 'test',
        label: 'test',
        baseUrl: 'http://localhost',
        apiKey: 'key',
        model: 'test-model',
      ),
    );
    llm = FakeLlmService.forTest(delegate);

    final _MockGlobalMemoryService memory = _MockGlobalMemoryService();
    when(() => memory.updateMemory(any())).thenAnswer((_) async {});
    when(() => memory.buildMemoryMessage()).thenAnswer((_) async => null);
    final _MockChatTitleService titles = _MockChatTitleService();
    when(() => titles.shouldGenerateTitle(any())).thenReturn(false);

    cubit = ChatCubit(
      chatRepository: repository,
      settingsRepository: _MockSettingsRepository(),
      avatarAnimationService: _MockAvatarAnimationService(),
      chatTitleService: titles,
      chatStreamingService: ChatStreamingService(
        chatRepository: repository,
        llmService: llm,
        streamProcessor: StreamProcessorService(),
        promptDatasource: _FakePromptDatasource(),
        interruptionService: InterruptionService(),
        chatEntryService: _FakeChatEntryService(),
        toolRegistry: _OpenToolRegistry(lifecycle),
        settingsRepository: _MockSettingsRepository(),
        globalMemoryService: memory,
      ),
      appLifecycleService: lifecycle,
      globalMemoryService: memory,
      demoService: _MockDemoService(),
    );
    cubit
      ..setOpenedChat(seeded)
      ..setCurrentChat(seeded);
  });

  setUpAll(() => registerFallbackValue(const Chat()));

  tearDown(() => cubit.close());

  Future<void> reply(Map<String, dynamic> arguments) async {
    llm.activate(<FakeLlmResponse>[
      FakeLlmResponse(
        jsonBody: '',
        toolCalls: <FakeToolCall>[
          FakeToolCall(name: 'change_avatar', arguments: arguments),
        ],
      ),
      const FakeLlmResponse(jsonBody: '{"message": "Voilà, new look!"}'),
    ]);
    await cubit.streamResponse(
      'Dress up!',
      onlyText: true,
      avatar: cubit.state.currentChat.avatar,
      currentChat: cubit.state.currentChat,
      language: 'en',
    );
    // Lets the fire-and-forget avatar handlers settle.
    await pumpEventQueue();
  }

  test('the stored chat keeps the wardrobe change_avatar set', () async {
    await reply(<String, dynamic>{
      'hat': 'beanie',
      'top': 'longCoat',
      'topTint': 'red',
      'hatTint': 'teal',
    });

    final Chat stored = (await datasource.getChat(seeded.id))!;
    expect(stored.entries.last.body, contains('Voilà'));
    expect(stored.avatar.hat, AvatarHat.beanie);
    expect(stored.avatar.top, AvatarTop.longCoat);
    expect(stored.avatar.topTint, AvatarTint.red);
    expect(stored.avatar.hatTint, AvatarTint.teal);
    expect(stored.avatar.background, AvatarScene.livingRoom);
    expect(cubit.state.openedChat.avatar, stored.avatar);
    expect(cubit.state.currentChat.avatar, stored.avatar);
  });

  test('the stored chat keeps the costume change_avatar set', () async {
    await reply(<String, dynamic>{'costume': 'batman'});

    final Chat stored = (await datasource.getChat(seeded.id))!;
    expect(stored.avatar.costume, AvatarCostume.batman);
    expect(cubit.state.openedChat.avatar.costume, AvatarCostume.batman);
  });

  test('the stored avatar keeps the legacy map keys', () async {
    await reply(<String, dynamic>{'hat': 'beanie', 'top': 'longCoat'});

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> map =
        json.decode(prefs.getString('chat_${seeded.id}')!)
            as Map<String, dynamic>;
    final Map<String, dynamic> avatar = map['avatar'] as Map<String, dynamic>;
    // Hat under 'top', top under 'bottom' (the v1 field mapping).
    expect(avatar['top'], 'beanie');
    expect(avatar['bottom'], 'longCoat');
  });
}
