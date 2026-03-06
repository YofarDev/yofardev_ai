import 'languages.dart';

class LanguageEn extends Languages {
  ///   Global   ///
  @override
  String get appName => "Yofardev AI";
  @override
  String get empty => "(empty)";
  @override
  String get settings => "Settings";
  @override
  String get listChats => "List of chats";
  @override
  String get hiddenPart =>
      "This part is not visible to the user, do not take it into account in your response.";
  @override
  String get describeThisImage => "Describe this image";
  @override
  String get settingsSubstring => "Start a new chat after any settings change";
  @override
  String get enableSoundEffects => "Enable sound effects";
  @override
  String get loadDefaultSystemPrompt => "Load the default system prompt";
  @override
  String get ttsVoices => "TTS Voices";
  @override
  String get moreVoicesIOS =>
      "For more voices, go to Settings > Accessibility > Spoken Content > Voices";
  @override
  String get moreVoicesAndroid =>
      "For more voices : ‘Google Text-to-Speech’ on the Play Store";
  @override
  String get username => "Your name";
  @override
  String get userMessage => "User’s message";
  @override
  String get currentDate => "Current date";
  @override
  String get currentAvatarConfig => "Current avatar configuration";
  @override
  String get currentUsername => "User’s name";
  @override
  String get resultsFunctionCalling => "Function calling results";
  @override
  String get personaAssistant => "Assistant’s persona";

  ///   Task LLM Config   ///
  @override
  String get newChat => "New chat";
  @override
  String get taskLlmConfig => "Task LLM Configuration";
  @override
  String get assistantTask => "Assistant";
  @override
  String get titleTask => "Title Generation";
  @override
  String get functionCallingTask => "Function Calling";
  @override
  String get useDefaultLlm => "Use default LLM";
  @override
  String get taskLlmNote =>
      "Note: If no LLM is selected for a task, the default assistant LLM will be used.";
  @override
  String get taskLlmDescription => "LLM used for main chat responses";
  @override
  String get titleLlmDescription => "LLM used to generate chat titles";
  @override
  String get functionCallingLlmDescription =>
      "LLM used for tool/function detection";

  @override
  String get titleGenerationPrompt =>
      "Generate a concise title (max 5 words) for this chat: ";

  @override
  String get titleGenerationSystemPrompt =>
      "You are a helpful assistant that generates short, descriptive chat titles. Return only the title, no quotes or extra text.";
}
