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

  /// Message shown when demo mode is activated
  ///
  /// In en, this message translates to:
  /// **'Demo mode: {scriptName}'**
  String demoModeActivated(String scriptName);

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
