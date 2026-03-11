import 'package:audio_analyzer/audio_analyzer.dart';

import '../../utils/logger.dart';

/// Service for extracting audio amplitudes for avatar mouth animation
/// Extracted from ChatCubit to follow single responsibility principle
class AudioAmplitudeService {
  AudioAmplitudeService({AudioAnalyzer? analyzer}) : _analyzer = analyzer;

  AudioAnalyzer? _analyzer;

  /// Extract amplitudes from audio file for smooth mouth animation
  ///
  /// Returns a list of amplitude values (0-100) representing audio intensity
  /// over time. Falls back to default amplitudes on error.
  Future<List<int>> extractAmplitudes(String audioPath) async {
    try {
      _analyzer ??= AudioAnalyzer();
      final List<int> amplitudes = await _analyzer!.getAmplitudes(audioPath);
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
