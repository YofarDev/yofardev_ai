// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonError => 'An error occurred';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonClose => 'Close';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonDone => 'Done';

  @override
  String get reset => 'Reset';

  @override
  String get test => 'test';

  @override
  String get appName => 'Yofardev AI';

  @override
  String get assistantTask => 'Assistant';

  @override
  String get currentAvatarConfig => 'Current avatar configuration';

  @override
  String get currentDate => 'Current date';

  @override
  String get currentUsername => 'User’s name';

  @override
  String get describeThisImage => 'Describe this image';

  @override
  String get empty => '(empty)';

  @override
  String get enableSoundEffects => 'Enable sound effects';

  @override
  String get functionCallingLlmDescription =>
      'LLM used for tool/function detection';

  @override
  String get functionCallingTask => 'Function Calling';

  @override
  String get hiddenPart =>
      'This part is not visible to the user, do not take it into account in your response.';

  @override
  String get listChats => 'List of chats';

  @override
  String get loadDefaultSystemPrompt => 'Load the default system prompt';

  @override
  String get moreVoicesAndroid =>
      'For more voices : ‘Google Text-to-Speech’ on the Play Store';

  @override
  String get moreVoicesIOS =>
      'For more voices, go to Settings > Accessibility > Spoken Content > Voices';

  @override
  String get newChat => 'New chat';

  @override
  String get personaAssistant => 'Assistant’s persona';

  @override
  String get personaDescriptionAssistant => 'Helpful, clear, and balanced.';

  @override
  String get personaDescriptionNormal =>
      'Neutral tone for everyday conversation.';

  @override
  String get personaDescriptionDoomer => 'Pessimistic and cynical takes.';

  @override
  String get personaDescriptionConservative =>
      'Traditional and cautious viewpoints.';

  @override
  String get personaDescriptionPhilosopher =>
      'Reflective answers with deeper reasoning.';

  @override
  String get personaDescriptionGeek => 'Technical style with nerdy references.';

  @override
  String get personaDescriptionCoach =>
      'Motivating, practical, action-focused guidance.';

  @override
  String get personaDescriptionPsychologist =>
      'Empathetic and introspective support.';

  @override
  String get resultsFunctionCalling => 'Function calling results';

  @override
  String get settings => 'Settings';

  @override
  String get settingsSubstring => 'Start a new chat after any settings change';

  @override
  String get settings_apiKey => 'API Key';

  @override
  String get settings_enable => 'Enable';

  @override
  String get settings_engineId => 'Search Engine ID';

  @override
  String get settings_functionCalling => 'Function Calling';

  @override
  String get settings_functionCalling_description =>
      'Configure API keys for function calling features';

  @override
  String get settings_functionCalling_saved => 'Configuration saved';

  @override
  String get settings_googleSearch => 'Google Search';

  @override
  String get settings_googleSearch_description =>
      'Search the web for current information';

  @override
  String get settings_news => 'News';

  @override
  String get settings_news_description => 'Get today\'s most popular news';

  @override
  String get settings_save => 'Save';

  @override
  String get settings_weather => 'Weather';

  @override
  String get settings_weather_description =>
      'Get current weather for any location';

  @override
  String get taskLlmConfig => 'Task LLM Configuration';

  @override
  String get taskLlmDescription => 'LLM used for main chat responses';

  @override
  String get taskLlmNote =>
      'Note: If no LLM is selected for a task, the default assistant LLM will be used.';

  @override
  String get titleGenerationPrompt =>
      'Generate a concise title (max 5 words) for this chat: ';

  @override
  String get titleGenerationSystemPrompt =>
      'You are a helpful assistant that generates short, descriptive chat titles. Return only the title, no quotes or extra text.';

  @override
  String get titleLlmDescription => 'LLM used to generate chat titles';

  @override
  String get titleTask => 'Title Generation';

  @override
  String get ttsVoices => 'TTS Voices';

  @override
  String get useDefaultLlm => 'Use default LLM';

  @override
  String get userMessage => 'User’s message';

  @override
  String get username => 'Your name';

  @override
  String get apiPicker => 'API Picker';

  @override
  String get deleteChatTitle => 'Delete chat?';

  @override
  String get deleteChatConfirmation =>
      'This conversation will be permanently removed.';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String get timeYesterday => 'yesterday';

  @override
  String timeDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String demoModeActivated(String scriptName) {
    return 'Demo mode: $scriptName';
  }

  @override
  String get deleteConfig => 'Delete Config';

  @override
  String deleteConfigConfirmation(String configLabel) {
    return 'Are you sure you want to delete \"$configLabel\"?';
  }

  @override
  String get llmProviderSelection => 'LLM Provider Selection';

  @override
  String get noLlmConfigurations => 'No LLM configurations found.';

  @override
  String get addProvider => 'Add Provider';

  @override
  String get responseInterrupted => 'Response interrupted';

  @override
  String conversationDownloaded(String fileName) {
    return 'Conversation downloaded: $fileName';
  }

  @override
  String failedToDownload(String error) {
    return 'Failed to download: $error';
  }

  @override
  String get ok => 'OK';

  @override
  String get pageNotFound => 'Page not found';

  @override
  String errorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get aiAssistantAvatar => 'AI assistant avatar';

  @override
  String get failedToLoadLlmConfigs => 'Failed to load available LLM configs';

  @override
  String get noLlmConfigurationSelected => 'No LLM configuration selected';
}
