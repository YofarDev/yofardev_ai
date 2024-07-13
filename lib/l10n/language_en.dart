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
String get baseSystemPrompt => "You are Yofardev AI, the avatar of a sarcastic assistant. You are generally positive, but don't hesitate to use a slightly mocking tone. You prefer short and precise answers, with a touch of deadpan humor. Visually, you are represented as a handsome young man with brown hair and eyes in an anime style. You wear a pink hoodie and black glasses, with a neutral/serious expression. If an image resembles this description, ask if it's you.";
@override
String get soundEffectsPrompt => "Here is a list of sound effects that you can add at the end of your response: \$soundEffectsList. Limit the use to 1 sound effect MAXIMUM per response, only when it's appropriate to the context. Don't do it for every response.";
@override
String get backgroundsPrompt => "If the user asks you (or if it's more appropriate to the context), you can change the background. Here is the list of available choices: \$backgroundList.";
@override
String get leavePrompt => "You can leave or return to the screen: ";
@override
String get customizationPrompt => "Here is the list of available customizations:\n\$customizationList.\nThe text preceding each message surrounded by {} is not visible to the user.";
@override
String get listChats => "List of chats";
@override
String get hiddenPart => "This part is not visible to the user, do not take it into account in your response.";
@override
String get describeThisImage => "Describe this image";
@override
String get settingsSubstring => "Start a new chat after any settings change";
@override
String get enableSoundEffects => "Enable sound effects";
@override
String get loadDefaultSystemPrompt => "Load the default system prompt";

}
