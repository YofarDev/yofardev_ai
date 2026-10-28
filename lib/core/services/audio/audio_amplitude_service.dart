import 'dart:io';
import 'dart:typed_data';

import 'package:audio_analyzer/audio_analyzer.dart';

import '../../utils/logger.dart';
import 'wav_amplitude_extractor.dart';

/// Service for extracting audio amplitudes for avatar mouth animation
/// Extracted from ChatCubit to follow single responsibility principle
class AudioAmplitudeService {
  AudioAmplitudeService({
    AudioAnalyzer? analyzer,
    WavAmplitudeExtractor? extractor,
  }) : _analyzer = analyzer ?? AudioAnalyzer(),
       _extractor = extractor ?? const WavAmplitudeExtractor();

  final AudioAnalyzer _analyzer;
  final WavAmplitudeExtractor _extractor;

  /// 40 fps amplitudes, one value per 25 ms window.
  static const Duration frameDuration = Duration(milliseconds: 25);

  /// Extract amplitudes from audio file for smooth mouth animation
  ///
  /// Returns a list of amplitude values (0-100) representing audio intensity
  /// over time. WAV files are parsed in pure Dart (platform-independent 25 ms
  /// frames); anything else, or an unreadable WAV, falls back to the
  /// [AudioAnalyzer] plugin, then to the default amplitudes on error.
  Future<List<int>> extractAmplitudes(String audioPath) async {
    if (audioPath.toLowerCase().endsWith('.wav')) {
      try {
        final Uint8List wavBytes = await File(audioPath).readAsBytes();
        final List<int> amplitudes = _extractor.extract(wavBytes);
        AppLogger.debug(
          'Extracted ${amplitudes.length} amplitudes from WAV $audioPath',
          tag: 'AudioAmplitude',
        );
        return amplitudes;
      } catch (e) {
        AppLogger.error(
          'WAV extraction failed for $audioPath, falling back to analyzer',
          tag: 'AudioAmplitude',
          error: e,
        );
      }
    }
    try {
      final List<int> amplitudes = await _analyzer.getAmplitudes(audioPath);
      AppLogger.debug(
        'Extracted ${amplitudes.length} amplitudes for $audioPath',
        tag: 'AudioAmplitude',
      );
      return amplitudes;
    } catch (e) {
      AppLogger.error(
        'Failed to extract amplitudes from $audioPath',
        tag: 'AudioAmplitude',
        error: e,
      );
      // Return default amplitudes for smooth animation
      return List<int>.filled(50, 15);
    }
  }
}
