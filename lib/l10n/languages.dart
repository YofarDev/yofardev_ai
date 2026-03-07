import 'package:flutter/material.dart';

abstract class Languages {
  static Languages of(BuildContext context) {
    return Localizations.of<Languages>(context, Languages)!;
  }

  ///   Global   ///
  String get appName;
  String get empty;
  String get settings;
  String get listChats;
  String get hiddenPart;
  String get describeThisImage;
  String get settingsSubstring;
  String get enableSoundEffects;
  String get loadDefaultSystemPrompt;
  String get ttsVoices;
  String get moreVoicesIOS;
  String get moreVoicesAndroid;
  String get username;
  String get userMessage;
  String get currentDate;
  String get currentAvatarConfig;
  String get currentUsername;
  String get resultsFunctionCalling;
  String get personaAssistant;

  ///   Task LLM Config   ///
  String get newChat;
  String get taskLlmConfig;
  String get assistantTask;
  String get titleTask;
  String get functionCallingTask;
  String get useDefaultLlm;
  String get taskLlmNote;
  String get taskLlmDescription;
  String get titleLlmDescription;
  String get functionCallingLlmDescription;

  /// Title Generation
  String get titleGenerationPrompt;
  String get titleGenerationSystemPrompt;

  ///   Function Calling Config   ///
  String get settings_functionCalling;
  String get settings_functionCalling_description;
  String get settings_functionCalling_saved;
  String get settings_googleSearch;
  String get settings_googleSearch_description;
  String get settings_apiKey;
  String get settings_engineId;
  String get settings_weather;
  String get settings_weather_description;
  String get settings_news;
  String get settings_news_description;
  String get settings_enable;
  String get settings_save;
}
