import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/bg_images.dart';
import '../models/chat.dart';
import '../models/chat_entry.dart';
import '../models/sound_effects.dart';
import '../utils/app_utils.dart';
import '../utils/extensions.dart';
import 'chat_history_service.dart';

class LlmService {
  Future<Map<String, dynamic>> askYofardevAi(
    String prompt,
    Chat currentChat,
  ) async {
    const String apiKey = 'AIzaSyDkC65Fjz3tLOqdPkzQy4VEbcZHCYJdWQ8';
    final GenerativeModel model = GenerativeModel(
      model: 'gemini-1.5-pro',
      apiKey: apiKey,
      systemInstruction: Content.system(_getSystemPrompt(currentChat)),
      safetySettings: <SafetySetting>[
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        //   SafetySetting(HarmCategory.unspecified, HarmBlockThreshold.none),
      ],
    );
    final ChatSession chatSession = model.startChat(
      history: <Content>[
        ..._getChatHistory(currentChat),
      ],
    );
    final Content content = Content.text(prompt);
    final GenerateContentResponse response =
        await chatSession.sendMessage(content);
    debugPrint(response.text);
    final String responseText = (response.text ?? "").removeEmojis().trim();
    await ChatHistoryService().updateChat(
      chatId: currentChat.id,
      userPrompt: prompt,
      modelResonse: responseText,
    );
    final Map<String, dynamic> responseMap =
        AppUtils().splitStringAndAnnotations(responseText);
    return responseMap;
  }

  String _getSystemPrompt(Chat currentChat) {
    final String base =
        "Tu es Yofardev AI, l'avatar IA d'un développeur sarcastique. Tu es généralement positif, mais n'hésite pas à pointer du doigt les bêtises avec humour.  Tu privilégies les réponses courtes et précises, avec une touche d'humour pince-sans-rire. L'utilisateur ne voit pas tes réponses sous forme de texte, mais les entends en audio grâce à un plugin TTS. Date du jour : ${DateTime.now()}";
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
    final String backgroundPrompt =
        "Tu peux également changer le fond d'écran dans lequel ton personnage se trouve à la demande de l'utilisateur (où dans de rares cas, de ton propre chef si tu penses que c'est adapté au contexte). Voici la liste des choix disponibles : $backgroundList. Actuellement c'est : ${currentChat.bgImages}.";
    return "$base\n$soundEffectsPrompt\n$backgroundPrompt";
  }

  List<Content> _getChatHistory(Chat chat) {
    final List<Content> contents = <Content>[];
    for (final ChatEntry entry in chat.entries) {
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
