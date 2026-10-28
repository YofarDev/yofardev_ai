import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_analyzer/audio_analyzer.dart';

import '../../models/performance/speech_timeline.dart';
import '../../utils/logger.dart';
import 'speech_analyzer.dart';
import 'wav_amplitude_extractor.dart';
import 'wav_pcm.dart';

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

  /// Viseme spans and prosody marks of a TTS WAV file ([text] is the
  /// sentence, a hint for the classifier). The decode and analysis run off
  /// the UI isolate. Never throws: null (logged) for a non-WAV path or any
  /// error, so the caller falls back to the amplitude timeline.
  Future<SpeechTimeline?> analyzeSpeech(
    String audioPath, {
    String? text,
  }) async {
    if (!audioPath.toLowerCase().endsWith('.wav')) {
      return null;
    }
    try {
      final Uint8List wavBytes = await File(audioPath).readAsBytes();
      final SpeechTimeline timeline = await _analyzeInIsolate(wavBytes, text);
      AppLogger.debug(
        'Analysed ${timeline.visemes.length} viseme spans and '
        '${timeline.marks.length} prosody marks for $audioPath',
        tag: 'AudioAmplitude',
      );
      return timeline;
    } catch (e) {
      AppLogger.error(
        'Speech analysis failed for $audioPath',
        tag: 'AudioAmplitude',
        error: e,
      );
      return null;
    }
  }

  /// Static so the isolate closure captures only the bytes and the text
  /// (never this service and its platform plugin).
  static Future<SpeechTimeline> _analyzeInIsolate(
    Uint8List wavBytes,
    String? text,
  ) => Isolate.run<SpeechTimeline>(
    () => const SpeechAnalyzer().analyze(WavPcm.decode(wavBytes), text: text),
    debugName: 'speech_analyzer',
  );
}
