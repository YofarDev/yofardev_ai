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
  Future<String> execute(Map<String, dynamic> args) async {
    final String location = args['location'] as String? ?? 'current';
    // TODO: Pass API key from settings in Task 13
    return await WeatherService.getCurrentWeather(
      location,
      '', // apiKey - will be passed from settings in Task 13
    );
  }
}
