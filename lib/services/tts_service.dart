import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

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
    return '${documentsDir.path}/Music';
  }

  Future<String> textToFrenchMaleVoice(String text) async {
    final FlutterTts flutterTts = FlutterTts();
    await flutterTts.setLanguage("fr-FR");
    await flutterTts.setVoice(
      <String, String>{"name": "fr-fr-x-frd-local", "locale": "fr-FR"},
    );
    final String musicDirectoryPath = await getMusicDirectoryPath();
    final String filename = "${DateTime.now().millisecondsSinceEpoch}.wav";
    final String filePath = '$musicDirectoryPath/$filename';
    await flutterTts.awaitSynthCompletion(true);
    await flutterTts.synthesizeToFile(text, filename);
    return filePath;
  }
}
