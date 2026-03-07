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
  Map<String, String> get requiredConfigKeys => <String, String>{
    'googleSearchKey': 'apiKey',
    'googleSearchEngineId': 'engineId',
  };

  @override
  Future<String> execute(
    Map<String, dynamic> args,
    Map<String, dynamic> configValues,
  ) async {
    final String query = args['query'] as String? ?? '';

    final String? apiKey = configValues['apiKey'] as String?;
    final String? engineId = configValues['engineId'] as String?;

    if (apiKey == null || apiKey.isEmpty) {
      return 'Error: Google Search API key not configured';
    }

    if (engineId == null || engineId.isEmpty) {
      return 'Error: Google Search Engine ID not configured';
    }

    try {
      final List<Map<String, dynamic>> results =
          await GoogleSearchService.searchGoogle(query, apiKey, engineId);
      return results.toString();
    } catch (e) {
      return 'Error executing Google Search: $e';
    }
  }
}
