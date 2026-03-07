import '../../models/function_info.dart';

import 'news_service.dart';
import 'agent_tool.dart';

class NewsTool extends AgentTool {
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
      return await NewsService.getMostPopularNewsOfTheDay(
        apiKey,
      );
    } catch (e) {
      return 'Error getting news: $e';
    }
  }
}
