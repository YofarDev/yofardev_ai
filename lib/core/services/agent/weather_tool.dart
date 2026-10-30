import '../../models/function_info.dart';
import '../../models/weather_report.dart';

import '../../utils/logger.dart';
import 'weather_service.dart';
import 'agent_tool.dart';

/// Fetches the weather for [location]: the JSON for the LLM and the report.
typedef WeatherFetch =
    Future<({String json, WeatherReport? report})> Function(
      String location,
      String apiKey,
    );

class WeatherTool extends AgentTool {
  /// [onOwnLocationReport] hears the report of every successful call for the
  /// user's own location (no `location`, empty, or `current`), never one for
  /// another city. [onReport] hears every successful call, any city (the
  /// tablet's weather card, M8 ruling 14). [fetch] is a test seam (default:
  /// [WeatherService]).
  WeatherTool({this.onOwnLocationReport, this.onReport, WeatherFetch? fetch})
    : _fetch = fetch ?? WeatherService.fetchCurrentWeather;

  final void Function(WeatherReport report)? onOwnLocationReport;
  final void Function(WeatherReport report)? onReport;
  final WeatherFetch _fetch;

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
    final String requested = (args['location'] as String? ?? '').trim();
    final bool ownLocation =
        requested.isEmpty || requested.toLowerCase() == 'current';
    final String location = ownLocation ? 'current' : requested;

    final String? apiKey = configValues['apiKey'] as String?;

    if (apiKey == null || apiKey.isEmpty) {
      return 'Error: OpenWeather API key not configured';
    }

    try {
      final ({String json, WeatherReport? report}) result = await _fetch(
        location,
        apiKey,
      );
      final WeatherReport? report = result.report;
      if (report != null) {
        _notify(onReport, report);
        if (ownLocation) {
          _notify(onOwnLocationReport, report);
        }
      }
      return result.json;
    } catch (e) {
      return 'Error getting weather: $e';
    }
  }

  /// Calls [listener]; a throwing listener never loses the answer.
  void _notify(
    void Function(WeatherReport report)? listener,
    WeatherReport report,
  ) {
    try {
      listener?.call(report);
    } catch (e) {
      AppLogger.warning(
        'WeatherTool: report listener failed ($e)',
        tag: 'WeatherTool',
      );
    }
  }
}
