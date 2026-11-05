import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:yofardev_ai/core/di/service_locator.dart';
import 'package:yofardev_ai/core/models/voice_effect.dart';
import 'package:yofardev_ai/features/sound/data/datasources/kokoro_tts_datasource.dart';
import 'package:yofardev_ai/features/sound/sound.dart';

/// A [TtsSynthesizer] that speaks with the app's real voice (Kokoro) and
/// keeps a copy of every WAV for the capture's mux, so the showcase speaks
/// with the production engine while `wow_capture` still gets its audio list.
///
/// Before the first sentence, [ensureModel] copies an already-installed model
/// from [modelSource] into this app's support directory (the simulator gets a
/// fresh container on every run; the harness blocks network, so the download
/// path can never run) and [ensureReady] waits for the engine to load.
class KokoroCaptureSynthesizer implements TtsSynthesizer {
  KokoroCaptureSynthesizer(this.keep, {required this.modelSource});

  /// Where a working Kokoro model already sits on the host
  /// (`.../tts/kokoro-int8-multi-lang-v1_0`).
  final String modelSource;

  /// The harness's audio dir; copies land as `NN.wav` in synthesis order.
  final Directory keep;

  final List<({String text, String file})> spoken =
      <({String text, String file})>[];

  /// The installed model's folder name under `<appSupport>/tts/`.
  static const String modelId = 'kokoro-int8-multi-lang-v1_0';

  int _n = 0;

  /// Copies the model unless the support directory already has it.
  Future<void> ensureModel() async {
    final Directory support = await getApplicationSupportDirectory();
    final Directory target = Directory('${support.path}/tts/$modelId');
    if (target.existsSync()) {
      return;
    }
    final Directory source = Directory('$modelSource/$modelId');
    if (!source.existsSync()) {
      throw StateError('KokoroCaptureSynthesizer: no model at ${source.path}');
    }
    await target.create(recursive: true);
    await for (final FileSystemEntity entity in source.list(recursive: true)) {
      final String relative = entity.path.substring(source.path.length + 1);
      final String destination = '${target.path}/$relative';
      if (entity is Directory) {
        await Directory(destination).create(recursive: true);
      } else if (entity is File) {
        await entity.copy(destination);
      }
    }
  }

  /// Waits until the engine the DI registered is ready (bootstrapApp starts
  /// the install; the model is on disk, so this is a local load).
  Future<void> ensureReady({
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final Stopwatch sw = Stopwatch()..start();
    while (sw.elapsed < timeout) {
      final TtsEngineStatus status = getIt<TtsEngineStatusService>().current;
      if (status is TtsEngineReady) {
        return;
      }
      if (status is TtsEngineFailed) {
        throw StateError('KokoroCaptureSynthesizer: engine failed: $status');
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw TimeoutException(
      'KokoroCaptureSynthesizer: engine never became '
      'ready (last: ${getIt<TtsEngineStatusService>().current})',
    );
  }

  @override
  Future<String> synthesize({
    required String text,
    required String language,
    required VoiceEffect voiceEffect,
  }) async {
    await ensureReady();
    final String path = await getIt<KokoroTtsDatasource>().synthesize(
      text: text,
      language: language,
      voiceEffect: voiceEffect,
    );
    final String copy = '${keep.path}/${_n.toString().padLeft(2, '0')}.wav';
    _n++;
    await File(path).copy(copy);
    spoken.add((text: text, file: copy));
    return path;
  }

  @override
  Future<void> delete(String path) => getIt<KokoroTtsDatasource>().delete(path);
}
