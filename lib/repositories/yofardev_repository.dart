import 'package:llm_api_picker/llm_api_picker.dart' as llm;

import '../models/avatar.dart';
import '../models/chat.dart';
import '../models/chat_entry.dart';
import '../models/sound_effects.dart';
import '../services/settings_service.dart';

class YofardevRepository {
  static Future<ChatEntry> askYofardevAi(Chat chat) async {
    final List<llm.ChatEntry> entries = <llm.ChatEntry>[];
    for (final ChatEntry entry in chat.entries) {
      entries.add(
        llm.ChatEntry(
          body: entry.body,
          isFromUser: entry.isFromUser,
          timestamp: entry.timestamp,
          attachedImage: entry.attachedImage,
        ),
      );
    }
    final String prompt = entries.last.body;
    entries.removeLast();
    String? answer = await llm.LLMRepository().promptCurrentModel(
      prompt: prompt,
      previousConversation: entries,
      systemPrompt: chat.systemPrompt,
    );
    if (answer != null) {
      answer = answer =
          answer.substring(answer.indexOf('{'), answer.indexOf('}') + 1);
      return ChatEntry(
        body: answer,
        isFromUser: false,
        timestamp: DateTime.now(),
      );
    } else {
      throw Exception('No answer');
    }
  }

  ///////////////////////////////// SYSTEM PROMPT /////////////////////////////////

  static Future<String> getSystemPrompt() async {
    String systemPrompt = await SettingsService().getBaseSystemPrompt();

    final StringBuffer backgroundList = StringBuffer();
    for (final AvatarBackgrounds bg in AvatarBackgrounds.values) {
      backgroundList.write("${bg.name}, ");
    }
    systemPrompt =
        systemPrompt.replaceAll('\$backgroundList', backgroundList.toString());

    final StringBuffer hatList = StringBuffer();
    for (final AvatarHat hat in AvatarHat.values) {
      hatList.write("${hat.name}, ");
    }
    systemPrompt = systemPrompt.replaceAll('\$hatList', hatList.toString());

    final StringBuffer topList = StringBuffer();
    for (final AvatarTop top in AvatarTop.values) {
      topList.write("${top.name}, ");
    }
    systemPrompt = systemPrompt.replaceAll('\$topList', topList.toString());

    final StringBuffer glassesList = StringBuffer();
    for (final AvatarGlasses glasses in AvatarGlasses.values) {
      glassesList.write("${glasses.name}, ");
    }
    systemPrompt =
        systemPrompt.replaceAll('\$glassesList', glassesList.toString());

    final StringBuffer specialsList = StringBuffer();
    for (final AvatarSpecials specials in AvatarSpecials.values) {
      specialsList.write("${specials.name}, ");
    }
    systemPrompt =
        systemPrompt.replaceAll('\$specialsList', specialsList.toString());

    final StringBuffer costumeList = StringBuffer();
    for (final AvatarCostume costume in AvatarCostume.values) {
      costumeList.write("${costume.name}, ");
    }
    systemPrompt =
        systemPrompt.replaceAll('\$costumeList', costumeList.toString());

    final StringBuffer soundEffectsList = StringBuffer();
    for (final SoundEffects soundEffect in SoundEffects.values) {
      soundEffectsList.write("${soundEffect.name}, ");
    }
    return systemPrompt.replaceAll(
      '\$soundEffectsList',
      soundEffectsList.toString(),
    );
  }
}
