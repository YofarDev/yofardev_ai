import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yofardev_ai/core/design/theme/app_theme.dart';
import 'package:yofardev_ai/core/l10n/generated/app_localizations.dart';
import 'package:yofardev_ai/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:yofardev_ai/features/settings/screens/function_calling_config_screen.dart';
import 'package:yofardev_ai/core/repositories/settings_repository.dart';
import 'package:yofardev_ai/features/settings/widgets/function_calling_section.dart';
import 'package:yofardev_ai/core/services/llm/llm_service_interface.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/task_llm_config.dart';
import 'package:yofardev_ai/core/models/llm_config.dart';
import 'package:yofardev_ai/core/models/llm_message.dart';
import 'package:yofardev_ai/core/models/function_info.dart';
import 'package:yofardev_ai/core/models/llm_task_type.dart';

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
  Future<Result<String?>> getLanguage() async {
    return Result<String?>.ok('en');
  }

  @override
  Future<Result<void>> setLanguage(String language) async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<bool>> getSoundEffects() async {
    return Result<bool>.ok(true);
  }

  @override
  Future<Result<void>> setSoundEffects(bool soundEffects) async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<String?>> getUsername() async {
    return Result<String?>.ok(null);
  }

  @override
  Future<Result<void>> setUsername(String username) async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<String>> getSystemPrompt() async {
    return Result<String>.ok('');
  }

  @override
  Future<Result<void>> setSystemPrompt(String prompt) async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<ChatPersona>> getPersona() async {
    return Result<ChatPersona>.ok(ChatPersona.assistant);
  }

  @override
  Future<Result<void>> setPersona(ChatPersona persona) async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<TaskLlmConfig>> getTaskLlmConfig() async {
    return Result<TaskLlmConfig>.ok(TaskLlmConfig());
  }

  @override
  Future<Result<void>> setTaskLlmConfig(TaskLlmConfig config) async {
    return Result<void>.ok(null);
  }

  // Google Search Configuration
  @override
  Future<Result<String?>> getGoogleSearchKey() async {
    return Result<String?>.ok(_googleSearchKey);
  }

  @override
  Future<Result<void>> setGoogleSearchKey(String key) async {
    _googleSearchKey = key;
    googleSearchKeyUpdateCount++;
    return Result<void>.ok(null);
  }

  @override
  Future<Result<String?>> getGoogleSearchEngineId() async {
    return Result<String?>.ok(_googleSearchEngineId);
  }

  @override
  Future<Result<void>> setGoogleSearchEngineId(String id) async {
    _googleSearchEngineId = id;
    googleSearchEngineIdUpdateCount++;
    return Result<void>.ok(null);
  }

  @override
  Future<Result<bool>> getGoogleSearchEnabled() async {
    return Result<bool>.ok(_googleSearchEnabled);
  }

  @override
  Future<Result<void>> setGoogleSearchEnabled(bool enabled) async {
    _googleSearchEnabled = enabled;
    googleSearchEnabledUpdateCount++;
    return Result<void>.ok(null);
  }

  // OpenWeather Configuration
  @override
  Future<Result<String?>> getOpenWeatherKey() async {
    return Result<String?>.ok(_openWeatherKey);
  }

  @override
  Future<Result<void>> setOpenWeatherKey(String key) async {
    _openWeatherKey = key;
    openWeatherKeyUpdateCount++;
    return Result<void>.ok(null);
  }

  @override
  Future<Result<bool>> getOpenWeatherEnabled() async {
    return Result<bool>.ok(_openWeatherEnabled);
  }

  @override
  Future<Result<void>> setOpenWeatherEnabled(bool enabled) async {
    _openWeatherEnabled = enabled;
    openWeatherEnabledUpdateCount++;
    return Result<void>.ok(null);
  }

  // New York Times Configuration
  @override
  Future<Result<String?>> getNewYorkTimesKey() async {
    return Result<String?>.ok(_newYorkTimesKey);
  }

  @override
  Future<Result<void>> setNewYorkTimesKey(String key) async {
    _newYorkTimesKey = key;
    newYorkTimesKeyUpdateCount++;
    return Result<void>.ok(null);
  }

  @override
  Future<Result<bool>> getNewYorkTimesEnabled() async {
    return Result<bool>.ok(_newYorkTimesEnabled);
  }

  @override
  Future<Result<void>> setNewYorkTimesEnabled(bool enabled) async {
    _newYorkTimesEnabled = enabled;
    newYorkTimesEnabledUpdateCount++;
    return Result<void>.ok(null);
  }

  // Global Memory Configuration
  @override
  Future<Result<bool>> getMemoryEnabled() async {
    return Result<bool>.ok(true);
  }

  @override
  Future<Result<void>> setMemoryEnabled(bool enabled) async {
    return Result<void>.ok(null);
  }

  @override
  Future<Result<bool>> getCaptionsEnabled() async => Result<bool>.ok(true);

  @override
  Future<Result<void>> setCaptionsEnabled(bool enabled) async =>
      Result<void>.ok(null);
}

/// Mock LlmServiceInterface using mocktail
class MockLlmService extends Mock implements LlmServiceInterface {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();

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

    AppLocalizations l10n(WidgetTester tester) {
      return AppLocalizations.of(
        tester.element(find.byType(FunctionCallingConfigScreen)),
      );
    }

    Finder sectionByTitle(String title) {
      return find.ancestor(
        of: find.text(title),
        matching: find.byType(FunctionCallingSection),
      );
    }

    Finder textFieldsInSection(String title) {
      return find.descendant(
        of: sectionByTitle(title),
        matching: find.byType(TextField),
      );
    }

    Finder switchInSection(String title) {
      return find.descendant(
        of: sectionByTitle(title),
        matching: find.byType(Switch),
      );
    }

    testWidgets(
      'Full flow: configure Google Search API key → enable → persist',
      (WidgetTester tester) async {
        // Arrange: Create the widget tree
        await tester.pumpWidget(
          buildTestApp(
            child: BlocProvider<SettingsCubit>(
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

        final AppLocalizations strings = l10n(tester);
        await tester.enterText(
          textFieldsInSection(strings.settings_googleSearch).first,
          'test-google-key',
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          textFieldsInSection(strings.settings_googleSearch).at(1),
          'test-engine-id',
        );
        await tester.pumpAndSettle();

        final Switch firstSwitch = tester.widget<Switch>(
          switchInSection(strings.settings_googleSearch),
        );
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
        buildTestApp(
          child: BlocProvider<SettingsCubit>(
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

      final AppLocalizations strings = l10n(tester);
      await tester.tap(switchInSection(strings.settings_googleSearch));
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
        buildTestApp(
          child: BlocProvider<SettingsCubit>(
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

      final AppLocalizations strings = l10n(tester);
      await tester.enterText(
        textFieldsInSection(strings.settings_weather).first,
        'test-openweather-key',
      );
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
          buildTestApp(
            child: BlocProvider<SettingsCubit>(
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

        final AppLocalizations strings = l10n(tester);
        await tester.enterText(
          textFieldsInSection(strings.settings_news).first,
          'test-nyt-key',
        );
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
        buildTestApp(
          child: BlocProvider<SettingsCubit>(
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

      final AppLocalizations strings = l10n(tester);
      await tester.enterText(
        textFieldsInSection(strings.settings_googleSearch).first,
        'google-key',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        textFieldsInSection(strings.settings_googleSearch).at(1),
        'engine-id',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        textFieldsInSection(strings.settings_weather).first,
        'weather-key',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        textFieldsInSection(strings.settings_news).first,
        'nyt-key',
      );
      await tester.pumpAndSettle();

      await tester.tap(switchInSection(strings.settings_googleSearch));
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

Widget buildTestApp({required Widget child}) {
  return MaterialApp(
    theme: AppTheme.dark,
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}
