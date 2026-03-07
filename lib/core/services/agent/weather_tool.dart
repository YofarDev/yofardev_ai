import 'package:fpdart/src/either.dart';

import '../../models/function_info.dart';
import '../../../features/settings/domain/repositories/settings_repository.dart';

import 'weather_service.dart';
import 'agent_tool.dart';

class WeatherTool extends AgentTool {
  @override
  String get name => 'getCurrentWeather';

  @override
  String get description => 'Returns the current weather';

  @override
  List<Parameter> get parameters => <Parameter>[
    Parameter(
      name: 'location',
      description: 'The location to get the weather for',
      type: 'string',
    ),
  ];

  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    required SettingsRepository settingsRepository,
  }) async {
    final String location = args['location'] as String? ?? 'current';

    // Get API key from settings
    final Either<Exception, String?> apiKeyResult = await settingsRepository.getOpenWeatherKey();

    return apiKeyResult.fold(
      (Exception error) => 'Error: OpenWeather API key not configured',
      (String? apiKey) async {
        if (apiKey == null || apiKey.isEmpty) {
          return 'Error: OpenWeather API key not configured';
        }

        try {
          return await WeatherService.getCurrentWeather(
            location,
            apiKey,
          );
        } catch (e) {
          return 'Error getting weather: $e';
        }
      },
    );
  }
}
