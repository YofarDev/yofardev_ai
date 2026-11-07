import '../../models/function_info.dart';

import 'news_service.dart';
import 'agent_tool.dart';

/// Fetches the day's most shared articles as the string for the LLM.
typedef NewsFetch = Future<String> Function(String apiKey);

class NewsTool extends AgentTool {
  /// [fetch] is a test seam (default: [NewsService]).
  NewsTool({NewsFetch? fetch})
    : _fetch = fetch ?? NewsService.getMostPopularNewsOfTheDay;

  final NewsFetch _fetch;

  @override
  String get name => 'getMostPopularNewsOfTheDay';

  @override
  String get description =>
      'Returns an array of the most shared articles on NYTimes.com in the last 24 hours';

  @override
  List<Parameter> get parameters => <Parameter>[];

  @override
  Map<String, String> get requiredConfigKeys => <String, String>{
    'newYorkTimesKey': 'apiKey',
  };

  @override
  Future<String> execute(
    Map<String, dynamic> args,
    Map<String, dynamic> configValues,
  ) async {
    final String? apiKey = configValues['apiKey'] as String?;

    if (apiKey == null || apiKey.isEmpty) {
      return 'Error: New York Times API key not configured';
    }

    try {
      return await _fetch(apiKey);
    } catch (e) {
      return 'Error getting news: $e';
    }
  }
}
