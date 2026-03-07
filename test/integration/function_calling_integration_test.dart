import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yofardev_ai/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:yofardev_ai/features/settings/screens/function_calling_config_screen.dart';
import 'package:yofardev_ai/features/settings/domain/repositories/settings_repository.dart';
import 'package:yofardev_ai/core/services/llm/llm_service_interface.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/task_llm_config.dart';
import 'package:yofardev_ai/core/models/llm_config.dart';
import 'package:yofardev_ai/core/models/llm_message.dart';
import 'package:yofardev_ai/core/models/function_info.dart';
import 'package:yofardev_ai/core/models/llm_task_type.dart';
import 'package:yofardev_ai/l10n/localization_manager.dart';

/// Mock SettingsRepository that tracks updates in memory
class InMemorySettingsRepository implements SettingsRepository {
  String? _googleSearchKey;
  String? _googleSearchEngineId;
  bool _googleSearchEnabled = true;

  String? _openWeatherKey;
  bool _openWeatherEnabled = true;

  String? _newYorkTimesKey;
  bool _newYorkTimesEnabled = true;

  // Trackers for verification
  int googleSearchKeyUpdateCount = 0;
  int googleSearchEngineIdUpdateCount = 0;
  int googleSearchEnabledUpdateCount = 0;
  int openWeatherKeyUpdateCount = 0;
  int openWeatherEnabledUpdateCount = 0;
  int newYorkTimesKeyUpdateCount = 0;
  int newYorkTimesEnabledUpdateCount = 0;

  @override
  Future<Either<Exception, String?>> getLanguage() async {
    return const Right<Exception, String?>('en');
  }

  @override
  Future<Either<Exception, void>> setLanguage(String language) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, bool>> getSoundEffects() async {
    return const Right<Exception, bool>(true);
  }

  @override
  Future<Either<Exception, void>> setSoundEffects(bool soundEffects) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, String?>> getUsername() async {
    return const Right<Exception, String?>(null);
  }

  @override
  Future<Either<Exception, void>> setUsername(String username) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, String>> getSystemPrompt() async {
    return const Right<Exception, String>('');
  }

  @override
  Future<Either<Exception, void>> setSystemPrompt(String prompt) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, ChatPersona>> getPersona() async {
    return const Right<Exception, ChatPersona>(ChatPersona.assistant);
  }

  @override
  Future<Either<Exception, void>> setPersona(ChatPersona persona) async {
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, TaskLlmConfig>> getTaskLlmConfig() async {
    return const Right<Exception, TaskLlmConfig>(TaskLlmConfig());
  }

  @override
  Future<Either<Exception, void>> setTaskLlmConfig(TaskLlmConfig config) async {
    return const Right<Exception, void>(null);
  }

  // Google Search Configuration
  @override
  Future<Either<Exception, String?>> getGoogleSearchKey() async {
    return Right<Exception, String?>(_googleSearchKey);
  }

  @override
  Future<Either<Exception, void>> setGoogleSearchKey(String key) async {
    _googleSearchKey = key;
    googleSearchKeyUpdateCount++;
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, String?>> getGoogleSearchEngineId() async {
    return Right<Exception, String?>(_googleSearchEngineId);
  }

  @override
  Future<Either<Exception, void>> setGoogleSearchEngineId(String id) async {
    _googleSearchEngineId = id;
    googleSearchEngineIdUpdateCount++;
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, bool>> getGoogleSearchEnabled() async {
    return Right<Exception, bool>(_googleSearchEnabled);
  }

  @override
  Future<Either<Exception, void>> setGoogleSearchEnabled(bool enabled) async {
    _googleSearchEnabled = enabled;
    googleSearchEnabledUpdateCount++;
    return const Right<Exception, void>(null);
  }

  // OpenWeather Configuration
  @override
  Future<Either<Exception, String?>> getOpenWeatherKey() async {
    return Right<Exception, String?>(_openWeatherKey);
  }

  @override
  Future<Either<Exception, void>> setOpenWeatherKey(String key) async {
    _openWeatherKey = key;
    openWeatherKeyUpdateCount++;
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, bool>> getOpenWeatherEnabled() async {
    return Right<Exception, bool>(_openWeatherEnabled);
  }

  @override
  Future<Either<Exception, void>> setOpenWeatherEnabled(bool enabled) async {
    _openWeatherEnabled = enabled;
    openWeatherEnabledUpdateCount++;
    return const Right<Exception, void>(null);
  }

  // New York Times Configuration
  @override
  Future<Either<Exception, String?>> getNewYorkTimesKey() async {
    return Right<Exception, String?>(_newYorkTimesKey);
  }

  @override
  Future<Either<Exception, void>> setNewYorkTimesKey(String key) async {
    _newYorkTimesKey = key;
    newYorkTimesKeyUpdateCount++;
    return const Right<Exception, void>(null);
  }

  @override
  Future<Either<Exception, bool>> getNewYorkTimesEnabled() async {
    return Right<Exception, bool>(_newYorkTimesEnabled);
  }

  @override
  Future<Either<Exception, void>> setNewYorkTimesEnabled(bool enabled) async {
    _newYorkTimesEnabled = enabled;
    newYorkTimesEnabledUpdateCount++;
    return const Right<Exception, void>(null);
  }
}

/// Mock LlmServiceInterface using mocktail
class MockLlmService extends Mock implements LlmServiceInterface {}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationManager().initialize('en');

    // Register fallback values for mocktail
    registerFallbackValue(
      const LlmConfig(
        id: 'test-id',
        label: 'Test',
        baseUrl: 'https://test.com',
        apiKey: 'key',
        model: 'model',
      ),
    );
    registerFallbackValue(LlmTaskType.titleGeneration);
    registerFallbackValue(<LlmMessage>[]);
    registerFallbackValue(
      FunctionInfo(
        name: 'test',
        description: 'test',
        parameters: <Parameter>[],
        function: (Map<String, dynamic> args) async => null,
      ),
    );
    registerFallbackValue(<FunctionInfo>[]);
  });

  group('Function Calling Configuration Integration Tests', () {
    late InMemorySettingsRepository settingsRepository;
    late MockLlmService mockLlmService;
    late SettingsCubit settingsCubit;

    setUp(() {
      settingsRepository = InMemorySettingsRepository();
      mockLlmService = MockLlmService();

      // Stub the init() method to return a completed Future
      when(() => mockLlmService.init()).thenAnswer((_) async {});
    });

    tearDown(() {
      settingsCubit.close();
    });

    testWidgets(
      'Full flow: configure Google Search API key → enable → persist',
      (WidgetTester tester) async {
        // Arrange: Create the widget tree
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<SettingsCubit>(
              create: (BuildContext context) {
                settingsCubit = SettingsCubit(
                  settingsRepository: settingsRepository,
                  llmService: mockLlmService,
                );
                return settingsCubit;
              },
              child: const FunctionCallingConfigScreen(),
            ),
          ),
        );

        // Wait for the widget to settle
        await tester.pumpAndSettle();

        // Act: Enter Google Search API key
        final Finder apiKeyTextField = find.widgetWithText(
          TextField,
          'API Key',
        );
        await tester.enterText(apiKeyTextField.first, 'test-google-key');
        await tester.pumpAndSettle();

        // Act: Enter Engine ID
        final Finder engineIdTextField = find.widgetWithText(
          TextField,
          'Search Engine ID',
        );
        await tester.enterText(engineIdTextField, 'test-engine-id');
        await tester.pumpAndSettle();

        // Act: Verify toggle is enabled by default
        final Finder switchWidget = find.byType(Switch);
        expect(switchWidget, findsWidgets);

        // Get the first switch (Google Search enable switch)
        Switch firstSwitch = tester.widget<Switch>(switchWidget.first);
        expect(firstSwitch.value, true);

        // Act: Tap the save button to trigger save
        final Finder saveButton = find.byIcon(Icons.save);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Assert: Verify state was updated
        expect(settingsCubit.state.googleSearchKey, 'test-google-key');
        expect(settingsCubit.state.googleSearchEngineId, 'test-engine-id');
        expect(settingsCubit.state.googleSearchEnabled, true);

        // Assert: Verify data was persisted in repository
        expect(settingsRepository.googleSearchKeyUpdateCount, 1);
        expect(settingsRepository.googleSearchEngineIdUpdateCount, 1);
      },
    );

    testWidgets('Full flow: toggle Google Search disabled → persist', (
      WidgetTester tester,
    ) async {
      // Arrange: Create the widget tree
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<SettingsCubit>(
            create: (BuildContext context) {
              settingsCubit = SettingsCubit(
                settingsRepository: settingsRepository,
                llmService: mockLlmService,
              );
              return settingsCubit;
            },
            child: const FunctionCallingConfigScreen(),
          ),
        ),
      );

      // Wait for the widget to settle
      await tester.pumpAndSettle();

      // Act: Find and tap the first switch (Google Search enable switch)
      final Finder switchWidget = find.byType(Switch);
      await tester.tap(switchWidget.first);
      await tester.pumpAndSettle();

      // Act: Tap the save button
      final Finder saveButton = find.byIcon(Icons.save);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Assert: Verify disabled state
      expect(settingsCubit.state.googleSearchEnabled, false);

      // Assert: Verify data was persisted in repository
      expect(settingsRepository.googleSearchEnabledUpdateCount, 1);
    });

    testWidgets('Full flow: configure OpenWeather API key → enable → persist', (
      WidgetTester tester,
    ) async {
      // Arrange: Create the widget tree
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<SettingsCubit>(
            create: (BuildContext context) {
              settingsCubit = SettingsCubit(
                settingsRepository: settingsRepository,
                llmService: mockLlmService,
              );
              return settingsCubit;
            },
            child: const FunctionCallingConfigScreen(),
          ),
        ),
      );

      // Wait for the widget to settle
      await tester.pumpAndSettle();

      // Act: Find OpenWeather API key text field
      // There are multiple "API Key" text fields, so we need to find the second one
      final Finder apiKeyTextFields = find.widgetWithText(TextField, 'API Key');
      expect(apiKeyTextFields, findsAtLeastNWidgets(2));

      // Enter OpenWeather API key in the second field
      await tester.enterText(apiKeyTextFields.at(1), 'test-openweather-key');
      await tester.pumpAndSettle();

      // Act: Tap the save button
      final Finder saveButton = find.byIcon(Icons.save);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Assert: Verify state was updated
      expect(settingsCubit.state.openWeatherKey, 'test-openweather-key');
      expect(settingsCubit.state.openWeatherEnabled, true);

      // Assert: Verify data was persisted in repository
      expect(settingsRepository.openWeatherKeyUpdateCount, 1);
    });

    testWidgets(
      'Full flow: configure New York Times API key → enable → persist',
      (WidgetTester tester) async {
        // Arrange: Create the widget tree
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<SettingsCubit>(
              create: (BuildContext context) {
                settingsCubit = SettingsCubit(
                  settingsRepository: settingsRepository,
                  llmService: mockLlmService,
                );
                return settingsCubit;
              },
              child: const FunctionCallingConfigScreen(),
            ),
          ),
        );

        // Wait for the widget to settle
        await tester.pumpAndSettle();

        // Act: Find New York Times API key text field (third "API Key" field)
        final Finder apiKeyTextFields = find.widgetWithText(
          TextField,
          'API Key',
        );
        expect(apiKeyTextFields, findsAtLeastNWidgets(3));

        // Enter NYT API key in the third field
        await tester.enterText(apiKeyTextFields.at(2), 'test-nyt-key');
        await tester.pumpAndSettle();

        // Act: Tap the save button
        final Finder saveButton = find.byIcon(Icons.save);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Assert: Verify state was updated
        expect(settingsCubit.state.newYorkTimesKey, 'test-nyt-key');
        expect(settingsCubit.state.newYorkTimesEnabled, true);

        // Assert: Verify data was persisted in repository
        expect(settingsRepository.newYorkTimesKeyUpdateCount, 1);
      },
    );

    testWidgets('Full flow: configure all three services → persist all', (
      WidgetTester tester,
    ) async {
      // Arrange: Create the widget tree
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<SettingsCubit>(
            create: (BuildContext context) {
              settingsCubit = SettingsCubit(
                settingsRepository: settingsRepository,
                llmService: mockLlmService,
              );
              return settingsCubit;
            },
            child: const FunctionCallingConfigScreen(),
          ),
        ),
      );

      // Wait for the widget to settle
      await tester.pumpAndSettle();

      // Act: Find all API key text fields
      final Finder apiKeyTextFields = find.widgetWithText(TextField, 'API Key');
      expect(apiKeyTextFields, findsAtLeastNWidgets(3));

      // Enter Google Search API key
      await tester.enterText(apiKeyTextFields.at(0), 'google-key');
      await tester.pumpAndSettle();

      // Enter Engine ID
      final Finder engineIdTextField = find.widgetWithText(
        TextField,
        'Search Engine ID',
      );
      await tester.enterText(engineIdTextField, 'engine-id');
      await tester.pumpAndSettle();

      // Enter OpenWeather API key
      await tester.enterText(apiKeyTextFields.at(1), 'weather-key');
      await tester.pumpAndSettle();

      // Enter NYT API key
      await tester.enterText(apiKeyTextFields.at(2), 'nyt-key');
      await tester.pumpAndSettle();

      // Disable Google Search
      final Finder switchWidgets = find.byType(Switch);
      await tester.tap(switchWidgets.at(0));
      await tester.pumpAndSettle();

      // Act: Tap the save button
      final Finder saveButton = find.byIcon(Icons.save);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Assert: Verify all states were updated
      expect(settingsCubit.state.googleSearchKey, 'google-key');
      expect(settingsCubit.state.googleSearchEngineId, 'engine-id');
      expect(settingsCubit.state.googleSearchEnabled, false);
      expect(settingsCubit.state.openWeatherKey, 'weather-key');
      expect(settingsCubit.state.openWeatherEnabled, true);
      expect(settingsCubit.state.newYorkTimesKey, 'nyt-key');
      expect(settingsCubit.state.newYorkTimesEnabled, true);

      // Assert: Verify all data was persisted in repository
      expect(settingsRepository.googleSearchKeyUpdateCount, 1);
      expect(settingsRepository.googleSearchEngineIdUpdateCount, 1);
      expect(settingsRepository.googleSearchEnabledUpdateCount, 1);
      expect(settingsRepository.openWeatherKeyUpdateCount, 1);
      expect(settingsRepository.newYorkTimesKeyUpdateCount, 1);
    });
  });
}
