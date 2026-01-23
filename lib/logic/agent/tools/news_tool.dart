import '../../../models/llm/function_info.dart';

import '../../../services/news_service.dart';
import '../agent_tool.dart';

class NewsTool extends AgentTool {
  @override
  String get name => 'getMostPopularNewsOfTheDay';

  @override
  String get description =>
      'Returns an array of the most shared articles on NYTimes.com in the last 24 hours';

  @override
  List<Parameter> get parameters => <Parameter>[];

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final String result = await NewsService.getMostPopularNewsOfTheDay();
    return result;
  }
}
