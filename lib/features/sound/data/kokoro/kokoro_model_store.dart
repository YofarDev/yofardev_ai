import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../../../core/utils/logger.dart';
import '../../domain/tts_engine_status.dart';
import 'kokoro_model_paths.dart';
import 'kokoro_model_spec.dart';
import 'model_archive_extractor.dart';

/// The download did not complete (HTTP status, or fewer bytes than
/// announced).
class ModelDownloadException implements Exception {
  const ModelDownloadException(this.message);

  final String message;

  @override
  String toString() => 'ModelDownloadException: $message';
}

/// The archive unpacked, but a file the engine needs is missing.
class ModelLayoutException implements Exception {
  const ModelLayoutException(this.message);

  final String message;

  @override
  String toString() => 'ModelLayoutException: $message';
}

/// Owns the Kokoro model on disk, under `<appSupport>/tts/<modelId>/`:
/// download, extraction, verification and cleanup of leftovers.
class KokoroModelStore {
  KokoroModelStore({
    required http.Client client,
    required ModelArchiveExtractor extractor,
    required Future<Directory> Function() supportDirectoryProvider,
    String modelId = KokoroModelSpec.modelId,
    String downloadUrl = KokoroModelSpec.downloadUrl,
    List<String> requiredPaths = KokoroModelSpec.requiredPaths,
  }) : _client = client,
       _extractor = extractor,
       _supportDirectoryProvider = supportDirectoryProvider,
       _modelId = modelId,
       _downloadUrl = downloadUrl,
       _requiredPaths = requiredPaths;

  static const String _readyMarker = '.ready';

  final http.Client _client;
  final ModelArchiveExtractor _extractor;
  final Future<Directory> Function() _supportDirectoryProvider;
  final String _modelId;
  final String _downloadUrl;
  final List<String> _requiredPaths;

  Future<KokoroModelPaths>? _inFlight;

  Future<Directory> _ttsDir() async =>
      Directory(p.join((await _supportDirectoryProvider()).path, 'tts'));

  /// The ready marker is present and every required file exists.
  Future<bool> isInstalled() async {
    final Directory root = Directory(p.join((await _ttsDir()).path, _modelId));
    return _isComplete(root, requireMarker: true);
  }

  Future<bool> _isComplete(
    Directory root, {
    required bool requireMarker,
  }) async {
    if (requireMarker &&
        !await File(p.join(root.path, _readyMarker)).exists()) {
      return false;
    }
    for (final String relative in _requiredPaths) {
      final String path = p.join(root.path, relative);
      if (!await File(path).exists() && !await Directory(path).exists()) {
        return false;
      }
    }
    return true;
  }

  /// Downloads, extracts and verifies the model, reporting
  /// [TtsEngineStatus.downloading] and [TtsEngineStatus.extracting] through
  /// [onStatus]. Throws on failure, leaving no partial files behind.
  /// Single-flight: a second caller awaits the run in progress.
  Future<KokoroModelPaths> install({
    required void Function(TtsEngineStatus status) onStatus,
  }) {
    final Future<KokoroModelPaths>? running = _inFlight;
    if (running != null) return running;
    final Future<KokoroModelPaths> run = _install(onStatus).whenComplete(() {
      _inFlight = null;
    });
    _inFlight = run;
    return run;
  }

  Future<KokoroModelPaths> _install(
    void Function(TtsEngineStatus status) onStatus,
  ) async {
    final Directory ttsDir = await _ttsDir();
    final Directory root = Directory(p.join(ttsDir.path, _modelId));
    if (await _isComplete(root, requireMarker: true)) {
      return KokoroModelPaths(root.path);
    }

    await ttsDir.create(recursive: true);
    final File archive = File(p.join(ttsDir.path, '$_modelId.tar.bz2.part'));
    final Directory staging = Directory(p.join(ttsDir.path, '$_modelId.tmp'));
    await _wipeLeftovers(ttsDir, archive, staging);

    try {
      await _download(archive, onStatus);
      onStatus(const TtsEngineStatus.extracting());
      await staging.create(recursive: true);
      await _extractor.extractTarBz2(
        archivePath: archive.path,
        destinationDir: staging.path,
      );
      // sherpa-onnx archives hold one top folder named after the model.
      final Directory nested = Directory(p.join(staging.path, _modelId));
      final Directory unpacked = await nested.exists() ? nested : staging;
      if (!await _isComplete(unpacked, requireMarker: false)) {
        throw const ModelLayoutException('required model files are missing');
      }
      await File(p.join(unpacked.path, _readyMarker)).create();
      if (await root.exists()) await root.delete(recursive: true);
      await unpacked.rename(root.path);
      return KokoroModelPaths(root.path);
    } finally {
      await _deleteQuietly(archive);
      await _deleteQuietly(staging);
    }
  }

  /// Removes a half-written archive or staging folder from a killed run,
  /// and any other model folder (an older model id).
  Future<void> _wipeLeftovers(
    Directory ttsDir,
    File archive,
    Directory staging,
  ) async {
    await _deleteQuietly(archive);
    await _deleteQuietly(staging);
    await for (final FileSystemEntity entity in ttsDir.list()) {
      if (p.basename(entity.path) != _modelId) {
        await _deleteQuietly(entity);
      }
    }
  }

  Future<void> _download(
    File archive,
    void Function(TtsEngineStatus status) onStatus,
  ) async {
    onStatus(const TtsEngineStatus.downloading(null));
    final http.StreamedResponse response = await _client.send(
      http.Request('GET', Uri.parse(_downloadUrl)),
    );
    if (response.statusCode != 200) {
      throw ModelDownloadException('HTTP ${response.statusCode}');
    }
    final int? total = response.contentLength;
    final IOSink sink = archive.openWrite();
    int received = 0;
    int lastPercent = -1;
    try {
      await for (final List<int> chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total != null && total > 0) {
          final int percent = received * 100 ~/ total;
          // One status per percent: the stream yields thousands of chunks.
          if (percent != lastPercent) {
            lastPercent = percent;
            onStatus(TtsEngineStatus.downloading(received / total));
          }
        }
      }
    } finally {
      await sink.close();
    }
    if (total != null && received != total) {
      throw ModelDownloadException('received $received of $total bytes');
    }
    AppLogger.info(
      'Kokoro model downloaded ($received bytes)',
      tag: 'KokoroModelStore',
    );
  }

  Future<void> _deleteQuietly(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) await entity.delete(recursive: true);
    } catch (e) {
      AppLogger.debug('Failed to delete $entity: $e', tag: 'KokoroModelStore');
    }
  }
}
