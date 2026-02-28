import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supertonic_flutter/supertonic_flutter.dart';

import '../utils/platform_utils.dart';

class TtsService {
  static SupertonicTTS? _supertonicTTS;

  /// Initialize SupertonicTTS engine
  static Future<void> initSupertonic() async {
    if (_supertonicTTS != null && _supertonicTTS!.isInitialized) {
      debugPrint('SupertonicTTS already initialized');
      return;
    }

    try {
      debugPrint('Initializing SupertonicTTS...');
      _supertonicTTS = SupertonicTTS();
      await _supertonicTTS!.initialize();
      debugPrint('✅ SupertonicTTS initialized successfully!');
    } catch (e) {
      debugPrint('❌ Failed to initialize SupertonicTTS: $e');
      _supertonicTTS = null;
      rethrow;
    }
  }

  /// Dispose SupertonicTTS resources
  static void disposeSupertonic() {
    _supertonicTTS?.dispose();
    _supertonicTTS = null;
  }

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
    final Stopwatch totalStopwatch = Stopwatch()..start();
    debugPrint(
      '⏱️  Starting TTS generation for: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."',
    );

    // Ensure SupertonicTTS is initialized
    if (_supertonicTTS == null || !_supertonicTTS!.isInitialized) {
      await initSupertonic();
    }

    // If initialization succeeded, use it
    if (_supertonicTTS != null && _supertonicTTS!.isInitialized) {
      try {
        debugPrint('🎵 Using SupertonicTTS for synthesis');
        final String result = await _synthesizeWithSupertonic(
          text: text,
          language: language,
          voiceEffect: voiceEffect,
        );
        totalStopwatch.stop();
        debugPrint(
          '🎉 Total TTS time: ${totalStopwatch.elapsedMilliseconds}ms (${totalStopwatch.elapsedMilliseconds / 1000}s)',
        );
        return result;
      } catch (e) {
        debugPrint('❌ SupertonicTTS failed: $e');
        rethrow;
      }
    }

    throw Exception('SupertonicTTS is not available. Please initialize it first.');
  }

  Future<String> _synthesizeWithSupertonic({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
  }) async {
    final Stopwatch synthesisStopwatch = Stopwatch()..start();

    // Create config based on VoiceEffect
    const TTSConfig config = TTSConfig(speechSpeed: 1);

    debugPrint('🎙️ Synthesizing with SupertonicTTS: "$text"');

    // Synthesize speech
    final TTSResult result = await _supertonicTTS!.synthesize(
      text,
      language: language,
      voiceStyle: 'M1',
      config: config,
    );

    synthesisStopwatch.stop();
    debugPrint(
      '✅ SupertonicTTS synthesis completed in ${synthesisStopwatch.elapsedMilliseconds}ms',
    );
    debugPrint(
      '   Audio: ${result.duration}s, ${result.sampleRate}Hz, ${result.audioData.length} samples',
    );

    // Save to file
    final Stopwatch fileStopwatch = Stopwatch()..start();
    final String musicDirectoryPath = await getMusicDirectoryPath();
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final String filename = '$timestamp.wav';
    final String filePath = '$musicDirectoryPath/$filename';

    debugPrint('💾 Saving WAV file to: $filePath');

    final File file = File(filePath);
    await file.writeAsBytes(result.toWavBytes());

    fileStopwatch.stop();
    debugPrint('✅ File saved in ${fileStopwatch.elapsedMilliseconds}ms');

    // Verify file exists and check size
    if (await file.exists()) {
      final int fileSize = await file.length();
      debugPrint('✅ WAV file created: $fileSize bytes');
    } else {
      debugPrint('❌ Failed to create WAV file!');
    }

    return filePath;
  }

  /// Check if SupertonicTTS is available
  static bool get isSupertonicAvailable =>
      _supertonicTTS != null && _supertonicTTS!.isInitialized;
}

class VoiceEffect {
  final double pitch;
  final double speedRate;

  VoiceEffect({required this.pitch, required this.speedRate});
}
