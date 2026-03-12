import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/llm_config.dart';
import 'package:yofardev_ai/core/models/task_llm_config.dart';
import 'package:yofardev_ai/core/services/llm/llm_service_interface.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:yofardev_ai/features/settings/presentation/bloc/settings_state.dart';
import 'package:yofardev_ai/core/repositories/settings_repository.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockLlmServiceInterface extends Mock implements LlmServiceInterface {}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(ChatPersona.normal);
    registerFallbackValue(const TaskLlmConfig());
  });

  group('SettingsCubit', () {
    late SettingsCubit cubit;
    late MockSettingsRepository mockSettingsRepo;
    late MockLlmServiceInterface mockLlmService;

    setUp(() {
      mockSettingsRepo = MockSettingsRepository();
      mockLlmService = MockLlmServiceInterface();

      // Stub the init() method to return a completed Future
      when(() => mockLlmService.init()).thenAnswer((_) async {});

      // Stub repository methods with default values
      when(() => mockSettingsRepo.getTaskLlmConfig()).thenAnswer(
        (_) async => const Right<Exception, TaskLlmConfig>(TaskLlmConfig()),
      );
      when(
        () => mockSettingsRepo.setTaskLlmConfig(any()),
      ).thenAnswer((_) async => const Right<Exception, void>(null));
      when(
        () => mockSettingsRepo.setSystemPrompt(any()),
      ).thenAnswer((_) async => const Right<Exception, void>(null));
      when(
        () => mockSettingsRepo.setUsername(any()),
      ).thenAnswer((_) async => const Right<Exception, void>(null));
      when(
        () => mockSettingsRepo.setPersona(any()),
      ).thenAnswer((_) async => const Right<Exception, void>(null));
      when(
        () => mockSettingsRepo.getLanguage(),
      ).thenAnswer((_) async => const Right<Exception, String?>('en'));
      when(
        () => mockSettingsRepo.getSoundEffects(),
      ).thenAnswer((_) async => const Right<Exception, bool>(true));
      when(
        () => mockSettingsRepo.getUsername(),
      ).thenAnswer((_) async => const Right<Exception, String?>('user'));
      when(
        () => mockSettingsRepo.getSystemPrompt(),
      ).thenAnswer((_) async => const Right<Exception, String>('prompt'));
      when(() => mockSettingsRepo.getPersona()).thenAnswer(
        (_) async => const Right<Exception, ChatPersona>(ChatPersona.normal),
      );
      when(
        () => mockSettingsRepo.getGoogleSearchKey(),
      ).thenAnswer((_) async => const Right<Exception, String?>(null));
      when(
        () => mockSettingsRepo.getGoogleSearchEngineId(),
      ).thenAnswer((_) async => const Right<Exception, String?>(null));
      when(
        () => mockSettingsRepo.getGoogleSearchEnabled(),
      ).thenAnswer((_) async => const Right<Exception, bool>(true));
      when(
        () => mockSettingsRepo.getOpenWeatherKey(),
      ).thenAnswer((_) async => const Right<Exception, String?>(null));
      when(
        () => mockSettingsRepo.getOpenWeatherEnabled(),
      ).thenAnswer((_) async => const Right<Exception, bool>(true));
      when(
        () => mockSettingsRepo.getNewYorkTimesKey(),
      ).thenAnswer((_) async => const Right<Exception, String?>(null));
      when(
        () => mockSettingsRepo.getNewYorkTimesEnabled(),
      ).thenAnswer((_) async => const Right<Exception, bool>(true));

      cubit = SettingsCubit(
        settingsRepository: mockSettingsRepo,
        llmService: mockLlmService,
      );
    });

    tearDown(() => cubit.close());

    test('initial state should have default values', () {
      expect(cubit.state.taskLlmConfig, isNull);
      expect(cubit.state.availableLlmConfigs, isEmpty);
    });

    group('loadSettings', () {
      test('should initialize LLM service and load configs', () async {
        final List<LlmConfig> testConfigs = <LlmConfig>[
          const LlmConfig(
            id: 'config1',
            label: 'GPT-4',
            baseUrl: 'https://api.openai.com',
            apiKey: 'key',
            model: 'gpt-4',
          ),
        ];

        when(() => mockLlmService.getAllConfigs()).thenReturn(testConfigs);

        await cubit.loadSettings();

        verify(() => mockLlmService.init()).called(1);
        expect(cubit.state.availableLlmConfigs, testConfigs);
      });

      test('should call loadTaskLlmConfig', () async {
        when(() => mockSettingsRepo.getTaskLlmConfig()).thenAnswer(
          (_) async => const Right<Exception, TaskLlmConfig>(TaskLlmConfig()),
        );

        await cubit.loadSettings();

        verify(() => mockSettingsRepo.getTaskLlmConfig()).called(1);
      });

      test('should handle LLM config loading errors gracefully', () async {
        when(() => mockLlmService.init()).thenAnswer((_) async {});
        when(
          () => mockLlmService.getAllConfigs(),
        ).thenThrow(Exception('Config load failed'));
        when(() => mockSettingsRepo.getTaskLlmConfig()).thenAnswer(
          (_) async => const Right<Exception, TaskLlmConfig>(TaskLlmConfig()),
        );

        await cubit.loadSettings();

        expect(cubit.state.taskLlmConfig, isNotNull);
      });
    });

    group('loadTaskLlmConfig', () {
      test('should load and emit task LLM config', () async {
        const TaskLlmConfig testConfig = TaskLlmConfig(
          assistantLlmId: 'gpt-4-assistant',
          titleGenerationLlmId: 'gpt-4-titles',
        );

        when(
          () => mockSettingsRepo.getTaskLlmConfig(),
        ).thenAnswer((_) async => Right<Exception, TaskLlmConfig>(testConfig));

        expect(cubit.state.taskLlmConfig, isNull);

        await cubit.loadTaskLlmConfig();

        expect(cubit.state.taskLlmConfig, testConfig);
      });

      test('should emit default config on error', () async {
        when(() => mockSettingsRepo.getTaskLlmConfig()).thenAnswer(
          (_) async => Left<Exception, TaskLlmConfig>(Exception('Load failed')),
        );

        expect(cubit.state.taskLlmConfig, isNull);

        await cubit.loadTaskLlmConfig();

        expect(cubit.state.taskLlmConfig, const TaskLlmConfig());
      });
    });

    group('setTaskLlmConfig', () {
      test('should save config and emit it on success', () async {
        const TaskLlmConfig testConfig = TaskLlmConfig(
          assistantLlmId: 'gpt-4-assistant',
          functionCallingLlmId: 'claude-3-opus',
        );

        when(
          () => mockSettingsRepo.setTaskLlmConfig(testConfig),
        ).thenAnswer((_) async => const Right<Exception, void>(null));

        await cubit.setTaskLlmConfig(testConfig);

        verify(() => mockSettingsRepo.setTaskLlmConfig(testConfig)).called(1);
        expect(cubit.state.taskLlmConfig, testConfig);
      });

      test('should log error on failure', () async {
        const TaskLlmConfig testConfig = TaskLlmConfig();

        when(() => mockSettingsRepo.setTaskLlmConfig(testConfig)).thenAnswer(
          (_) async => Left<Exception, void>(Exception('Save failed')),
        );

        await cubit.setTaskLlmConfig(testConfig);

        expect(cubit.state.taskLlmConfig, isNull);
      });
    });

    group('setSystemPrompt', () {
      test('should save system prompt via repository', () async {
        const String testPrompt = 'You are a helpful assistant';

        when(
          () => mockSettingsRepo.setSystemPrompt(testPrompt),
        ).thenAnswer((_) async => const Right<Exception, void>(null));

        await cubit.setSystemPrompt(testPrompt);

        verify(() => mockSettingsRepo.setSystemPrompt(testPrompt)).called(1);
      });

      test('should log error on failure', () async {
        when(() => mockSettingsRepo.setSystemPrompt(any())).thenAnswer(
          (_) async => Left<Exception, void>(Exception('Save failed')),
        );

        await cubit.setSystemPrompt('test');

        verify(() => mockSettingsRepo.setSystemPrompt(any())).called(1);
      });
    });

    group('setUsername', () {
      test('should save username via repository', () async {
        const String testUsername = 'JohnDoe';

        when(
          () => mockSettingsRepo.setUsername(testUsername),
        ).thenAnswer((_) async => const Right<Exception, void>(null));

        await cubit.setUsername(testUsername);

        verify(() => mockSettingsRepo.setUsername(testUsername)).called(1);
      });

      test('should log error on failure', () async {
        when(() => mockSettingsRepo.setUsername(any())).thenAnswer(
          (_) async => Left<Exception, void>(Exception('Save failed')),
        );

        await cubit.setUsername('test');

        verify(() => mockSettingsRepo.setUsername(any())).called(1);
      });
    });

    group('setPersona', () {
      test('should save persona via repository', () async {
        const ChatPersona testPersona = ChatPersona.assistant;

        when(
          () => mockSettingsRepo.setPersona(testPersona),
        ).thenAnswer((_) async => const Right<Exception, void>(null));

        await cubit.setPersona(testPersona);

        verify(() => mockSettingsRepo.setPersona(testPersona)).called(1);
      });

      test('should log error on failure', () async {
        when(() => mockSettingsRepo.setPersona(any())).thenAnswer(
          (_) async => Left<Exception, void>(Exception('Save failed')),
        );

        await cubit.setPersona(ChatPersona.assistant);

        verify(() => mockSettingsRepo.setPersona(any())).called(1);
      });
    });

    group('SettingsState', () {
      test('should create with default values', () {
        const SettingsState state = SettingsState();

        expect(state.taskLlmConfig, isNull);
        expect(state.availableLlmConfigs, isEmpty);
      });

      test('should copy with new values', () {
        const SettingsState state = SettingsState();

        final List<LlmConfig> configs = <LlmConfig>[
          const LlmConfig(
            id: 'test',
            label: 'Test',
            baseUrl: 'https://api.test.com',
            apiKey: 'key',
            model: 'model',
          ),
        ];

        const TaskLlmConfig taskConfig = TaskLlmConfig(assistantLlmId: 'gpt-4');

        final SettingsState newState = state.copyWith(
          taskLlmConfig: taskConfig,
          availableLlmConfigs: configs,
        );

        expect(newState.taskLlmConfig, taskConfig);
        expect(newState.availableLlmConfigs, configs);
        expect(newState.availableLlmConfigs, isNot(state.availableLlmConfigs));
      });

      test('should support value equality', () {
        const TaskLlmConfig taskConfig = TaskLlmConfig(assistantLlmId: 'gpt-4');

        final List<LlmConfig> configs = <LlmConfig>[
          const LlmConfig(
            id: 'test',
            label: 'Test',
            baseUrl: 'https://api.test.com',
            apiKey: 'key',
            model: 'model',
          ),
        ];

        final SettingsState state1 = SettingsState(
          taskLlmConfig: taskConfig,
          availableLlmConfigs: configs,
        );

        final SettingsState state2 = SettingsState(
          taskLlmConfig: taskConfig,
          availableLlmConfigs: configs,
        );

        expect(state1, equals(state2));
      });

      test('different states are not equal', () {
        const TaskLlmConfig config1 = TaskLlmConfig(assistantLlmId: 'gpt-4');

        const TaskLlmConfig config2 = TaskLlmConfig(assistantLlmId: 'gpt-3.5');

        const SettingsState state1 = SettingsState(
          taskLlmConfig: config1,
          availableLlmConfigs: <LlmConfig>[],
        );

        const SettingsState state2 = SettingsState(
          taskLlmConfig: config2,
          availableLlmConfigs: <LlmConfig>[],
        );

        expect(state1, isNot(equals(state2)));
      });
    });

    group('Integration scenarios', () {
      test('loadSettings then modify task config', () async {
        final List<LlmConfig> configs = <LlmConfig>[
          const LlmConfig(
            id: 'c1',
            label: 'C1',
            baseUrl: 'u1',
            apiKey: 'k1',
            model: 'm1',
          ),
        ];

        const TaskLlmConfig initialConfig = TaskLlmConfig(
          assistantLlmId: 'gpt-3.5-assistant',
        );

        when(() => mockLlmService.getAllConfigs()).thenReturn(configs);
        when(() => mockSettingsRepo.getTaskLlmConfig()).thenAnswer(
          (_) async => Right<Exception, TaskLlmConfig>(initialConfig),
        );
        when(
          () => mockSettingsRepo.setTaskLlmConfig(any()),
        ).thenAnswer((_) async => const Right<Exception, void>(null));

        await cubit.loadSettings();

        expect(cubit.state.availableLlmConfigs, configs);
        expect(cubit.state.taskLlmConfig, initialConfig);

        const TaskLlmConfig newConfig = TaskLlmConfig(
          assistantLlmId: 'gpt-4-assistant',
        );

        await cubit.setTaskLlmConfig(newConfig);

        expect(cubit.state.taskLlmConfig, newConfig);
        verify(() => mockSettingsRepo.setTaskLlmConfig(newConfig)).called(1);
      });

      test('multiple setting operations in sequence', () async {
        when(
          () => mockSettingsRepo.setSystemPrompt(any()),
        ).thenAnswer((_) async => const Right<Exception, void>(null));
        when(
          () => mockSettingsRepo.setUsername(any()),
        ).thenAnswer((_) async => const Right<Exception, void>(null));
        when(
          () => mockSettingsRepo.setPersona(any()),
        ).thenAnswer((_) async => const Right<Exception, void>(null));

        await cubit.setSystemPrompt('Test prompt');
        await cubit.setUsername('User');
        await cubit.setPersona(ChatPersona.coach);

        verify(() => mockSettingsRepo.setSystemPrompt('Test prompt')).called(1);
        verify(() => mockSettingsRepo.setUsername('User')).called(1);
        verify(() => mockSettingsRepo.setPersona(ChatPersona.coach)).called(1);
      });
    });

    group('Error handling', () {
      test('should continue on LLM service init failure', () async {
        // BUG DETECTED: The cubit does NOT handle init() failures gracefully
        // The init() call is not wrapped in try/catch, so exceptions propagate
        when(() => mockLlmService.init()).thenThrow(Exception('Init failed'));
        when(() => mockSettingsRepo.getTaskLlmConfig()).thenAnswer(
          (_) async => const Right<Exception, TaskLlmConfig>(TaskLlmConfig()),
        );

        // The exception will propagate to the caller (test expects this)
        expect(() => cubit.loadSettings(), throwsA(isA<Exception>()));

        // Because init() failed, loadTaskLlmConfig was never called
        verifyNever(() => mockSettingsRepo.getTaskLlmConfig());
      });

      test('should continue on getAllConfigs failure', () async {
        when(() => mockLlmService.init()).thenAnswer((_) async {});
        when(
          () => mockLlmService.getAllConfigs(),
        ).thenThrow(Exception('Config list failed'));
        when(() => mockSettingsRepo.getTaskLlmConfig()).thenAnswer(
          (_) async => const Right<Exception, TaskLlmConfig>(TaskLlmConfig()),
        );

        await cubit.loadSettings();

        expect(cubit.state.availableLlmConfigs, isEmpty);
        expect(cubit.state.taskLlmConfig, isNotNull);
      });

      test('all setters should handle errors gracefully', () async {
        when(() => mockSettingsRepo.setSystemPrompt(any())).thenAnswer(
          (_) async => Left<Exception, void>(Exception('Prompt failed')),
        );
        when(() => mockSettingsRepo.setUsername(any())).thenAnswer(
          (_) async => Left<Exception, void>(Exception('Username failed')),
        );
        when(() => mockSettingsRepo.setPersona(any())).thenAnswer(
          (_) async => Left<Exception, void>(Exception('Persona failed')),
        );

        await cubit.setSystemPrompt('test');
        await cubit.setUsername('test');
        await cubit.setPersona(ChatPersona.assistant);

        verify(() => mockSettingsRepo.setSystemPrompt(any())).called(1);
        verify(() => mockSettingsRepo.setUsername(any())).called(1);
        verify(() => mockSettingsRepo.setPersona(any())).called(1);
      });
    });

    group('TaskLlmConfig value equality', () {
      test('equal configs should be equal', () {
        const TaskLlmConfig config1 = TaskLlmConfig(
          assistantLlmId: 'gpt-4',
          titleGenerationLlmId: 'gpt-3.5',
        );

        const TaskLlmConfig config2 = TaskLlmConfig(
          assistantLlmId: 'gpt-4',
          titleGenerationLlmId: 'gpt-3.5',
        );

        expect(config1, equals(config2));
      });

      test('different models should not be equal', () {
        const TaskLlmConfig config1 = TaskLlmConfig(assistantLlmId: 'gpt-4');

        const TaskLlmConfig config2 = TaskLlmConfig(assistantLlmId: 'gpt-3.5');

        expect(config1, isNot(equals(config2)));
      });

      test('different temperatures should not be equal', () {
        const TaskLlmConfig config1 = TaskLlmConfig(
          titleGenerationLlmId: 'gpt-4',
        );

        const TaskLlmConfig config2 = TaskLlmConfig(
          titleGenerationLlmId: 'gpt-3.5',
        );

        expect(config1, isNot(equals(config2)));
      });
    });

    group('LlmConfig list handling', () {
      test('should handle empty config list', () async {
        when(() => mockLlmService.getAllConfigs()).thenReturn(<LlmConfig>[]);
        when(() => mockSettingsRepo.getTaskLlmConfig()).thenAnswer(
          (_) async => const Right<Exception, TaskLlmConfig>(TaskLlmConfig()),
        );

        await cubit.loadSettings();

        expect(cubit.state.availableLlmConfigs, isEmpty);
        expect(cubit.state.taskLlmConfig, isNotNull);
      });

      test('should handle multiple configs', () async {
        final List<LlmConfig> configs = <LlmConfig>[
          const LlmConfig(
            id: 'c1',
            label: 'Config 1',
            baseUrl: 'https://api1.com',
            apiKey: 'key1',
            model: 'model1',
          ),
          const LlmConfig(
            id: 'c2',
            label: 'Config 2',
            baseUrl: 'https://api2.com',
            apiKey: 'key2',
            model: 'model2',
          ),
          const LlmConfig(
            id: 'c3',
            label: 'Config 3',
            baseUrl: 'https://api3.com',
            apiKey: 'key3',
            model: 'model3',
          ),
        ];

        when(() => mockLlmService.getAllConfigs()).thenReturn(configs);
        when(() => mockSettingsRepo.getTaskLlmConfig()).thenAnswer(
          (_) async => const Right<Exception, TaskLlmConfig>(TaskLlmConfig()),
        );

        await cubit.loadSettings();

        expect(cubit.state.availableLlmConfigs.length, 3);
        expect(cubit.state.availableLlmConfigs, configs);
      });
    });

    group('Edge cases', () {
      test('calling loadSettings multiple times', () async {
        when(() => mockLlmService.getAllConfigs()).thenReturn(<LlmConfig>[]);
        when(() => mockSettingsRepo.getTaskLlmConfig()).thenAnswer(
          (_) async => const Right<Exception, TaskLlmConfig>(TaskLlmConfig()),
        );

        await cubit.loadSettings();
        await cubit.loadSettings();
        await cubit.loadSettings();

        verify(() => mockLlmService.init()).called(3);
      });

      test('setting same config multiple times', () async {
        const TaskLlmConfig config = TaskLlmConfig(assistantLlmId: 'gpt-4');

        when(
          () => mockSettingsRepo.setTaskLlmConfig(config),
        ).thenAnswer((_) async => const Right<Exception, void>(null));

        await cubit.setTaskLlmConfig(config);
        await cubit.setTaskLlmConfig(config);
        await cubit.setTaskLlmConfig(config);

        verify(() => mockSettingsRepo.setTaskLlmConfig(config)).called(3);
      });

      test('empty values handling', () async {
        when(
          () => mockSettingsRepo.setSystemPrompt(''),
        ).thenAnswer((_) async => const Right<Exception, void>(null));
        when(
          () => mockSettingsRepo.setUsername(''),
        ).thenAnswer((_) async => const Right<Exception, void>(null));
        when(
          () => mockSettingsRepo.setPersona(ChatPersona.assistant),
        ).thenAnswer((_) async => const Right<Exception, void>(null));

        await cubit.setSystemPrompt('');
        await cubit.setUsername('');
        await cubit.setPersona(ChatPersona.assistant);

        verify(() => mockSettingsRepo.setSystemPrompt('')).called(1);
        verify(() => mockSettingsRepo.setUsername('')).called(1);
        verify(
          () => mockSettingsRepo.setPersona(ChatPersona.assistant),
        ).called(1);
      });
    });
  });
}
