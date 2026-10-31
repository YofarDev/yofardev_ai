import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get commonError;

  /// Button label to retry an action
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Button label to cancel an action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Button label to confirm an action
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// Button label to save data
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Button label to delete an item
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Button label to edit an item
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// Button label to close a dialog or screen
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Button label to go back
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Button label to go to the next step
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// Button label to complete an action
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// Button label to reset the counter
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @test.
  ///
  /// In en, this message translates to:
  /// **'test'**
  String get test;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Yofardev AI'**
  String get appName;

  /// No description provided for @assistantTask.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get assistantTask;

  /// No description provided for @currentAvatarConfig.
  ///
  /// In en, this message translates to:
  /// **'Current avatar configuration'**
  String get currentAvatarConfig;

  /// No description provided for @currentDate.
  ///
  /// In en, this message translates to:
  /// **'Current date'**
  String get currentDate;

  /// No description provided for @currentUsername.
  ///
  /// In en, this message translates to:
  /// **'User’s name'**
  String get currentUsername;

  /// No description provided for @describeThisImage.
  ///
  /// In en, this message translates to:
  /// **'Describe this image'**
  String get describeThisImage;

  /// No description provided for @empty.
  ///
  /// In en, this message translates to:
  /// **'(empty)'**
  String get empty;

  /// No description provided for @enableSoundEffects.
  ///
  /// In en, this message translates to:
  /// **'Enable sound effects'**
  String get enableSoundEffects;

  /// No description provided for @functionCallingLlmDescription.
  ///
  /// In en, this message translates to:
  /// **'LLM used for tool/function detection'**
  String get functionCallingLlmDescription;

  /// No description provided for @functionCallingTask.
  ///
  /// In en, this message translates to:
  /// **'Function Calling'**
  String get functionCallingTask;

  /// No description provided for @hiddenPart.
  ///
  /// In en, this message translates to:
  /// **'This part is not visible to the user, do not take it into account in your response.'**
  String get hiddenPart;

  /// No description provided for @listChats.
  ///
  /// In en, this message translates to:
  /// **'List of chats'**
  String get listChats;

  /// No description provided for @loadDefaultSystemPrompt.
  ///
  /// In en, this message translates to:
  /// **'Load the default system prompt'**
  String get loadDefaultSystemPrompt;

  /// Title of the global memory settings section
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get memory;

  /// Subtitle of the memory settings tile
  ///
  /// In en, this message translates to:
  /// **'Facts your avatar remembers about you across all chats'**
  String get memoryDescription;

  /// Explanation shown at the top of the memory page
  ///
  /// In en, this message translates to:
  /// **'Your avatar remembers facts about you across all chats. Review, delete, or clear them here.'**
  String get memoryPageSubtitle;

  /// Toggle label for the global memory feature
  ///
  /// In en, this message translates to:
  /// **'Enable global memory'**
  String get enableMemory;

  /// Placeholder shown when the memory list is empty
  ///
  /// In en, this message translates to:
  /// **'Nothing memorized yet. Chat with your avatar and it will remember facts about you.'**
  String get memoryEmpty;

  /// Button label to delete every memory item
  ///
  /// In en, this message translates to:
  /// **'Clear all memory'**
  String get clearMemory;

  /// Confirmation dialog body for clearing memory
  ///
  /// In en, this message translates to:
  /// **'Delete all memorized facts? This cannot be undone.'**
  String get clearMemoryConfirmation;

  /// Snackbar shown after deleting a memory item
  ///
  /// In en, this message translates to:
  /// **'Memory item deleted'**
  String get memoryDeleted;

  /// Task label for the LLM used by global memory extraction
  ///
  /// In en, this message translates to:
  /// **'Memory Extraction'**
  String get memoryTask;

  /// Description of the memory extraction task in the task LLM page
  ///
  /// In en, this message translates to:
  /// **'LLM used to extract facts for the global memory'**
  String get memoryLlmDescription;

  /// No description provided for @moreVoicesAndroid.
  ///
  /// In en, this message translates to:
  /// **'For more voices : ‘Google Text-to-Speech’ on the Play Store'**
  String get moreVoicesAndroid;

  /// No description provided for @moreVoicesIOS.
  ///
  /// In en, this message translates to:
  /// **'For more voices, go to Settings > Accessibility > Spoken Content > Voices'**
  String get moreVoicesIOS;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @personaAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant’s persona'**
  String get personaAssistant;

  /// No description provided for @personaNameAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get personaNameAssistant;

  /// No description provided for @personaNameNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get personaNameNormal;

  /// No description provided for @personaNameDoomer.
  ///
  /// In en, this message translates to:
  /// **'Doomer'**
  String get personaNameDoomer;

  /// No description provided for @personaNameConservative.
  ///
  /// In en, this message translates to:
  /// **'Conservative'**
  String get personaNameConservative;

  /// No description provided for @personaNamePhilosopher.
  ///
  /// In en, this message translates to:
  /// **'Philosopher'**
  String get personaNamePhilosopher;

  /// No description provided for @personaNameGeek.
  ///
  /// In en, this message translates to:
  /// **'Geek'**
  String get personaNameGeek;

  /// No description provided for @personaNameCoach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get personaNameCoach;

  /// No description provided for @personaNamePsychologist.
  ///
  /// In en, this message translates to:
  /// **'Psychologist'**
  String get personaNamePsychologist;

  /// No description provided for @personaDescriptionAssistant.
  ///
  /// In en, this message translates to:
  /// **'Helpful, clear, and balanced.'**
  String get personaDescriptionAssistant;

  /// No description provided for @personaDescriptionNormal.
  ///
  /// In en, this message translates to:
  /// **'Neutral tone for everyday conversation.'**
  String get personaDescriptionNormal;

  /// No description provided for @personaDescriptionDoomer.
  ///
  /// In en, this message translates to:
  /// **'Pessimistic and cynical takes.'**
  String get personaDescriptionDoomer;

  /// No description provided for @personaDescriptionConservative.
  ///
  /// In en, this message translates to:
  /// **'Traditional and cautious viewpoints.'**
  String get personaDescriptionConservative;

  /// No description provided for @personaDescriptionPhilosopher.
  ///
  /// In en, this message translates to:
  /// **'Reflective answers with deeper reasoning.'**
  String get personaDescriptionPhilosopher;

  /// No description provided for @personaDescriptionGeek.
  ///
  /// In en, this message translates to:
  /// **'Technical style with nerdy references.'**
  String get personaDescriptionGeek;

  /// No description provided for @personaDescriptionCoach.
  ///
  /// In en, this message translates to:
  /// **'Motivating, practical, action-focused guidance.'**
  String get personaDescriptionCoach;

  /// No description provided for @personaDescriptionPsychologist.
  ///
  /// In en, this message translates to:
  /// **'Empathetic and introspective support.'**
  String get personaDescriptionPsychologist;

  /// No description provided for @resultsFunctionCalling.
  ///
  /// In en, this message translates to:
  /// **'Function calling results'**
  String get resultsFunctionCalling;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsSubstring.
  ///
  /// In en, this message translates to:
  /// **'Start a new chat after any settings change'**
  String get settingsSubstring;

  /// No description provided for @settings_apiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get settings_apiKey;

  /// No description provided for @settings_enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get settings_enable;

  /// No description provided for @settings_engineId.
  ///
  /// In en, this message translates to:
  /// **'Search Engine ID'**
  String get settings_engineId;

  /// No description provided for @settings_functionCalling.
  ///
  /// In en, this message translates to:
  /// **'Function Calling'**
  String get settings_functionCalling;

  /// No description provided for @settings_functionCalling_description.
  ///
  /// In en, this message translates to:
  /// **'Configure API keys for function calling features'**
  String get settings_functionCalling_description;

  /// No description provided for @settings_functionCalling_saved.
  ///
  /// In en, this message translates to:
  /// **'Configuration saved'**
  String get settings_functionCalling_saved;

  /// No description provided for @settings_googleSearch.
  ///
  /// In en, this message translates to:
  /// **'Google Search'**
  String get settings_googleSearch;

  /// No description provided for @settings_googleSearch_description.
  ///
  /// In en, this message translates to:
  /// **'Search the web for current information'**
  String get settings_googleSearch_description;

  /// No description provided for @settings_news.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get settings_news;

  /// No description provided for @settings_news_description.
  ///
  /// In en, this message translates to:
  /// **'Get today\'s most popular news'**
  String get settings_news_description;

  /// No description provided for @settings_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settings_save;

  /// No description provided for @settings_weather.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get settings_weather;

  /// No description provided for @settings_weather_description.
  ///
  /// In en, this message translates to:
  /// **'Get current weather for any location'**
  String get settings_weather_description;

  /// No description provided for @taskLlmConfig.
  ///
  /// In en, this message translates to:
  /// **'Task LLM Configuration'**
  String get taskLlmConfig;

  /// No description provided for @taskLlmConfigDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure different LLMs for assistant, title generation, and function calling'**
  String get taskLlmConfigDescription;

  /// No description provided for @taskLlmDescription.
  ///
  /// In en, this message translates to:
  /// **'LLM used for main chat responses'**
  String get taskLlmDescription;

  /// No description provided for @taskLlmNote.
  ///
  /// In en, this message translates to:
  /// **'Note: If no LLM is selected for a task, the default assistant LLM will be used.'**
  String get taskLlmNote;

  /// No description provided for @titleGenerationPrompt.
  ///
  /// In en, this message translates to:
  /// **'Generate a concise title (max 5 words) for this chat: '**
  String get titleGenerationPrompt;

  /// No description provided for @titleGenerationSystemPrompt.
  ///
  /// In en, this message translates to:
  /// **'You are a helpful assistant that generates short, descriptive chat titles. Return only the title, no quotes or extra text.'**
  String get titleGenerationSystemPrompt;

  /// No description provided for @titleLlmDescription.
  ///
  /// In en, this message translates to:
  /// **'LLM used to generate chat titles'**
  String get titleLlmDescription;

  /// No description provided for @titleTask.
  ///
  /// In en, this message translates to:
  /// **'Title Generation'**
  String get titleTask;

  /// No description provided for @ttsVoices.
  ///
  /// In en, this message translates to:
  /// **'TTS Voices'**
  String get ttsVoices;

  /// No description provided for @useDefaultLlm.
  ///
  /// In en, this message translates to:
  /// **'Use default LLM'**
  String get useDefaultLlm;

  /// No description provided for @userMessage.
  ///
  /// In en, this message translates to:
  /// **'User’s message'**
  String get userMessage;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get username;

  /// Button label to open API configuration picker
  ///
  /// In en, this message translates to:
  /// **'API Picker'**
  String get apiPicker;

  /// Title for delete chat confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete chat?'**
  String get deleteChatTitle;

  /// Confirmation message for deleting a chat
  ///
  /// In en, this message translates to:
  /// **'This conversation will be permanently removed.'**
  String get deleteChatConfirmation;

  /// Time label for very recent messages
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// Time label for minutes ago
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String timeMinutesAgo(int count);

  /// Time label for hours ago
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String timeHoursAgo(int count);

  /// Time label for yesterday
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get timeYesterday;

  /// Time label for days ago
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String timeDaysAgo(int count);

  /// Snackbar shown when demo mode is activated
  ///
  /// In en, this message translates to:
  /// **'Demo mode activated'**
  String get demoModeActivated;

  /// Title for delete LLM config dialog
  ///
  /// In en, this message translates to:
  /// **'Delete Config'**
  String get deleteConfig;

  /// Confirmation message for deleting LLM config
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{configLabel}\"?'**
  String deleteConfigConfirmation(String configLabel);

  /// Page title for LLM provider selection
  ///
  /// In en, this message translates to:
  /// **'LLM Provider Selection'**
  String get llmProviderSelection;

  /// Message shown when no LLM configs exist
  ///
  /// In en, this message translates to:
  /// **'No LLM configurations found.'**
  String get noLlmConfigurations;

  /// Button label to add a new LLM provider
  ///
  /// In en, this message translates to:
  /// **'Add Provider'**
  String get addProvider;

  /// Message shown when user interrupts AI response
  ///
  /// In en, this message translates to:
  /// **'Response interrupted'**
  String get responseInterrupted;

  /// Success message after downloading conversation
  ///
  /// In en, this message translates to:
  /// **'Conversation downloaded: {fileName}'**
  String conversationDownloaded(String fileName);

  /// Error message when download fails
  ///
  /// In en, this message translates to:
  /// **'Failed to download: {error}'**
  String failedToDownload(String error);

  /// Button label for OK
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Error message for 404 page
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get pageNotFound;

  /// Error message with details
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorWithMessage(String message);

  /// Accessibility label for AI avatar
  ///
  /// In en, this message translates to:
  /// **'AI assistant avatar'**
  String get aiAssistantAvatar;

  /// Error message when LLM configs fail to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load available LLM configs'**
  String get failedToLoadLlmConfigs;

  /// Error message when no LLM config is selected
  ///
  /// In en, this message translates to:
  /// **'No LLM configuration selected'**
  String get noLlmConfigurationSelected;

  /// Title for adding a new LLM configuration
  ///
  /// In en, this message translates to:
  /// **'Add LLM Config'**
  String get llmConfigAdd;

  /// Title for editing an existing LLM configuration
  ///
  /// In en, this message translates to:
  /// **'Edit LLM Config'**
  String get llmConfigEdit;

  /// Label for LLM configuration name field
  ///
  /// In en, this message translates to:
  /// **'Label (e.g. My OpenAI)'**
  String get llmConfigLabel;

  /// Label for base URL field
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get llmConfigBaseUrl;

  /// Hint text for base URL field
  ///
  /// In en, this message translates to:
  /// **'https://api.openai.com/v1'**
  String get llmConfigBaseUrlHint;

  /// Label for API key field
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get llmConfigApiKey;

  /// Label for model name field
  ///
  /// In en, this message translates to:
  /// **'Model Name (e.g. gpt-4o)'**
  String get llmConfigModelName;

  /// Label for temperature slider
  ///
  /// In en, this message translates to:
  /// **'Temperature:'**
  String get llmConfigTemperature;

  /// Label for JSON response format dropdown
  ///
  /// In en, this message translates to:
  /// **'JSON Response Format'**
  String get llmConfigResponseFormat;

  /// Helper text for JSON response format
  ///
  /// In en, this message translates to:
  /// **'Format for JSON mode responses'**
  String get llmConfigResponseFormatHelper;

  /// JSON object format option for OpenAI
  ///
  /// In en, this message translates to:
  /// **'json_object (OpenAI)'**
  String get llmConfigResponseFormatJsonObject;

  /// JSON schema format option for some local APIs
  ///
  /// In en, this message translates to:
  /// **'json_schema (Some local APIs)'**
  String get llmConfigResponseFormatJsonSchema;

  /// Text format option
  ///
  /// In en, this message translates to:
  /// **'text (Generic)'**
  String get llmConfigResponseFormatText;

  /// No format option
  ///
  /// In en, this message translates to:
  /// **'none (No format, use prompt only)'**
  String get llmConfigResponseFormatNone;

  /// Validation error message for required fields
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get commonRequired;

  /// No description provided for @failureStorage.
  ///
  /// In en, this message translates to:
  /// **'Failed to save or load data'**
  String get failureStorage;

  /// No description provided for @failureNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get failureNetwork;

  /// No description provided for @failureTts.
  ///
  /// In en, this message translates to:
  /// **'Text-to-speech error'**
  String get failureTts;

  /// No description provided for @failureConfig.
  ///
  /// In en, this message translates to:
  /// **'Configuration error'**
  String get failureConfig;

  /// No description provided for @failureUnknown.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get failureUnknown;

  /// No description provided for @googleSearchApiTitle.
  ///
  /// In en, this message translates to:
  /// **'Google Search API'**
  String get googleSearchApiTitle;

  /// No description provided for @googleSearchApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your Google Search API key'**
  String get googleSearchApiKeyHint;

  /// No description provided for @searchEngineIdHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your Search Engine ID'**
  String get searchEngineIdHint;

  /// No description provided for @openWeatherApiTitle.
  ///
  /// In en, this message translates to:
  /// **'OpenWeather API'**
  String get openWeatherApiTitle;

  /// No description provided for @openWeatherApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your OpenWeather API key'**
  String get openWeatherApiKeyHint;

  /// No description provided for @nytApiTitle.
  ///
  /// In en, this message translates to:
  /// **'New York Times API'**
  String get nytApiTitle;

  /// No description provided for @nytApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your New York Times API key'**
  String get nytApiKeyHint;

  /// Number of messages shown on a chat card
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 message} other{{count} messages}}'**
  String chatMessageCount(int count);

  /// Title of the expandable function-call result tile
  ///
  /// In en, this message translates to:
  /// **'Result: {name}'**
  String functionResultTitle(String name);

  /// No description provided for @toolSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching the web…'**
  String get toolSearching;

  /// No description provided for @toolWeather.
  ///
  /// In en, this message translates to:
  /// **'Checking the weather…'**
  String get toolWeather;

  /// No description provided for @toolNews.
  ///
  /// In en, this message translates to:
  /// **'Reading the news…'**
  String get toolNews;

  /// No description provided for @toolMemory.
  ///
  /// In en, this message translates to:
  /// **'Searching my memory…'**
  String get toolMemory;

  /// No description provided for @toolWorking.
  ///
  /// In en, this message translates to:
  /// **'Working on it…'**
  String get toolWorking;

  /// No description provided for @askAnything.
  ///
  /// In en, this message translates to:
  /// **'Ask anything…'**
  String get askAnything;

  /// No description provided for @micPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Allow the microphone in settings to talk to me.'**
  String get micPermissionDenied;

  /// No description provided for @micUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice input isn\'t available here.'**
  String get micUnavailable;

  /// No description provided for @composerAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach an image'**
  String get composerAttach;

  /// No description provided for @composerTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get composerTools;

  /// No description provided for @composerSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get composerSend;

  /// No description provided for @composerStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get composerStop;

  /// No description provided for @composerListen.
  ///
  /// In en, this message translates to:
  /// **'Talk'**
  String get composerListen;

  /// No description provided for @composerMore.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get composerMore;

  /// No description provided for @stageHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get stageHistory;

  /// No description provided for @stageShowCaptions.
  ///
  /// In en, this message translates to:
  /// **'Show captions'**
  String get stageShowCaptions;

  /// No description provided for @stageHideCaptions.
  ///
  /// In en, this message translates to:
  /// **'Hide captions'**
  String get stageHideCaptions;

  /// No description provided for @stageDemo.
  ///
  /// In en, this message translates to:
  /// **'Play the demo'**
  String get stageDemo;

  /// No description provided for @languageNameEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNameEnglish;

  /// No description provided for @languageNameFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageNameFrench;

  /// No description provided for @stageMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get stageMenu;

  /// No description provided for @stageLanguageSwitch.
  ///
  /// In en, this message translates to:
  /// **'Language: {language}'**
  String stageLanguageSwitch(Object language);

  /// No description provided for @stageScenes.
  ///
  /// In en, this message translates to:
  /// **'Scenes'**
  String get stageScenes;

  /// No description provided for @scenePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a scene'**
  String get scenePickerTitle;

  /// No description provided for @sceneLivingRoom.
  ///
  /// In en, this message translates to:
  /// **'Living room'**
  String get sceneLivingRoom;

  /// No description provided for @sceneCampfire.
  ///
  /// In en, this message translates to:
  /// **'Campfire'**
  String get sceneCampfire;

  /// No description provided for @sceneBeach.
  ///
  /// In en, this message translates to:
  /// **'Beach'**
  String get sceneBeach;

  /// No description provided for @sceneDeepSpace.
  ///
  /// In en, this message translates to:
  /// **'Deep space'**
  String get sceneDeepSpace;

  /// No description provided for @sceneCafe.
  ///
  /// In en, this message translates to:
  /// **'Café'**
  String get sceneCafe;

  /// No description provided for @sceneRooftop.
  ///
  /// In en, this message translates to:
  /// **'Rooftop'**
  String get sceneRooftop;

  /// No description provided for @sceneMountainHut.
  ///
  /// In en, this message translates to:
  /// **'Mountain hut'**
  String get sceneMountainHut;

  /// No description provided for @sceneForestCabin.
  ///
  /// In en, this message translates to:
  /// **'Forest cabin'**
  String get sceneForestCabin;

  /// No description provided for @sceneTrainCompartment.
  ///
  /// In en, this message translates to:
  /// **'Train compartment'**
  String get sceneTrainCompartment;

  /// No description provided for @sceneLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get sceneLibrary;

  /// No description provided for @stageSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'{name} in the {scene} scene'**
  String stageSemanticsLabel(Object name, Object scene);

  /// No description provided for @stagePhaseIdle.
  ///
  /// In en, this message translates to:
  /// **'idle'**
  String get stagePhaseIdle;

  /// No description provided for @stagePhaseListening.
  ///
  /// In en, this message translates to:
  /// **'listening'**
  String get stagePhaseListening;

  /// No description provided for @stagePhaseThinking.
  ///
  /// In en, this message translates to:
  /// **'thinking'**
  String get stagePhaseThinking;

  /// No description provided for @stagePhaseSpeaking.
  ///
  /// In en, this message translates to:
  /// **'speaking'**
  String get stagePhaseSpeaking;

  /// No description provided for @scenePickerCurrentHint.
  ///
  /// In en, this message translates to:
  /// **'Current scene'**
  String get scenePickerCurrentHint;

  /// No description provided for @stagePropLamp.
  ///
  /// In en, this message translates to:
  /// **'Tap the lamp'**
  String get stagePropLamp;

  /// No description provided for @stagePropTv.
  ///
  /// In en, this message translates to:
  /// **'Tap the TV'**
  String get stagePropTv;

  /// No description provided for @stagePropCat.
  ///
  /// In en, this message translates to:
  /// **'Poke the cat'**
  String get stagePropCat;

  /// No description provided for @stagePropPlant.
  ///
  /// In en, this message translates to:
  /// **'Tap the plant'**
  String get stagePropPlant;

  /// No description provided for @stagePropFire.
  ///
  /// In en, this message translates to:
  /// **'Tap the fire'**
  String get stagePropFire;

  /// No description provided for @stagePropTent.
  ///
  /// In en, this message translates to:
  /// **'Tap the tent'**
  String get stagePropTent;

  /// No description provided for @stagePropOwl.
  ///
  /// In en, this message translates to:
  /// **'Poke the owl'**
  String get stagePropOwl;

  /// No description provided for @stagePropSky.
  ///
  /// In en, this message translates to:
  /// **'Look at the sky'**
  String get stagePropSky;

  /// No description provided for @stagePropCrab.
  ///
  /// In en, this message translates to:
  /// **'Poke the crab'**
  String get stagePropCrab;

  /// No description provided for @stagePropUmbrella.
  ///
  /// In en, this message translates to:
  /// **'Tap the umbrella'**
  String get stagePropUmbrella;

  /// No description provided for @stagePropSeagull.
  ///
  /// In en, this message translates to:
  /// **'Poke the seagull'**
  String get stagePropSeagull;

  /// No description provided for @stagePropPlanet.
  ///
  /// In en, this message translates to:
  /// **'Tap the planet'**
  String get stagePropPlanet;

  /// No description provided for @stagePropUfo.
  ///
  /// In en, this message translates to:
  /// **'Tap the UFO'**
  String get stagePropUfo;

  /// No description provided for @stagePropRubberDuck.
  ///
  /// In en, this message translates to:
  /// **'Squeeze the rubber duck'**
  String get stagePropRubberDuck;

  /// No description provided for @stagePropCup.
  ///
  /// In en, this message translates to:
  /// **'Tap the cup'**
  String get stagePropCup;

  /// No description provided for @stagePropEspresso.
  ///
  /// In en, this message translates to:
  /// **'Start the espresso machine'**
  String get stagePropEspresso;

  /// No description provided for @stagePropWindow.
  ///
  /// In en, this message translates to:
  /// **'Tap the window'**
  String get stagePropWindow;

  /// No description provided for @stagePropFish.
  ///
  /// In en, this message translates to:
  /// **'Tap the fish'**
  String get stagePropFish;

  /// No description provided for @stagePropTelescope.
  ///
  /// In en, this message translates to:
  /// **'Look through the telescope'**
  String get stagePropTelescope;

  /// No description provided for @stagePropAntenna.
  ///
  /// In en, this message translates to:
  /// **'Tap the antenna'**
  String get stagePropAntenna;

  /// No description provided for @stagePropPigeon.
  ///
  /// In en, this message translates to:
  /// **'Poke the pigeon'**
  String get stagePropPigeon;

  /// No description provided for @stagePropMoon.
  ///
  /// In en, this message translates to:
  /// **'Look at the moon'**
  String get stagePropMoon;

  /// No description provided for @stagePropStove.
  ///
  /// In en, this message translates to:
  /// **'Tap the stove'**
  String get stagePropStove;

  /// No description provided for @stagePropDog.
  ///
  /// In en, this message translates to:
  /// **'Pet the dog'**
  String get stagePropDog;

  /// No description provided for @stagePropBell.
  ///
  /// In en, this message translates to:
  /// **'Ring the bell'**
  String get stagePropBell;

  /// No description provided for @stagePropLantern.
  ///
  /// In en, this message translates to:
  /// **'Tap the lantern'**
  String get stagePropLantern;

  /// No description provided for @stagePropPinwheel.
  ///
  /// In en, this message translates to:
  /// **'Tap the pinwheel'**
  String get stagePropPinwheel;

  /// No description provided for @stagePropSquirrel.
  ///
  /// In en, this message translates to:
  /// **'Poke the squirrel'**
  String get stagePropSquirrel;

  /// No description provided for @stagePropWoodpile.
  ///
  /// In en, this message translates to:
  /// **'Tap the woodpile'**
  String get stagePropWoodpile;

  /// No description provided for @stagePropSuitcase.
  ///
  /// In en, this message translates to:
  /// **'Tap the suitcase'**
  String get stagePropSuitcase;

  /// No description provided for @stagePropLadybug.
  ///
  /// In en, this message translates to:
  /// **'Poke the ladybug'**
  String get stagePropLadybug;

  /// No description provided for @stagePropBook.
  ///
  /// In en, this message translates to:
  /// **'Open the book'**
  String get stagePropBook;

  /// No description provided for @stagePropGlobe.
  ///
  /// In en, this message translates to:
  /// **'Spin the globe'**
  String get stagePropGlobe;

  /// No description provided for @stagePropClock.
  ///
  /// In en, this message translates to:
  /// **'Tap the clock'**
  String get stagePropClock;

  /// No description provided for @stagePropMouse.
  ///
  /// In en, this message translates to:
  /// **'Poke the mouse'**
  String get stagePropMouse;

  /// No description provided for @stageDragCord.
  ///
  /// In en, this message translates to:
  /// **'Pull the lamp cord'**
  String get stageDragCord;

  /// No description provided for @stageDragPoke.
  ///
  /// In en, this message translates to:
  /// **'Stir the fire'**
  String get stageDragPoke;

  /// No description provided for @stageDragSand.
  ///
  /// In en, this message translates to:
  /// **'Draw in the sand'**
  String get stageDragSand;

  /// No description provided for @stageDragSpin.
  ///
  /// In en, this message translates to:
  /// **'Spin the planet'**
  String get stageDragSpin;

  /// No description provided for @stageDragWipe.
  ///
  /// In en, this message translates to:
  /// **'Wipe the misted window'**
  String get stageDragWipe;

  /// No description provided for @stageDragAim.
  ///
  /// In en, this message translates to:
  /// **'Swivel the telescope'**
  String get stageDragAim;

  /// No description provided for @stageDragRope.
  ///
  /// In en, this message translates to:
  /// **'Pull the bell rope'**
  String get stageDragRope;

  /// No description provided for @stageDragPinwheel.
  ///
  /// In en, this message translates to:
  /// **'Spin the pinwheel'**
  String get stageDragPinwheel;

  /// No description provided for @stageDragChain.
  ///
  /// In en, this message translates to:
  /// **'Pull the chain'**
  String get stageDragChain;

  /// No description provided for @stageDragLadder.
  ///
  /// In en, this message translates to:
  /// **'Slide the ladder'**
  String get stageDragLadder;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
