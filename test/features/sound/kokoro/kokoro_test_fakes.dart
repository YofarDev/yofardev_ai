import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:yofardev_ai/features/sound/data/kokoro/kokoro_engine.dart';
import 'package:yofardev_ai/features/sound/data/kokoro/kokoro_model_paths.dart';
import 'package:yofardev_ai/features/sound/data/kokoro/model_archive_extractor.dart';
import 'package:yofardev_ai/features/sound/data/kokoro/voice_blender.dart';

const String testModelId = 'kokoro-test';
const List<String> testRequiredPaths = <String>['model.onnx', 'voices.bin'];

/// Serves [bytes] once per request; counts requests. [declaredLength]
/// overrides Content-Length (a short body), [status] the HTTP status.
class FakeModelServer {
  FakeModelServer({
    this.bytes = 1000,
    this.status = 200,
    this.declaredLength,
    this.gate,
  });

  final int bytes;

  /// Mutable: a test flips it to retry once "online".
  int status;
  final int? declaredLength;

  /// When set, the body waits for it (to hold a download in flight).
  final Completer<void>? gate;
  int requests = 0;

  http.Client client() => MockClient.streaming((
    http.BaseRequest request,
    http.ByteStream body,
  ) async {
    requests++;
    final Completer<void>? wait = gate;
    if (wait != null) await wait.future;
    final Stream<List<int>> chunks = Stream<List<int>>.fromIterable(<List<int>>[
      List<int>.filled(bytes ~/ 2, 1),
      List<int>.filled(bytes - bytes ~/ 2, 2),
    ]);
    return http.StreamedResponse(
      chunks,
      status,
      contentLength: declaredLength ?? bytes,
    );
  });
}

/// Writes [files] under `<destination>/<testModelId>/` (the sherpa-onnx
/// archive layout), or throws [error].
class FakeExtractor implements ModelArchiveExtractor {
  FakeExtractor({this.files = testRequiredPaths, this.error});

  final List<String> files;
  final Object? error;
  int calls = 0;

  @override
  Future<void> extractTarBz2({
    required String archivePath,
    required String destinationDir,
  }) async {
    calls++;
    if (!File(archivePath).existsSync()) {
      throw StateError('archive missing');
    }
    final Object? failure = error;
    if (failure != null) {
      Directory(
        p.join(destinationDir, testModelId),
      ).createSync(recursive: true);
      throw failure;
    }
    for (final String name in files) {
      File(p.join(destinationDir, testModelId, name))
        ..createSync(recursive: true)
        ..writeAsStringSync(name);
    }
  }
}

class SynthesisCall {
  const SynthesisCall({
    required this.text,
    required this.sid,
    required this.lang,
    required this.outputPath,
  });

  final String text;
  final int sid;
  final String? lang;
  final String outputPath;
}

class FakeKokoroEngine implements KokoroEngine {
  FakeKokoroEngine({this.loadError, bool loaded = false}) : _loaded = loaded;

  final Object? loadError;
  bool _loaded;
  int loads = 0;
  KokoroModelPaths? loadedPaths;
  final List<SynthesisCall> calls = <SynthesisCall>[];

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> load(KokoroModelPaths paths) async {
    loads++;
    final Object? failure = loadError;
    if (failure != null) throw failure;
    loadedPaths = paths;
    _loaded = true;
  }

  @override
  Future<void> synthesizeToWav({
    required String text,
    required int sid,
    required String outputPath,
    String? lang,
    double speed = 1.0,
  }) async {
    calls.add(
      SynthesisCall(text: text, sid: sid, lang: lang, outputPath: outputPath),
    );
  }
}

class FakeVoiceBlender implements VoiceBlender {
  FakeVoiceBlender({this.error});

  final Object? error;
  final List<KokoroModelPaths> applied = <KokoroModelPaths>[];

  @override
  Future<void> apply(KokoroModelPaths paths) async {
    final Object? failure = error;
    if (failure != null) throw failure;
    applied.add(paths);
  }
}
