import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/localization_manager.dart';
import '../models/chat.dart';
import '../res/app_constants.dart';
import '../utils/app_utils.dart';
import '../utils/platform_utils.dart';

class SettingsService {
  Future<void> setPersona(ChatPersona persona) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('persona', persona.name);
  }

  Future<ChatPersona> getPersona() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? persona = prefs.getString('persona');
    return persona != null
        ? ChatPersona.values.byName(persona)
        : ChatPersona.normal;
  }

  Future<void> setUsername(String username) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
  }

  Future<String?> getUsername() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  Future<void> setLanguage(String language) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
  }

  Future<String?> getLanguage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('language');
  }

  Future<void> setBaseSystemPrompt(String baseSystemPrompt) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseSystemPrompt', baseSystemPrompt);
  }

  Future<String> getBaseSystemPrompt() async {
    final String baseSystemPrompt = await rootBundle.loadString(
      AppUtils.fixAssetsPath('assets/txt/system_prompt_$languageCode.txt'),
    );
    return baseSystemPrompt;
  }

  Future<void> setSoundEffects(bool soundEffects) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEffects', soundEffects);
  }

  Future<bool> getSoundEffects() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('soundEffects') ?? true;
  }

  Future<void> setTtsVoice(String name, String language) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('ttsVoice_$language', name);
  }

  Future<String> getTtsVoice(String language) async {
    // final SharedPreferences prefs = await SharedPreferences.getInstance();
    // final String? voiceName = prefs.getString('ttsVoice_$language');
    final String platform = PlatformUtils.checkPlatform();
    switch (platform) {
      case 'Android':
        if (language == 'fr') {
          return AppConstants.frenchAndroidVoice;
        } else {
          return AppConstants.englishAndroidVoice;
        }
      case 'iOS':
        if (language == 'fr') {
          return AppConstants.frenchIOSVoice;
        } else {
          return AppConstants.englishIOSVoice;
        }
      case 'Web':
        if (language == 'fr') {
          return 'Thomas (French (France))';
        } else {
          return 'Google UK English Male';
        }
      case 'MacOS':
        if (language == 'fr') {
          return 'Nicolas (Enhanced)';
        } else {
          return 'Lee (Premium)';
        }
      default:
        throw Exception('Unsupported platform');
    }
  }
}
