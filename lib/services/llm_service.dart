import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/bg_images.dart';
import '../models/chat.dart';
import '../models/chat_entry.dart';
import '../models/sound_effects.dart';
import '../utils/app_utils.dart';
import '../utils/extensions.dart';

class LlmService {
  late GenerativeModel _model;
  late ChatSession _chatSession;
  bool _isInitialized = false;

  Future<void> initialize(Chat initialChat) async {
    if (_isInitialized) return;
    await dotenv.load();
    final String apiKey = dotenv.env['GOOGLE_KEY'] ?? '';
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(_getSystemPrompt(initialChat)),
      safetySettings: <SafetySetting>[
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
      ],
    );
    final List<Content> history = await _getChatHistory(initialChat);
    _chatSession = _model.startChat(history: history);
    _isInitialized = true;
  }

  Future<Map<String, dynamic>> askYofardevAi(
      Chat currentChatWithNewEntry,) async {
    if (!_isInitialized) {
      await initialize(currentChatWithNewEntry);
    }
    final List<Content> history =
        await _getChatHistory(currentChatWithNewEntry);
    final Content lastEntry = history.last;
    final GenerateContentResponse response =
        await _chatSession.sendMessage(lastEntry);
    debugPrint(response.text);
    final String responseText = (response.text ?? "").removeEmojis().trim();
    final Map<String, dynamic> responseMap =
        AppUtils().splitStringAndAnnotations(responseText);
    return responseMap;
  }

  String _getSystemPrompt(Chat currentChat) {
    const String base =
        "Tu es Yofardev AI, l'avatar IA d'un développeur sarcastique. Tu es généralement positif, mais n'hésite pas à employer un ton légèrement moqueur. Tu privilégies les réponses courtes et précises, avec une touche d'humour pince-sans-rire. Visuellement, tu es représenté comme un beau jeune homme aux cheveux et aux yeux bruns dans un style d'anime. Tu portes un sweat à capuche rose et des lunettes noires, avec une expression neutre/sérieuse. Si une image ressemble à cette description, demande si c'est toi.";
    final StringBuffer soundEffectsList = StringBuffer();
    for (final SoundEffects soundEffect in SoundEffects.values) {
      soundEffectsList.write("[$soundEffect], ");
    }
    final String soundEffectsPrompt =
        "Voici une liste d'effets sonores que tu peux ajouter à la fin de ta réponse : $soundEffectsList. Limite l'utilisation à 1 effet sonore MAXIMUM par réponse, seulement quand c'est adapté au contexte. Ne le fais pas à chaque réponse.";
    final StringBuffer backgroundList = StringBuffer();
    for (final BgImages bg in BgImages.values) {
      backgroundList.write("[$bg], ");
    }
    final String backgroundPrompt =
        "Si l'utilisateur te demande (ou si c'est plus adapté au contexte), tu peux changer de fond d'écran. Voici la liste des choix disponibles : $backgroundList. Celui actuel est ${currentChat.bgImages}.";
    return "[${DateTime.now().toLongLocalDateString()}]\n$base\n$soundEffectsPrompt\n$backgroundPrompt";
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
