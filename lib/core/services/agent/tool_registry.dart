import 'package:fpdart/fpdart.dart';

import '../../repositories/settings_repository.dart';
import '../../models/function_info.dart';
import 'agent_tool.dart';
import 'alarm_tool.dart';
import 'avatar_tool.dart';
import 'calculator_tool.dart';
import 'character_counter_tool.dart';
import 'google_search_tool.dart';
import 'news_tool.dart';
import 'weather_tool.dart';
import 'web_reader_tool.dart';

export 'agent_tool.dart';

class ToolRegistry {
  final List<AgentTool> _tools;

  ToolRegistry({List<AgentTool>? tools})
    : _tools =
          tools ??
          <AgentTool>[
            AlarmTool(),
            AvatarTool(),
            WeatherTool(),
            NewsTool(),
            CharacterCounterTool(),
            CalculatorTool(),
            GoogleSearchTool(),
            WebReaderTool(),
          ];

  List<AgentTool> get tools => List<AgentTool>.unmodifiable(_tools);

  AgentTool? getTool(String name) {
    try {
      return _tools.firstWhere((AgentTool tool) => tool.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Returns the list of FunctionInfo for LlmService
  List<FunctionInfo> get functionInfos {
    return _tools.map((AgentTool t) => t.toFunctionInfo()).toList();
  }

  /// Returns a filtered list of FunctionInfo based on settings configuration.
  /// Only includes tools that:
  /// - Have API keys configured (if required)
  /// - Are enabled in settings
  Future<List<FunctionInfo>> getFunctionInfos(
    SettingsRepository settingsRepository,
  ) async {
    final List<FunctionInfo> filteredFunctions = <FunctionInfo>[];

    // Always include tools that don't require API keys
    filteredFunctions.add(AlarmTool().toFunctionInfo());
    filteredFunctions.add(AvatarTool().toFunctionInfo());
    filteredFunctions.add(CharacterCounterTool().toFunctionInfo());
    filteredFunctions.add(CalculatorTool().toFunctionInfo());
    filteredFunctions.add(WebReaderTool().toFunctionInfo());

    // Google Search - requires API key, engine ID, and enabled flag
    final Either<Exception, String?> googleKeyResult = await settingsRepository
        .getGoogleSearchKey();
    final Either<Exception, String?> googleEngineResult =
        await settingsRepository.getGoogleSearchEngineId();
    final Either<Exception, bool> googleEnabledResult = await settingsRepository
        .getGoogleSearchEnabled();

    final bool googleConfigured = googleKeyResult.fold(
      (Exception error) => false,
      (String? key) => key != null && key.isNotEmpty,
    );
    final bool googleEngineConfigured = googleEngineResult.fold(
      (Exception error) => false,
      (String? id) => id != null && id.isNotEmpty,
    );
    final bool googleEnabled = googleEnabledResult.fold(
      (Exception error) => false,
      (bool enabled) => enabled,
    );

    if (googleConfigured && googleEngineConfigured && googleEnabled) {
      filteredFunctions.add(GoogleSearchTool().toFunctionInfo());
    }

    // Weather - requires API key and enabled flag
    final Either<Exception, String?> weatherKeyResult = await settingsRepository
        .getOpenWeatherKey();
    final Either<Exception, bool> weatherEnabledResult =
        await settingsRepository.getOpenWeatherEnabled();

    final bool weatherConfigured = weatherKeyResult.fold(
      (Exception error) => false,
      (String? key) => key != null && key.isNotEmpty,
    );
    final bool weatherEnabled = weatherEnabledResult.fold(
      (Exception error) => false,
      (bool enabled) => enabled,
    );

    if (weatherConfigured && weatherEnabled) {
      filteredFunctions.add(WeatherTool().toFunctionInfo());
    }

    // News - requires API key and enabled flag
    final Either<Exception, String?> newsKeyResult = await settingsRepository
        .getNewYorkTimesKey();
    final Either<Exception, bool> newsEnabledResult = await settingsRepository
        .getNewYorkTimesEnabled();

    final bool newsConfigured = newsKeyResult.fold(
      (Exception error) => false,
      (String? key) => key != null && key.isNotEmpty,
    );
    final bool newsEnabled = newsEnabledResult.fold(
      (Exception error) => false,
      (bool enabled) => enabled,
    );

    if (newsConfigured && newsEnabled) {
      filteredFunctions.add(NewsTool().toFunctionInfo());
    }

    return filteredFunctions;
  }

  /// Executes a tool with the provided arguments and settings repository.
  /// Fetches the required configuration values and passes them to the tool.
  Future<dynamic> executeTool(
    AgentTool tool,
    Map<String, dynamic> args,
    SettingsRepository settingsRepository,
  ) async {
    // Fetch required configuration values based on the tool's requirements
    final Map<String, dynamic> configValues = <String, dynamic>{};

    for (final MapEntry<String, String> entry
        in tool.requiredConfigKeys.entries) {
      final String settingKey = entry.key;
      final String paramName = entry.value;

      final dynamic value = await _getSettingValue(
        settingsRepository,
        settingKey,
      );
      configValues[paramName] = value;
    }

    // Execute the tool with the fetched configuration values
    return tool.execute(args, configValues);
  }

  /// Helper method to fetch a setting value from the repository.
  Future<dynamic> _getSettingValue(
    SettingsRepository settingsRepository,
    String settingKey,
  ) async {
    final Either<Exception, dynamic> result;

    switch (settingKey) {
      case 'googleSearchKey':
        result = await settingsRepository.getGoogleSearchKey();
        break;
      case 'googleSearchEngineId':
        result = await settingsRepository.getGoogleSearchEngineId();
        break;
      case 'openWeatherKey':
        result = await settingsRepository.getOpenWeatherKey();
        break;
      case 'newYorkTimesKey':
        result = await settingsRepository.getNewYorkTimesKey();
        break;
      default:
        throw UnsupportedError('Unknown setting key: $settingKey');
    }

    return result.fold((Exception error) => null, (dynamic value) => value);
  }
}
