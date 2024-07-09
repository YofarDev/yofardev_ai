import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/bg_images.dart';
import '../models/chat_entry.dart';
import '../models/sound_effects.dart';
import '../utils/app_utils.dart';
import '../utils/extensions.dart';
import 'avatar_service.dart';
import 'chat_history_service.dart';

class LlmService {
  Future<Map<String, dynamic>> askYofardevAi(String prompt) async {
    const String apiKey = 'AIzaSyDkC65Fjz3tLOqdPkzQy4VEbcZHCYJdWQ8';
    final String currentChatId = await ChatHistoryService().getCurrentChatId();
    final GenerativeModel model = GenerativeModel(
      model: 'gemini-1.5-pro',
      apiKey: apiKey,
      systemInstruction: Content.system(await _getSystemPrompt()),
      safetySettings: <SafetySetting>[
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        //   SafetySetting(HarmCategory.unspecified, HarmBlockThreshold.none),
      ],
    );
    final ChatSession chat = model.startChat(
      history: <Content>[
        ...await _getChatHistory(currentChatId),
      ],
    );
    final Content content = Content.text(prompt);
    final GenerateContentResponse response = await chat.sendMessage(content);
    final String responseText = (response.text ?? "").removeEmojis().trim();
    await ChatHistoryService().saveChat(
      chatId: currentChatId,
      userPrompt: prompt,
      modelResonse: responseText,
    );
    final Map<String, dynamic> responseMap =
        AppUtils().splitStringAndAnnotations(responseText);
    return responseMap;
  }

  Future<String> _getSystemPrompt() async {
    const String base =
        "Tu es Yofardev AI, l'avatar IA d'un développeur sarcastique. Tu es généralement positif, mais n'hésite pas à pointer du doigt les bêtises avec humour.  Tu privilégies les réponses courtes et précises, avec une touche d'humour pince-sans-rire. L'utilisateur ne voit pas tes réponses sous forme de texte, mais les entends en audio grâce à un plugin TTS.";
    final StringBuffer soundEffectsList = StringBuffer();
    for (final SoundEffects soundEffect in SoundEffects.values) {
      soundEffectsList.write("[$soundEffect], ");
    }
    final String soundEffectsPrompt =
        "Voici une liste d'effets sonores que tu peux ajouter à la fin de ta réponse : $soundEffectsList\nLimite l'utilisation d'effets sonores à des situations où ils ajoutent réellement à la conversation, comme pour souligner une blague ou une remarque sarcastique. Essaye de ne pas en envoyer systématiquement (disons 1 message sur 3 en moyenne).";
    final StringBuffer backgroundList = StringBuffer();
    for (final BgImages bg in BgImages.values) {
      backgroundList.write("[$bg], ");
    }
    final BgImages currentBg = await AvatarService().getCurrentBg();
    final String backgroundPrompt =
        "Tu peux également choisir le fond d'écran dans laquelle ton personnage se trouve, ce qui modifiera visuellement ce que voit l'utilisateur. Voici la liste des choix disponibles : $backgroundList. Actuellement c'est : $currentBg.";
    return "$base\n$soundEffectsPrompt\n$backgroundPrompt";
  }

  Future<List<Content>> _getChatHistory(String currentChatId) async {
    final List<ChatEntry>? chat =
        await ChatHistoryService().getChat(currentChatId);
    if (chat == null) {
      return <Content>[];
    }
    final List<Content> contents = <Content>[];
    for (final ChatEntry entry in chat) {
      final String value = entry.text;
      Content c;
      if (entry.isFromUser) {
        c = Content.text(value);
      } else {
        c = Content.model(<Part>[TextPart(value)]);
      }
      contents.add(c);
    }
    return contents;
  }
}
