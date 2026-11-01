import 'dart:ffi';
import 'dart:isolate';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../../../core/utils/logger.dart';

import 'kokoro_engine.dart';
import 'kokoro_model_paths.dart';
import 'peak_normalizer.dart';

/// The engine on platforms with FFI (picked by `kokoro_engine_factory.dart`).
KokoroEngine createPlatformKokoroEngine() => SherpaKokoroEngine();

/// [KokoroEngine] on sherpa-onnx. The native handle is created once and kept
/// for the process lifetime; each synthesis runs in [Isolate.run] on that
/// shared handle (bindings are per isolate, the handle is process-wide).
class SherpaKokoroEngine implements KokoroEngine {
  int? _handleAddress;
  sherpa.OfflineTtsConfig? _config;

  @override
  bool get isLoaded => _handleAddress != null;

  @override
  Future<void> load(KokoroModelPaths paths) async {
    if (isLoaded) return;
    final sherpa.OfflineTtsConfig config = sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(
        kokoro: sherpa.OfflineTtsKokoroModelConfig(
          model: paths.model,
          voices: paths.voices,
          tokens: paths.tokens,
          dataDir: paths.dataDir,
          dictDir: paths.dictDir,
          lexicon: paths.lexicon,
        ),
        numThreads: 2,
        debug: false,
      ),
    );
    _handleAddress = await Isolate.run<int>(() {
      sherpa.initBindings();
      return sherpa.OfflineTts(config).ptr.address;
    });
    _config = config;
  }

  @override
  Future<void> synthesizeToWav({
    required String text,
    required int sid,
    required String outputPath,
    String? lang,
    double speed = 1.0,
  }) async {
    final int? address = _handleAddress;
    final sherpa.OfflineTtsConfig? config = _config;
    if (address == null || config == null) {
      throw StateError('Kokoro engine is not loaded');
    }
    final int written = await Isolate.run<int>(() {
      sherpa.initBindings();
      final Stopwatch generate = Stopwatch()..start();
      final sherpa.OfflineTts tts = sherpa.OfflineTts.fromPtr(
        ptr: Pointer<Void>.fromAddress(address).cast(),
        config: config,
      );
      final sherpa.GeneratedAudio audio = tts.generateWithConfig(
        text: text,
        config: sherpa.OfflineTtsGenerationConfig(
          sid: sid,
          speed: speed,
          extra: lang == null
              ? const <String, Object>{}
              : <String, Object>{'lang': lang},
        ),
      );
      if (audio.samples.isEmpty) return -1;
      final int generateMs = generate.elapsedMilliseconds;
      normalizePeak(audio.samples);
      final bool ok = sherpa.writeWave(
        filename: outputPath,
        samples: audio.samples,
        sampleRate: audio.sampleRate,
      );
      return ok ? generateMs : -1;
    });
    if (written < 0) {
      throw StateError('Kokoro produced no audio');
    }
    AppLogger.debug('Kokoro generated in $written ms', tag: 'KokoroEngine');
  }
}
