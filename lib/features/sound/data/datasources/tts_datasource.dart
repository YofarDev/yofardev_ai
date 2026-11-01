import 'dart:async';
import 'dart:io';

import 'package:supertonic_flutter/supertonic_flutter.dart';

import '../../../../core/models/voice_effect.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/services/tts_synthesizer.dart';
import 'tts_scratch_files.dart';

/// Supertonic on-device TTS: the fallback voice while Kokoro's model is
/// downloading or unavailable, and for languages Kokoro does not speak.
class TtsDatasource implements TtsSynthesizer {
  static SupertonicTTS? _supertonicTTS;

  /// Initialize SupertonicTTS engine
  static Future<void> initSupertonic() async {
    if (_supertonicTTS != null && _supertonicTTS!.isInitialized) {
      return;
    }

    // Periodic cleanup of stale TTS wav files, off the synthesis critical path.
    TtsScratchFiles.ensureSweeping();

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
    TtsScratchFiles.stopSweeping();
    _supertonicTTS?.dispose();
    _supertonicTTS = null;
  }

  @override
  Future<void> delete(String path) => TtsScratchFiles.delete(path);

  @override
  Future<String> synthesize({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
  }) => textToFrenchMaleVoice(
    text: text,
    language: language,
    voiceEffect: voiceEffect,
  );

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
    final String filePath = await TtsScratchFiles.newWavPath();

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
