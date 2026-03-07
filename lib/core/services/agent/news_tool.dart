import 'package:fpdart/src/either.dart';

import '../../models/function_info.dart';
import '../../../features/settings/domain/repositories/settings_repository.dart';

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
  Future<String> execute(
    Map<String, dynamic> args, {
    required SettingsRepository settingsRepository,
  }) async {
    // Get API key from settings
    final Either<Exception, String?> apiKeyResult = await settingsRepository.getNewYorkTimesKey();

    return apiKeyResult.fold(
      (Exception error) => 'Error: New York Times API key not configured',
      (String? apiKey) async {
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
      },
    );
  }
}
