import 'package:flutter/services.dart';

import '../models/avatar_config.dart';
import '../models/avatar_gesture.dart';
import '../models/avatar_mood.dart';
import '../models/avatar_scene.dart';
import '../models/chat.dart';
import '../models/seasonal_wardrobe.dart';
import '../models/sound_effects.dart';
import '../utils/app_utils.dart';
import 'settings_local_datasource.dart';

class PromptDatasource {
  final SettingsLocalDatasource _settingsDatasource;
  final DateTime Function() _now;

  /// [now] is the local clock the seasonal note reads (tests inject it).
  PromptDatasource({
    required SettingsLocalDatasource settingsDatasource,
    DateTime Function()? now,
  }) : _settingsDatasource = settingsDatasource,
       _now = now ?? DateTime.now;

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
      AvatarScene.values,
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
      r'$tintList',
      AvatarTint.values,
    );
    systemPrompt = _replacePlaceholder(
      systemPrompt,
      r'$soundEffectsList',
      SoundEffects.values,
    );
    systemPrompt = _replacePlaceholder(
      systemPrompt,
      r'$moodList',
      AvatarMood.values,
    );
    systemPrompt = _replacePlaceholder(
      systemPrompt,
      r'$gestureList',
      AvatarGesture.llmCues,
    );
    systemPrompt = systemPrompt.replaceAll(
      r'$sceneEventList',
      _sceneEventList(),
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

    systemPrompt = systemPrompt.replaceAll(r'$PERSONA', personaStr);

    // In December the user sees the default outfit as the December one (M9
    // ruling 13): the LLM is told, so it can play along.
    final String seasonalNote = decemberWardrobePromptNote(_now());
    return seasonalNote.isEmpty
        ? systemPrompt
        : '$systemPrompt\n\n$seasonalNote';
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

  /// Scene events grouped by scene, since an event is only valid for the
  /// scene currently on screen.
  String _sceneEventList() {
    final StringBuffer buffer = StringBuffer();
    for (final AvatarScene scene in AvatarScene.values) {
      buffer.write('${scene.name}: ');
      for (final SceneEvent event in scene.allowedEvents) {
        buffer.write('${event.name}, ');
      }
      buffer.write('; ');
    }
    return buffer.toString();
  }
}
