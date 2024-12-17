import 'package:flutter/foundation.dart';
import 'package:llm_api_picker/llm_api_picker.dart' as llm;
import 'package:llm_api_picker/llm_api_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/avatar.dart';
import '../models/chat.dart';
import '../models/chat_entry.dart';
import '../models/sound_effects.dart';
import '../services/settings_service.dart';
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

  Future<List<Map<String, dynamic>>> getFunctionsResults({
    required String lastUserMessage,
    List<FunctionInfo>? nextStepFunctions,
    String? previousResponse,
    List<Map<String, dynamic>>? previousResults,
  }) async {
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
    final List<Map<String, dynamic>> functionsResults =
        <Map<String, dynamic>>[];
    final List<FunctionInfo> next = <FunctionInfo>[];
    for (final FunctionInfo functionInfo in functionsCalled) {
      final Map<String, dynamic> result = <String, dynamic>{
        'name': functionInfo.name,
        'parameters': functionInfo.parameters,
        'result': await _callFunction(functionInfo, functionInfo.parameters),
      };
      functionsResults.add(result);
      if (functionInfo.isMultiStep) next.add(functionInfo);
    }
    if (next.isNotEmpty) {
      final List<Map<String, dynamic>> previousResults =
          <Map<String, dynamic>>[];
      for (final FunctionInfo functionInfo in next) {
        final int index = functionsResults.indexWhere(
          (Map<String, dynamic> result) => result['name'] == functionInfo.name,
        );
        if (index != -1) {
          previousResults.add(functionsResults[index]);
        }
      }
      final List<Map<String, dynamic>> nextResults = await getFunctionsResults(
        lastUserMessage: lastUserMessage,
        nextStepFunctions: next.map((FunctionInfo x) => x.nextStep!).toList(),
        previousResponse: items.$1,
        previousResults: previousResults,
      );
      functionsResults.removeWhere(
        (Map<String, dynamic> result) => next.any(
          (llm.FunctionInfo function) => function.name == result['name'],
        ),
      );
      functionsResults.addAll(nextResults);
    }
    return functionsResults;
  }

  static Future<String> _callFunction(
    FunctionInfo functionInfo,
    Map<String, dynamic>? parameters,
  ) async {
    final String functionName = functionInfo.name;

    switch (functionName) {
      case 'getCurrentWeather':
        final String location = parameters?['location'] as String? ?? 'current';
        return FunctionsHelper.getCurrentWeather(location);
      case 'getMostPopularNewsOfTheDay':
        return FunctionsHelper.getMostPopularNewsOfTheDay();
      case 'characterCounter':
        final String text = parameters?['text'] as String? ?? '';
        final String character = parameters?['character'] as String? ?? '';
        return FunctionsHelper.characterCounterFunction(text, character)
            .toString();
      case 'calculateExpression':
        final String expression = parameters?['expression'] as String? ?? '';
        return FunctionsHelper.calculatorFunction(expression)?.toString() ??
            'Invalid expression';
      case 'searchWikipedia':
        final String query = parameters?['query'] as String? ?? '';
        return FunctionsHelper.searchWikipediaFunction(query);
      case 'getWikipediaPage':
        final String title = parameters?['title'] as String? ?? '';
        return FunctionsHelper.getWikiPage(title);
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
    return systemPrompt.replaceAll(
      '\$soundEffectsList',
      soundEffectsList.toString(),
    );
  }
}
