import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/platform_utils.dart';
import 'settings_service.dart';

class TtsService {
  Future<String> getMusicDirectoryPath() async {
    final String platform = PlatformUtils.checkPlatform();
    switch (platform) {
      case 'Android':
        try {
          final List<Directory>? externalStorageDirectories =
              await getExternalStorageDirectories();
          if (externalStorageDirectories != null &&
              externalStorageDirectories.isNotEmpty) {
            final String path = externalStorageDirectories[0].path;
            final String musicPath =
                '${path.replaceAll(RegExp('/Android/data/.*'), '')}/Music';
            return musicPath;
          } else {
            throw Exception("External storage not found");
          }
        } catch (e) {
          throw Exception("Error getting music directory: $e");
        }
      default:
        final Directory documentsDir = await getApplicationDocumentsDirectory();
        return documentsDir.path;
    }
  }

  Future<String> textToFrenchMaleVoice({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
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
    await flutterTts.setSpeechRate(voiceEffect.speedRate);
    await flutterTts.setPitch(voiceEffect.pitch);
    if (PlatformUtils.checkPlatform() == 'iOS') {
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
        "${DateTime.now().millisecondsSinceEpoch}${PlatformUtils.checkPlatform() == 'iOS' || PlatformUtils.checkPlatform() == 'MacOS' ? '.caf' : '.wav'}";
    final String filePath = '$musicDirectoryPath/$filename';
    await flutterTts.awaitSynthCompletion(true);
    await flutterTts.synthesizeToFile(text, filename);

    return filePath;
  }

  Future<FlutterTts> getFlutterTts({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
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
    await flutterTts.setSpeechRate(voiceEffect.speedRate);
    await flutterTts.setPitch(voiceEffect.pitch);
    return flutterTts;
  }
}

class VoiceEffect {
  final double pitch;
  final double speedRate;

  VoiceEffect({
    required this.pitch,
    required this.speedRate,
  });
}
