import 'package:fpdart/src/either.dart';

import '../../models/function_info.dart';
import '../../../features/settings/domain/repositories/settings_repository.dart';

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
  Future<String> execute(
    Map<String, dynamic> args, {
    required SettingsRepository settingsRepository,
  }) async {
    final String query = args['query'] as String? ?? '';

    // Get API keys from settings
    final Either<Exception, String?> apiKeyResult = await settingsRepository.getGoogleSearchKey();
    final Either<Exception, String?> engineIdResult = await settingsRepository.getGoogleSearchEngineId();

    return apiKeyResult.fold(
      (Exception error) => 'Error: Google Search API key not configured',
      (String? apiKey) async {
        if (apiKey == null || apiKey.isEmpty) {
          return 'Error: Google Search API key not configured';
        }

        return engineIdResult.fold(
          (Exception error) => 'Error: Google Search Engine ID not configured',
          (String? engineId) async {
            if (engineId == null || engineId.isEmpty) {
              return 'Error: Google Search Engine ID not configured';
            }

            try {
              final List<Map<String, dynamic>> results =
                  await GoogleSearchService.searchGoogle(
                query,
                apiKey,
                engineId,
              );
              return results.toString();
            } catch (e) {
              return 'Error executing Google Search: $e';
            }
          },
        );
      },
    );
  }
}
