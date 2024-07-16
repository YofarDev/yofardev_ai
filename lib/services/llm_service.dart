import 'dart:io';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../l10n/localization_manager.dart';
import '../models/avatar.dart';
import '../models/chat.dart';
import '../models/chat_entry.dart';
import '../models/sound_effects.dart';
import '../utils/app_utils.dart';
import '../utils/extensions.dart';
import 'settings_service.dart';

class LlmService {
  late GenerativeModel _model;
  late ChatSession _chatSession;
  bool _isInitialized = false;

  Future<void> initialize(Chat initialChat) async {
    final String systemPrompt = await _getSystemPrompt(initialChat);
    systemPrompt.printCyanLog();
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: await SettingsService().getApiKey(),
      systemInstruction: Content.system(systemPrompt),
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
    Chat currentChatWithNewEntry, {
    bool onlyText = false,
    Avatar avatar = const Avatar(),
  }) async {
    if (!_isInitialized || currentChatWithNewEntry.entries.length < 2) {
      await initialize(currentChatWithNewEntry);
    }
    final List<Content> history =
        await _getChatHistory(currentChatWithNewEntry);
    final Content lastEntry = history.last;
    lastEntry.parts
        // ignore: avoid_function_literals_in_foreach_calls
        .forEach((Part part) => part.toJson().toString().printMagentaLog());
    try {
      final GenerateContentResponse response =
          await _chatSession.sendMessage(lastEntry);
      response.text?.printGreenLog();
      final String responseText = (response.text ?? "").removeEmojis().trim();
      final Map<String, dynamic> responseMap =
          AppUtils().splitStringAndAnnotations(responseText);
      return responseMap;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> _getSystemPrompt(Chat currentChat) async {
    final String base = currentChat.systemPrompt ?? localized.baseSystemPrompt;
    final StringBuffer soundEffectsList = StringBuffer();
    for (final SoundEffects soundEffect in SoundEffects.values) {
      soundEffectsList.write("[$soundEffect], ");
    }
    final String soundEffectsPrompt = localized.soundEffectsPrompt
        .replaceAll('\$soundEffectsList', soundEffectsList.toString());
    final StringBuffer backgroundList = StringBuffer();
    for (final AvatarBackgrounds bg in AvatarBackgrounds.values) {
      backgroundList.write("[$bg], ");
    }
    final String backgroundPrompt = localized.backgroundsPrompt
        .replaceAll('\$backgroundList', backgroundList.toString());
    final StringBuffer customizationList = StringBuffer();
    for (final AvatarTop top in AvatarTop.values) {
      customizationList.write("[$top], ");
    }
    customizationList.write("\n");
    for (final AvatarBottom bottom in AvatarBottom.values) {
      customizationList.write("[$bottom], ");
    }
    customizationList.write("\n");
    for (final AvatarGlasses glasses in AvatarGlasses.values) {
      customizationList.write("[$glasses], ");
    }
    customizationList.write("\n");
    for (final AvatarCostume costume in AvatarCostume.values) {
      customizationList.write("[$costume], ");
    }
    customizationList.write("\n");
    customizationList.write(localized.leavePrompt);
    for (final AvatarSpecials specials in AvatarSpecials.values) {
      customizationList.write("[$specials], ");
    }
    final String customizationPrompt = localized.customizationPrompt
        .replaceAll('\$customizationList', customizationList.toString());
    return "$base\n$soundEffectsPrompt\n$backgroundPrompt\n$customizationPrompt";
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
