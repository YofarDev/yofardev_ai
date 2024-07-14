import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/localization_manager.dart';

class SettingsService {
  Future<void> setApiKey(String apiKey) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiKey', apiKey);
  }

  Future<String> getApiKey() async {
    // await dotenv.load();
    // final String? apiKey = dotenv.env['GOOGLE_KEY'] ;
    // if (apiKey != null) {
    //   return apiKey;
    // }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('apiKey') ?? '';
  }


  Future<void> setBaseSystemPrompt(String baseSystemPrompt) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseSystemPrompt', baseSystemPrompt);
  }

  Future<String?> getBaseSystemPrompt() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('baseSystemPrompt') ?? localized.baseSystemPrompt;
  }

  Future<void> setSoundEffects(bool soundEffects) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEffects', soundEffects);
  }

  Future<bool> getSoundEffects() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('soundEffects') ?? true;
  }
}
