import 'package:flutter/services.dart';

import '../models/avatar_config.dart';
import '../models/chat.dart';
import '../models/sound_effects.dart';
import '../utils/app_utils.dart';
import 'settings_local_datasource.dart';

class PromptDatasource {
  final SettingsLocalDatasource _settingsDatasource;

  PromptDatasource({required SettingsLocalDatasource settingsDatasource})
    : _settingsDatasource = settingsDatasource;

  Future<String> getSystemPrompt() async {
    final String? language = await _settingsDatasource.getLanguage();
    final String languageCode = language ?? 'fr';
    String systemPrompt = await _settingsDatasource.getBaseSystemPrompt(
      languageCode,
    );

    // Replace lists
    systemPrompt = _replacePlaceholder(
      systemPrompt,
      r'$backgroundList',
      AvatarBackgrounds.values,
    );
    systemPrompt = _replacePlaceholder(
      systemPrompt,
      r'$hatList',
      AvatarHat.values,
    );
    systemPrompt = _replacePlaceholder(
      systemPrompt,
      r'$topList',
      AvatarTop.values,
    );
    systemPrompt = _replacePlaceholder(
      systemPrompt,
      r'$glassesList',
      AvatarGlasses.values,
    );
    systemPrompt = _replacePlaceholder(
      systemPrompt,
      r'$costumeList',
      AvatarCostume.values,
    );
    systemPrompt = _replacePlaceholder(
      systemPrompt,
      r'$soundEffectsList',
      SoundEffects.values,
    );

    // Replace user info
    final String? username = await _settingsDatasource.getUsername();
    systemPrompt = systemPrompt.replaceAll(
      r'$USERNAME',
      username != null ? "Username : $username\n" : '',
    );

    // Replace Persona
    final ChatPersona persona = await _settingsDatasource.getPersona();
    final String personaStr = await rootBundle.loadString(
      AppUtils.fixAssetsPath(
        'assets/txt/persona_${persona.name}_$languageCode.txt',
      ),
    );

    return systemPrompt.replaceAll(r'$PERSONA', personaStr);
  }

  String _replacePlaceholder(
    String text,
    String placeholder,
    List<Enum> values,
  ) {
    final StringBuffer buffer = StringBuffer();
    for (final Enum value in values) {
      buffer.write("${value.name}, ");
    }
    return text.replaceAll(placeholder, buffer.toString());
  }
}
