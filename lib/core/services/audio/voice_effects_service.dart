import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../models/voice_effect.dart';
import '../../utils/logger.dart';
import 'voice_fx/voice_fx.dart';
import 'wav_pcm.dart';

/// Applies the costume's [VoiceEffect] to a synthesized TTS WAV with
/// [VoiceFx] (pure Dart, off the UI isolate).
class VoiceEffectsService {
  /// Ends the name of every processed copy.
  static const String _processedSuffix = '_fx.wav';

  /// The path of [inputPath] processed by [effect], written next to it as
  /// `<input path without .wav>_fx.wav` with the same sample count and rate.
  /// [inputPath] itself when there is nothing to apply ([VoiceEffect.none],
  /// web) or the processing failed (logged: the sentence plays dry).
  Future<String> applyVoiceEffects(String inputPath, VoiceEffect effect) async {
    if (effect == VoiceEffect.none || kIsWeb) {
      return inputPath;
    }
    try {
      final Uint8List dryBytes = await File(inputPath).readAsBytes();
      final Uint8List processed = await _processInIsolate(dryBytes, effect);
      final String outputPath = _outputPathOf(inputPath);
      await File(outputPath).writeAsBytes(processed, flush: true);
      return outputPath;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Voice effect ${effect.name} failed for $inputPath, playing it dry',
        tag: 'VoiceEffectsService',
        error: e,
        stackTrace: stackTrace,
      );
      return inputPath;
    }
  }

  /// The dry WAV the processed copy at [path] was written from
  /// (`<name>_fx.wav` → `<name>.wav`); null when [path] is no processed
  /// copy.
  static String? dryPathOf(String path) => path.endsWith(_processedSuffix)
      ? '${path.substring(0, path.length - _processedSuffix.length)}.wav'
      : null;

  static String _outputPathOf(String inputPath) {
    final String stem = inputPath.endsWith('.wav')
        ? inputPath.substring(0, inputPath.length - '.wav'.length)
        : inputPath;
    return '$stem$_processedSuffix';
  }

  /// Static so the isolate closure captures only the bytes and the effect.
  static Future<Uint8List> _processInIsolate(
    Uint8List wavBytes,
    VoiceEffect effect,
  ) => Isolate.run<Uint8List>(() {
    final WavPcm dry = WavPcm.decode(wavBytes);
    return WavPcm(
      sampleRate: dry.sampleRate,
      samples: VoiceFx.process(dry.samples, dry.sampleRate, effect),
    ).encodePcm16();
  }, debugName: 'voice_fx');
}
