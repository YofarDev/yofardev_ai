import '../../models/function_info.dart';

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
  Map<String, String> get requiredConfigKeys => <String, String>{
    'openWeatherKey': 'apiKey',
  };

  @override
  Future<String> execute(
    Map<String, dynamic> args,
    Map<String, dynamic> configValues,
  ) async {
    final String location = args['location'] as String? ?? 'current';

    final String? apiKey = configValues['apiKey'] as String?;

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
  }
}
