// ignore_for_file: join_return_with_assignment

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:llm_api_picker/llm_api_picker.dart' as llm;
import 'package:uuid/uuid.dart';

import '../l10n/localization_manager.dart';
import '../models/avatar.dart';
import '../models/chat.dart';
import '../models/chat_entry.dart';
import '../models/sound_effects.dart';
import '../services/settings_service.dart';
import '../utils/app_utils.dart';
import '../utils/functions_helper.dart';

class YofardevRepository {
  final llm.LLMRepository _repo = llm.LLMRepository();

  Future<ChatEntry> askYofardevAi(Chat chat) async {
    final llm.LlmApi? api = await llm.LLMRepository.getCurrentApi();
    if (api == null) {
      throw Exception('No API selected');
    }
    String? answer = await llm.LLMRepository.promptModel(
      messages: chat.llmMessages,
      systemPrompt: chat.systemPrompt,
      api: api,
      returnJson: true,
      debugLogs: true,
    );
    answer =
        answer = answer.substring(answer.indexOf('{'), answer.indexOf('}') + 1);
    return ChatEntry(
      id: const Uuid().v4(),
      body: answer,
      entryType: EntryType.yofardev,
      timestamp: DateTime.now(),
    );
  }

  ///////////////////////////////// FUNCTIONS CALL /////////////////////////////////

  Stream<Map<String, dynamic>> getFunctionsResultsStream({
    required Chat chat,
    required String lastUserMessage,
    List<Map<String, dynamic>>? previousResults,
  }) async* {
    final llm.LlmApi? api = await llm.LLMRepository.getCurrentApi();
    if (api == null) {
      throw Exception('No API selected');
    }
    // Query model first for function calling
    final (String, List<llm.FunctionInfo>) items =
        await _repo.checkFunctionsCalling(
      api: api,
      functions: FunctionsHelper.getFunctions,
      messages: chat.llmMessages,
      lastUserMessage: lastUserMessage,
    );
    final List<llm.FunctionInfo> functionsCalled = items.$2;
    for (final llm.FunctionInfo functionInfo in functionsCalled) {
      final Map<String, dynamic> result = <String, dynamic>{
        'name': functionInfo.name,
        'parameters': functionInfo.parametersCalled,
        'result':
            await _callFunction(functionInfo, functionInfo.parametersCalled),
      };
      debugPrint('Function results: $result');
      yield result;
    }
  }

  static Future<String> _callFunction(
    llm.FunctionInfo functionInfo,
    Map<String, dynamic>? parametersCalled,
  ) async {
    final String functionName = functionInfo.name;

    switch (functionName) {
      case 'getCurrentWeather':
        final String location = parametersCalled?['location'] as String? ?? 'current';
        return (functionInfo.function as Function(String))(location)
            as Future<String>;
      case 'characterCounter':
        final String text = parametersCalled?['text'] as String? ?? '';
        final String character = parametersCalled?['character'] as String? ?? '';
        final int response = await (functionInfo.function as Function(
          String,
          String,
        ))(text, character) as int;
        return response.toString();
      case 'calculateExpression':
        final String expression = parametersCalled?['expression'] as String? ?? '';
        final double? response = await (functionInfo.function as Function(
          String,
        ))(expression) as double?;
        return response?.toString() ?? 'Invalid expression';
      case 'setAlarm':
        final int minutesFromNow = parametersCalled?['minutesFromNow'] as int? ?? 0;
        final String message =
            parametersCalled?['message'] as String? ?? 'Hello world!';
        return (functionInfo.function as Function(int, String))(
          minutesFromNow,
          message,
        ) as Future<String>;
      case 'searchGoogle':
        final String query = parametersCalled?['query'] as String? ?? '';
        final List<Map<String, dynamic>> response =
            await (functionInfo.function as Function(String))(query)
                as List<Map<String, dynamic>>;
        return response.toString();
         case 'getTextContentFromWebsite':
        final String url = parametersCalled?['url'] as String? ?? '';
        final String response = await (functionInfo.function as Function(
          String,
        ))(url) as String;
        return response;
      default:
        debugPrint('Invalid function name: $functionName');
        return 'null';
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
    systemPrompt = systemPrompt.replaceAll(
      '\$soundEffectsList',
      soundEffectsList.toString(),
    );
    final String? username = await SettingsService().getUsername();

    systemPrompt = systemPrompt.replaceAll(
      '\$USERNAME',
      username != null ? "${localized.currentUsername} : $username\n" : '',
    );
    final ChatPersona persona = await SettingsService().getPersona();
    final String personaStr = await rootBundle.loadString(
      AppUtils.fixAssetsPath(
        'assets/txt/persona_${persona.name}_$languageCode.txt',
      ),
    );
    systemPrompt = systemPrompt.replaceAll(
      '\$PERSONA',
      personaStr,
    );
    return systemPrompt;
  }
}
