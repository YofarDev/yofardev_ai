import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/bg_images.dart';
import '../models/chat.dart';
import '../models/chat_entry.dart';
import '../models/sound_effects.dart';
import '../utils/app_utils.dart';
import '../utils/extensions.dart';

class LlmService {
  Future<Map<String, dynamic>> askYofardevAi(
    Chat currentChatWithNewEntry,
  ) async {
    const String apiKey = 'AIzaSyDkC65Fjz3tLOqdPkzQy4VEbcZHCYJdWQ8';
    final GenerativeModel model = GenerativeModel(
      model: 'gemini-1.5-pro',
      apiKey: apiKey,
      systemInstruction:
          Content.system(_getSystemPrompt(currentChatWithNewEntry)),
      safetySettings: <SafetySetting>[
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        //   SafetySetting(HarmCategory.unspecified, HarmBlockThreshold.none),
      ],
    );
    final List<Content> history =
        await _getChatHistory(currentChatWithNewEntry);
    final Content lastEntry = history.last;
    history.removeLast();
    final ChatSession chatSession = model.startChat(
      history: <Content>[
        ...history,
      ],
    );
    final Content content = lastEntry;
    final GenerateContentResponse response =
        await chatSession.sendMessage(content);
    debugPrint(response.text);
    final String responseText = (response.text ?? "").removeEmojis().trim();
    final Map<String, dynamic> responseMap =
        AppUtils().splitStringAndAnnotations(responseText);
    return responseMap;
  }

  String _getSystemPrompt(Chat currentChat) {
    final String base =
        "Date du jour : ${DateTime.now().toLongLocalDateString()}.\nTu es Yofardev AI, l'avatar IA d'un développeur sarcastique. Tu es généralement positif, mais n'hésite pas à pointer du doigt les bêtises avec humour.  Tu privilégies les réponses courtes et précises, avec une touche d'humour pince-sans-rire. Visuellement, tu es représenté dans un style anime/cartoon. Tu as un sweat à capuche rose et des lunettes.";
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
        "Tu peux également changer le fond d'écran dans lequel ton personnage se trouve à la demande de l'utilisateur (ou de ton propre chef si tu penses que c'est adapté au contexte, mais pas systématiquement). Voici la liste des choix disponibles : $backgroundList. Actuellement c'est : ${currentChat.bgImages}.";
    return "$base\n$soundEffectsPrompt\n$backgroundPrompt";
  }

  Future<List<Content>> _getChatHistory(Chat chat) async {
    final List<Content> contents = <Content>[];
    for (final ChatEntry entry in chat.entries) {
      final String value = entry.text;
      Content c;
      if (entry.isFromUser) {
        if (entry.attachedImage.isNotEmpty && chat.entries.last == entry) {
          final Uint8List imageBytes =
              await File(entry.attachedImage).readAsBytes();
          c = Content.multi(<Part>[
            TextPart(entry.text),
            DataPart('image/jpeg', imageBytes),
          ]);
        } else {
          c = Content.text(value);
        }
      } else {
        c = Content.model(<Part>[TextPart(value)]);
      }
      contents.add(c);
    }
    return contents;
  }
}
