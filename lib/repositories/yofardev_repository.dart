import 'package:llm_api_picker/llm_api_picker.dart' as llm;
import 'package:llm_api_picker/llm_api_picker.dart';

import '../models/avatar.dart';
import '../models/chat.dart';
import '../models/chat_entry.dart';
import '../models/sound_effects.dart';
import '../services/news_service.dart';
import '../services/settings_service.dart';
import '../services/weather_service.dart';

typedef WeatherFunction = Future<String> Function(String location);
typedef NewsFunction = Future<String> Function();

class YofardevRepository {
  static Future<ChatEntry> askYofardevAi(Chat chat) async {
    final llm.LlmApi? api = await llm.LLMRepository.getCurrentApi();
    if (api == null) {
      throw Exception('No API selected');
    }
    final List<llm.Message> messages = <llm.Message>[];
    for (final ChatEntry entry in chat.entries) {
      messages.add(
        llm.Message(
          role: entry.isFromUser
              ? llm.MessageRole.user
              : llm.MessageRole.assistant,
          body: entry.body,
          attachedImage:
              entry.attachedImage.isNotEmpty ? entry.attachedImage : null,
        ),
      );
    }
    String? answer = await llm.LLMRepository.promptModel(
      messages: messages,
      systemPrompt: chat.systemPrompt,
      api: api,
      returnJson: true,
    );
    answer =
        answer = answer.substring(answer.indexOf('{'), answer.indexOf('}') + 1);
    return ChatEntry(
      body: answer,
      isFromUser: false,
      timestamp: DateTime.now(),
    );
  }

  static Future<List<Map<String, dynamic>>> getFunctionsResults({
    required String lastUserMessage,
  }) async {
    final llm.LlmApi? api = await llm.LLMRepository.getCurrentApi();
    if (api == null) {
      throw Exception('No API selected');
    }
    // Query model first for function calling
    final List<FunctionInfo> functionsCalled =
        await llm.LLMRepository.checkFunctionsCalling(
      api: api,
      functions: _functions,
      lastUserMessage: lastUserMessage,
    );
    final List<Map<String, dynamic>> functionsResults =
        <Map<String, dynamic>>[];
    for (final FunctionInfo functionInfo in functionsCalled) {
      final Map<String, dynamic> result = <String, dynamic>{
        'name': functionInfo.name,
        'parameters': functionInfo.parameters,
        'result':
            await _callFunction(functionInfo.name, functionInfo.parameters),
      };
      functionsResults.add(result);
    }
    return functionsResults;
  }

  ///////////////////////////////// FUNCTIONS CALL /////////////////////////////////

  static final List<FunctionInfo> _functions = <FunctionInfo>[
    FunctionInfo(
      name: 'getCurrentWeather',
      description: 'Returns the current weather',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'location': <String, dynamic>{
            'type': 'string',
            'description': 'The location to get the weather for',
          },
        },
      },
      function: (String location) async =>
          await WeatherService.getCurrentWeather(location),
    ),
    FunctionInfo(
      name: 'getMostPopularNewsOfTheDay',
      description:
          'Returns an array of the most shared articles on NYTimes.com in the last 24 hours',
      parameters: <String, dynamic>{},
      function: (String location) async =>
          await NewsService.getMostPopularNewsOfTheDay(),
    ),
  ];

  static Future<String> _callFunction(
    String functionName,
    Map<String, dynamic>? parameters,
  ) async {
    final FunctionInfo functionInfo = _functions.firstWhere(
      (FunctionInfo e) => e.name == functionName,
      orElse: () => throw ArgumentError('Function not found: $functionName'),
    );
    final Function function = functionInfo.function;
    if (function is WeatherFunction) {
      final String location =
          parameters?['location'] as String? ?? 'Default Location';
      return function(location);
    } else if (function is NewsFunction) {
      return function();
    } else {
      throw ArgumentError('Invalid function type for: $functionName');
    }
  }

  ///////////////////////////////// SYSTEM PROMPT /////////////////////////////////

  static Future<String> getSystemPrompt() async {
    String systemPrompt = await SettingsService().getBaseSystemPrompt();

    final StringBuffer backgroundList = StringBuffer();
    for (final AvatarBackgrounds bg in AvatarBackgrounds.values) {
      backgroundList.write("${bg.name}, ");
    }
    systemPrompt =
        systemPrompt.replaceAll('\$backgroundList', backgroundList.toString());

    final StringBuffer hatList = StringBuffer();
    for (final AvatarHat hat in AvatarHat.values) {
      hatList.write("${hat.name}, ");
    }
    systemPrompt = systemPrompt.replaceAll('\$hatList', hatList.toString());

    final StringBuffer topList = StringBuffer();
    for (final AvatarTop top in AvatarTop.values) {
      topList.write("${top.name}, ");
    }
    systemPrompt = systemPrompt.replaceAll('\$topList', topList.toString());

    final StringBuffer glassesList = StringBuffer();
    for (final AvatarGlasses glasses in AvatarGlasses.values) {
      glassesList.write("${glasses.name}, ");
    }
    systemPrompt =
        systemPrompt.replaceAll('\$glassesList', glassesList.toString());

    final StringBuffer specialsList = StringBuffer();
    for (final AvatarSpecials specials in AvatarSpecials.values) {
      specialsList.write("${specials.name}, ");
    }
    systemPrompt =
        systemPrompt.replaceAll('\$specialsList', specialsList.toString());

    final StringBuffer costumeList = StringBuffer();
    for (final AvatarCostume costume in AvatarCostume.values) {
      costumeList.write("${costume.name}, ");
    }
    systemPrompt =
        systemPrompt.replaceAll('\$costumeList', costumeList.toString());

    final StringBuffer soundEffectsList = StringBuffer();
    for (final SoundEffects soundEffect in SoundEffects.values) {
      soundEffectsList.write("${soundEffect.name}, ");
    }
    return systemPrompt.replaceAll(
      '\$soundEffectsList',
      soundEffectsList.toString(),
    );
  }
}
