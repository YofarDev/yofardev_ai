import 'package:flutter/material.dart';

abstract class Languages {
static Languages of(BuildContext context) {
return Localizations.of<Languages>(context, Languages)!;

}
///   Global   ///
String get appName;
String get empty;
String get settings;
String get baseSystemPrompt;
String get soundEffectsPrompt;
String get backgroundsPrompt;
String get leavePrompt;
String get customizationPrompt;
String get listChats;
String get hiddenPart;
String get describeThisImage;

}
