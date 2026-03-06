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
}
