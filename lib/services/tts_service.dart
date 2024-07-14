import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

import 'settings_service.dart';

class TtsService {
  Future<String> getMusicDirectoryPath() async {
    if (Platform.isAndroid) {
      try {
        final List<Directory>? externalStorageDirectories =
            await getExternalStorageDirectories();
        if (externalStorageDirectories != null &&
            externalStorageDirectories.isNotEmpty) {
          final String path = externalStorageDirectories[0].path;
          final String musicPath =
              '${path.replaceAll(RegExp('/Android/data/.*'), '')}/Music';
          return musicPath;
        }
      } catch (e) {
        debugPrint("Error getting music directory: $e");
      }
    }

    // Fallback to the documents directory if not on Android or if there was an error
    final Directory documentsDir = await getApplicationDocumentsDirectory();
    return documentsDir.path;
  }

  Future<String> textToFrenchMaleVoice({
    required String text,
    required String language,
  }) async {
    final FlutterTts flutterTts = FlutterTts();
    final String locale = language == 'fr' ? 'fr-FR' : 'en-US';
     await flutterTts.setLanguage(locale);
        await flutterTts.setVoice(
          <String, String>{
            "name": await SettingsService().getTtsVoice(language),
            "locale": locale,
          },
        );
    if (Platform.isIOS) {
      await flutterTts.setSharedInstance(true);
      await flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        <IosTextToSpeechAudioCategoryOptions>[
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        ],
      );
    }
    final String musicDirectoryPath = await getMusicDirectoryPath();
    final String filename =
        "${DateTime.now().millisecondsSinceEpoch}${Platform.isAndroid ? '.wav' : '.caf'}";
    final String filePath = '$musicDirectoryPath/$filename';

    await flutterTts.awaitSynthCompletion(true);
    await flutterTts.synthesizeToFile(text, filename);

    return filePath;
  }
}
