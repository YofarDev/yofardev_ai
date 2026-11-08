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
  String get memory => 'Memory';

  @override
  String get memoryDescription =>
      'Facts your avatar remembers about you across all chats';

  @override
  String get memoryPageSubtitle =>
      'Your avatar remembers facts about you across all chats. Review, delete, or clear them here.';

  @override
  String get enableMemory => 'Enable global memory';

  @override
  String get memoryEmpty =>
      'Nothing memorized yet. Chat with your avatar and it will remember facts about you.';

  @override
  String get clearMemory => 'Clear all memory';

  @override
  String get clearMemoryConfirmation =>
      'Delete all memorized facts? This cannot be undone.';

  @override
  String get memoryDeleted => 'Memory item deleted';

  @override
  String get memoryTask => 'Memory Extraction';

  @override
  String get memoryLlmDescription =>
      'LLM used to extract facts for the global memory';

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
  String get personaNameAssistant => 'Assistant';

  @override
  String get personaNameNormal => 'Normal';

  @override
  String get personaNameDoomer => 'Doomer';

  @override
  String get personaNameConservative => 'Conservative';

  @override
  String get personaNamePhilosopher => 'Philosopher';

  @override
  String get personaNameGeek => 'Geek';

  @override
  String get personaNameCoach => 'Coach';

  @override
  String get personaNamePsychologist => 'Psychologist';

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
  String get taskLlmConfigDescription =>
      'Configure different LLMs for assistant, title generation, and function calling';

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
  String get demoModeActivated => 'Demo mode activated';

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

  @override
  String get llmConfigAdd => 'Add LLM Config';

  @override
  String get llmConfigEdit => 'Edit LLM Config';

  @override
  String get llmConfigLabel => 'Label (e.g. My OpenAI)';

  @override
  String get llmConfigBaseUrl => 'Base URL';

  @override
  String get llmConfigBaseUrlHint => 'https://api.openai.com/v1';

  @override
  String get llmConfigApiKey => 'API Key';

  @override
  String get llmConfigModelName => 'Model Name (e.g. gpt-4o)';

  @override
  String get llmConfigTemperature => 'Temperature:';

  @override
  String get llmConfigResponseFormat => 'JSON Response Format';

  @override
  String get llmConfigResponseFormatHelper => 'Format for JSON mode responses';

  @override
  String get llmConfigResponseFormatJsonObject => 'json_object (OpenAI)';

  @override
  String get llmConfigResponseFormatJsonSchema =>
      'json_schema (Some local APIs)';

  @override
  String get llmConfigResponseFormatText => 'text (Generic)';

  @override
  String get llmConfigResponseFormatNone => 'none (No format, use prompt only)';

  @override
  String get commonRequired => 'Required';

  @override
  String get failureStorage => 'Failed to save or load data';

  @override
  String get failureNetwork => 'Network error';

  @override
  String get failureTts => 'Text-to-speech error';

  @override
  String get failureConfig => 'Configuration error';

  @override
  String get failureUnknown => 'An unexpected error occurred';

  @override
  String get googleSearchApiTitle => 'Google Search API';

  @override
  String get googleSearchApiKeyHint => 'Enter your Google Search API key';

  @override
  String get searchEngineIdHint => 'Enter your Search Engine ID';

  @override
  String get openWeatherApiTitle => 'OpenWeather API';

  @override
  String get openWeatherApiKeyHint => 'Enter your OpenWeather API key';

  @override
  String get nytApiTitle => 'New York Times API';

  @override
  String get nytApiKeyHint => 'Enter your New York Times API key';

  @override
  String chatMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0';
  }

  @override
  String functionResultTitle(String name) {
    return 'Result: $name';
  }

  @override
  String get toolSearching => 'Searching the web…';

  @override
  String get toolWeather => 'Checking the weather…';

  @override
  String get toolNews => 'Reading the news…';

  @override
  String get toolMemory => 'Searching my memory…';

  @override
  String get toolWorking => 'Working on it…';

  @override
  String get askAnything => 'Ask anything…';

  @override
  String get micPermissionDenied =>
      'Allow the microphone in settings to talk to me.';

  @override
  String get micUnavailable => 'Voice input isn\'t available here.';

  @override
  String get composerAttach => 'Attach an image';

  @override
  String get composerTools => 'Tools';

  @override
  String get composerSend => 'Send';

  @override
  String get composerStop => 'Stop';

  @override
  String get composerListen => 'Talk';

  @override
  String get composerMore => 'More options';

  @override
  String get stageHistory => 'History';

  @override
  String get stageShowCaptions => 'Show captions';

  @override
  String get stageHideCaptions => 'Hide captions';

  @override
  String get stageDemo => 'Play the demo';

  @override
  String get languageNameEnglish => 'English';

  @override
  String get languageNameFrench => 'Français';

  @override
  String get stageMenu => 'Menu';

  @override
  String stageLanguageSwitch(Object language) {
    return 'Language: $language';
  }

  @override
  String get stageScenes => 'Scenes';

  @override
  String get scenePickerTitle => 'Choose a scene';

  @override
  String get sceneLivingRoom => 'Living room';

  @override
  String get sceneCampfire => 'Campfire';

  @override
  String get sceneBeach => 'Beach';

  @override
  String get sceneDeepSpace => 'Deep space';

  @override
  String get sceneCafe => 'Café';

  @override
  String get sceneRooftop => 'Rooftop';

  @override
  String get sceneMountainHut => 'Mountain hut';

  @override
  String get sceneForestCabin => 'Forest cabin';

  @override
  String get sceneTrainCompartment => 'Train compartment';

  @override
  String get sceneLibrary => 'Library';

  @override
  String stageSemanticsLabel(Object name, Object scene) {
    return '$name in the $scene scene';
  }

  @override
  String get stagePhaseIdle => 'idle';

  @override
  String get stagePhaseListening => 'listening';

  @override
  String get stagePhaseThinking => 'thinking';

  @override
  String get stagePhaseSpeaking => 'speaking';

  @override
  String get scenePickerCurrentHint => 'Current scene';

  @override
  String get stagePropLamp => 'Tap the lamp';

  @override
  String get stagePropTv => 'Tap the TV';

  @override
  String get stagePropCat => 'Poke the cat';

  @override
  String get stagePropPlant => 'Tap the plant';

  @override
  String get stagePropFire => 'Tap the fire';

  @override
  String get stagePropTent => 'Tap the tent';

  @override
  String get stagePropOwl => 'Poke the owl';

  @override
  String get stagePropSky => 'Look at the sky';

  @override
  String get stagePropCrab => 'Poke the crab';

  @override
  String get stagePropUmbrella => 'Tap the umbrella';

  @override
  String get stagePropSeagull => 'Poke the seagull';

  @override
  String get stagePropPlanet => 'Tap the planet';

  @override
  String get stagePropUfo => 'Tap the UFO';

  @override
  String get stagePropRubberDuck => 'Squeeze the rubber duck';

  @override
  String get stagePropCup => 'Tap the cup';

  @override
  String get stagePropEspresso => 'Start the espresso machine';

  @override
  String get stagePropWindow => 'Tap the window';

  @override
  String get stagePropFish => 'Tap the fish';

  @override
  String get stagePropTelescope => 'Look through the telescope';

  @override
  String get stagePropAntenna => 'Tap the antenna';

  @override
  String get stagePropPigeon => 'Poke the pigeon';

  @override
  String get stagePropMoon => 'Look at the moon';

  @override
  String get stagePropStove => 'Tap the stove';

  @override
  String get stagePropDog => 'Pet the dog';

  @override
  String get stagePropBell => 'Ring the bell';

  @override
  String get stagePropLantern => 'Tap the lantern';

  @override
  String get stagePropPinwheel => 'Tap the pinwheel';

  @override
  String get stagePropSquirrel => 'Poke the squirrel';

  @override
  String get stagePropWoodpile => 'Tap the woodpile';

  @override
  String get stagePropSuitcase => 'Tap the suitcase';

  @override
  String get stagePropLadybug => 'Poke the ladybug';

  @override
  String get stagePropBook => 'Open the book';

  @override
  String get stagePropGlobe => 'Spin the globe';

  @override
  String get stagePropClock => 'Tap the clock';

  @override
  String get stagePropMouse => 'Poke the mouse';

  @override
  String get stageDragCord => 'Pull the lamp cord';

  @override
  String get stageDragPoke => 'Stir the fire';

  @override
  String get stageDragSand => 'Draw in the sand';

  @override
  String get stageDragSpin => 'Spin the planet';

  @override
  String get stageDragWipe => 'Wipe the misted window';

  @override
  String get stageDragAim => 'Swivel the telescope';

  @override
  String get stageDragRope => 'Pull the bell rope';

  @override
  String get stageDragPinwheel => 'Spin the pinwheel';

  @override
  String get stageDragChain => 'Pull the chain';

  @override
  String get stageDragLadder => 'Slide the ladder';

  @override
  String get ttsVoiceTitle => 'Kokoro voice';

  @override
  String get ttsVoiceSource =>
      'One-time 132 MB download from GitHub (k2-fsa/sherpa-onnx). After that, everything stays on this device.';

  @override
  String get ttsVoiceNotInstalled => 'Not installed yet';

  @override
  String ttsVoiceDownloading(Object percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get ttsVoiceDownloadingStarted => 'Downloading…';

  @override
  String get ttsVoiceExtracting => 'Installing…';

  @override
  String get ttsVoiceLoading => 'Loading…';

  @override
  String get ttsVoiceReady => 'Ready, on this device';

  @override
  String get ttsVoiceFailed => 'Install failed';

  @override
  String get ttsVoiceRetry => 'Retry';

  @override
  String get ttsVoiceDownload => 'Download';

  @override
  String get ttsVoiceFallbackNote => 'Until then, the backup voice speaks.';

  @override
  String get ttsVoiceBannerTitle => 'Installing the new voice';

  @override
  String get ttsVoiceDismiss => 'Hide';

  @override
  String get llmSetupTitle => 'Connect an AI to start chatting';

  @override
  String get llmSetupBody =>
      'Add an API key (OpenAI-compatible or Gemini). It stays on this device.';

  @override
  String get llmSetupAction => 'Set up';

  @override
  String get llmSetupDismiss => 'Later';
}
