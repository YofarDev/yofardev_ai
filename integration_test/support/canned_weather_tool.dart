import 'dart:convert';

import 'package:yofardev_ai/core/models/function_info.dart';
import 'package:yofardev_ai/core/models/weather_report.dart';
import 'package:yofardev_ai/core/services/agent/agent_tool.dart';

/// `getCurrentWeather` with a canned Tokyo answer after [delay] (M6 ruling
/// 3): the storyboard's tool runs long enough for the tablet to come out and
/// the eyes to scan it, and the real tool (the owner's OpenWeather key, the
/// network) is never called.
class CannedWeatherTool extends AgentTool {
  CannedWeatherTool({
    this.delay = const Duration(milliseconds: 2500),
    this.onReport,
  });

  final Duration delay;

  /// M8: hears the canned report like the real tool's `onReport` (any city),
  /// so the tablet's weather card shows Tokyo's light rain at 18 °C.
  final void Function(WeatherReport report)? onReport;

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
  Map<String, String> get requiredConfigKeys => const <String, String>{};

  @override
  Future<String> execute(
    Map<String, dynamic> args,
    Map<String, dynamic> configValues,
  ) async {
    await Future<void>.delayed(delay);
    onReport?.call(
      const WeatherReport(
        conditionId: 500,
        rainMmPerHour: 0.6,
        temperatureC: 18,
      ),
    );
    return jsonEncode(<String, Object>{
      'location': args['location'] as String? ?? 'Tokyo',
      'description': 'light rain',
      'temperature': 18,
      'feels_like': 17,
      'humidity': 82,
      'wind_speed': 3.1,
    });
  }
}
