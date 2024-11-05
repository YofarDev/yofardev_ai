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

}
