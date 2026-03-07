import '../../models/function_info.dart';

import 'google_search_service.dart';
import 'agent_tool.dart';

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
    // TODO: Pass API keys from settings in Task 13
    final List<Map<String, dynamic>> results =
        await GoogleSearchService.searchGoogle(
      query,
      '', // apiKey - will be passed from settings in Task 13
      '', // engineId - will be passed from settings in Task 13
    );
    return results.toString();
  }
}
