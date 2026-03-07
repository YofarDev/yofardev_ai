import '../../models/function_info.dart';
import '../../../features/settings/domain/repositories/settings_repository.dart';

import 'agent_tool.dart';

class CharacterCounterTool extends AgentTool {
  @override
  String get name => 'characterCounter';

  @override
  String get description =>
      'Returns the number of times a specific character appears in a string';

  @override
  List<Parameter> get parameters => <Parameter>[
    Parameter(
      name: 'text',
      description: 'The string to count characters in',
      type: 'string',
    ),
    Parameter(
      name: 'character',
      description: 'The character to count',
      type: 'string',
    ),
  ];

  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    required SettingsRepository settingsRepository,
  }) async {
    final String text = args['text'] as String? ?? '';
    final String character = args['character'] as String? ?? '';

    int count = 0;
    for (int i = 0; i < text.length; i++) {
      if (text[i].toLowerCase() == character.toLowerCase()) {
        count++;
      }
    }
    return count.toString();
  }
}
