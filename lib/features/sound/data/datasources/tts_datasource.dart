import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supertonic_flutter/supertonic_flutter.dart';

import '../../../../core/models/voice_effect.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/platform_utils.dart';

class TtsDatasource {
  static SupertonicTTS? _supertonicTTS;
  static Timer? _cleanupTimer;

  /// Initialize SupertonicTTS engine
  static Future<void> initSupertonic() async {
    if (_supertonicTTS != null && _supertonicTTS!.isInitialized) {
      return;
    }

    // Periodic cleanup of stale TTS wav files, off the synthesis critical path.
    _cleanupTimer ??= Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(_cleanOldWavFiles()),
    );

    try {
      _supertonicTTS = SupertonicTTS();
      await _supertonicTTS!.initialize();
    } catch (e) {
      AppLogger.error(
        'Failed to initialize SupertonicTTS',
        tag: 'TtsService',
        error: e,
      );
      _supertonicTTS = null;
      rethrow;
    }
  }

  /// Dispose SupertonicTTS resources
  static void disposeSupertonic() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _supertonicTTS?.dispose();
    _supertonicTTS = null;
  }

  /// Deletes timestamp-named wav files older than 10 minutes.
  static Future<void> _cleanOldWavFiles() async {
    try {
      final TtsDatasource datasource = TtsDatasource();
      final Directory dir = Directory(await datasource.getMusicDirectoryPath());
      if (await dir.exists()) {
        final List<FileSystemEntity> files = await dir.list().toList();
        final int now = DateTime.now().millisecondsSinceEpoch;
        for (final FileSystemEntity file in files) {
          if (file is File && file.path.endsWith('.wav')) {
            final String name = file.path.split('/').last.split('.').first;
            final int? fileTimestamp = int.tryParse(name);
            // Delete if it's a timestamp file older than 10 minutes (600000 ms)
            if (fileTimestamp != null && (now - fileTimestamp) > 600000) {
              try {
                await file.delete();
              } catch (e) {
                AppLogger.debug(
                  'Failed to delete stale TTS file: $e',
                  tag: 'TtsDatasource',
                );
              }
            }
          }
        }
      }
    } catch (e) {
      AppLogger.error(
        'Failed to clean old wav files',
        tag: 'TtsService',
        error: e,
      );
    }
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
    // Ensure SupertonicTTS is initialized
    if (_supertonicTTS == null || !_supertonicTTS!.isInitialized) {
      await initSupertonic();
    }

    // If initialization succeeded, use it
    if (_supertonicTTS != null && _supertonicTTS!.isInitialized) {
      try {
        final String result = await _synthesizeWithSupertonic(
          text: text,
          language: language,
          voiceEffect: voiceEffect,
        );
        return result;
      } catch (e) {
        AppLogger.error(
          'SupertonicTTS synthesis failed',
          tag: 'TtsService',
          error: e,
        );
        rethrow;
      }
    }

    throw Exception(
      'SupertonicTTS is not available. Please initialize it first.',
    );
  }

  Future<String> _synthesizeWithSupertonic({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
  }) async {
    // Create config based on VoiceEffect
    const TTSConfig config = TTSConfig(speechSpeed: 1, denoisingSteps: 4);

    // Synthesize speech
    final TTSResult result = await _supertonicTTS!.synthesize(
      text,
      language: language,
      voiceStyle: 'M1',
      config: config,
    );

    // Save to file
    final String musicDirectoryPath = await getMusicDirectoryPath();

    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final String filename = '$timestamp.wav';
    final String filePath = '$musicDirectoryPath/$filename';

    final File file = File(filePath);
    await file.writeAsBytes(result.toWavBytes(), flush: true);

    // Single sanity check: writeAsBytes(flush: true) completing is the
    // durability guarantee.
    if (!await file.exists()) {
      AppLogger.error(
        'WAV file missing after flush write: $filePath',
        tag: 'TtsService',
      );
    }

    return filePath;
  }

  /// Check if SupertonicTTS is available
  static bool get isSupertonicAvailable =>
      _supertonicTTS != null && _supertonicTTS!.isInitialized;
}
