import '../../../models/llm/function_info.dart';

import '../../../services/google_search_service.dart';
import '../agent_tool.dart';

class GoogleSearchTool extends AgentTool {
  @override
  String get name => 'searchGoogle';

  @override
  String get description =>
      'Searches Google for a given query and returns the results';

  @override
  List<Parameter> get parameters => <Parameter>[
    Parameter(
      name: 'query',
      description: 'The query to search for',
      type: 'string',
    ),
  ];

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final String query = args['query'] as String? ?? '';
    final List<Map<String, dynamic>> results =
        await GoogleSearchService.searchGoogle(query);
    return results.toString();
  }
}
