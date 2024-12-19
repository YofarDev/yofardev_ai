// ignore_for_file: join_return_with_assignment

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:llm_api_picker/llm_api_picker.dart' as llm;
import 'package:llm_api_picker/llm_api_picker.dart';
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

  static Future<ChatEntry> askYofardevAi(Chat chat) async {
    final llm.LlmApi? api = await llm.LLMRepository.getCurrentApi();
    if (api == null) {
      throw Exception('No API selected');
    }
    final List<llm.Message> messages = <llm.Message>[];
    for (final ChatEntry entry in chat.entries) {
      if (entry.entryType == EntryType.functionCalling) continue;
      messages.add(
        llm.Message(
          role: entry.entryType == EntryType.user
              ? llm.MessageRole.user
              : llm.MessageRole.assistant,
          body: entry.body,
          attachedImage: entry.attachedImage,
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
      id: const Uuid().v4(),
      body: answer,
      entryType: EntryType.yofardev,
      timestamp: DateTime.now(),
    );
  }

  ///////////////////////////////// FUNCTIONS CALL /////////////////////////////////

  Stream<Map<String, dynamic>> getFunctionsResultsStream({
    required String lastUserMessage,
    List<FunctionInfo>? nextStepFunctions,
    String? previousResponse,
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
      functions: nextStepFunctions ?? FunctionsHelper.getFunctions,
      lastUserMessage: lastUserMessage,
      previousResponse: previousResponse,
      previousResults: previousResults?.toString(),
    );
    final List<FunctionInfo> functionsCalled = items.$2;
    for (final FunctionInfo functionInfo in functionsCalled) {
      final Map<String, dynamic> result = <String, dynamic>{
        'name': functionInfo.name,
        'parameters': functionInfo.parameters,
        'result': await _callFunction(functionInfo, functionInfo.parameters),
        'intermediate': functionInfo.isMultiStep,
      };
      debugPrint('Function results: $result');
      yield result;
      if (functionInfo.isMultiStep) {
        yield* getFunctionsResultsStream(
          lastUserMessage: lastUserMessage,
          nextStepFunctions: <llm.FunctionInfo>[functionInfo.nextStep!],
          previousResponse: items.$1,
          previousResults: <Map<String, dynamic>>[result],
        );
      }
    }
  }

  

  static Future<String> _callFunction(
    FunctionInfo functionInfo,
    Map<String, dynamic>? parameters,
  ) async {
    final String functionName = functionInfo.name;

    switch (functionName) {
      case 'getCurrentWeather':
        final String location = parameters?['location'] as String? ?? 'current';
        return (functionInfo.function as Function(String))(location)
            as Future<String>;
      case 'getMostPopularNewsOfTheDay':
        return (functionInfo.function as Function())() as Future<String>;
      case 'characterCounter':
        final String text = parameters?['text'] as String? ?? '';
        final String character = parameters?['character'] as String? ?? '';
        final int response = await (functionInfo.function as Function(
          String,
          String,
        ))(text, character) as int;
        return response.toString();
      case 'calculateExpression':
        final String expression = parameters?['expression'] as String? ?? '';
        final double? response = await (functionInfo.function as Function(
          String,
        ))(expression) as double?;
        return response?.toString() ?? 'Invalid expression';
      case 'searchWikipedia':
        final String query = parameters?['query'] as String? ?? '';
        return (functionInfo.function as Function(String))(query)
            as Future<String>;
      case 'getWikipediaPage':
        final String title = parameters?['title'] as String? ?? '';
        return (functionInfo.function as Function(String))(title)
            as Future<String>;
      case 'setAlarm':
        final int minutesFromNow = parameters?['minutesFromNow'] as int? ?? 0;
        final String message =
            parameters?['message'] as String? ?? 'Hello world!';
        return (functionInfo.function as Function(int, String))(
          minutesFromNow,
          message,
        ) as Future<String>;
      case 'searchGoogle':
        final String query = parameters?['query'] as String? ?? '';
        final List<Map<String, dynamic>> response =
            await (functionInfo.function as Function(String))(query)
                as List<Map<String, dynamic>>;
        return response.toString();
      case 'getHtmlFromUrl':
        final String url = parameters?['url'] as String? ?? '';
        return (functionInfo.function as Function(String))(url)
            as Future<String>;
      case 'summarizeWebPage':
        final String html = parameters?['html'] as String? ?? '';
        final String originalPrompt =
            parameters?['originalPrompt'] as String? ?? '';
        return (functionInfo.function as Function(String, String))(
          html,
          originalPrompt,
        ) as Future<String>;
      case 'multiStepsFunction':
      case 'multiStepsFunction2':
      case 'multiStepsFunction3':
        final String password = parameters?['password'] as String? ?? '';
        return (functionInfo.function as Function(String))(password)
            as Future<String>;
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
