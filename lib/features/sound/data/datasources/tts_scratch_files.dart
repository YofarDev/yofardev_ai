import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import '../../../../core/utils/logger.dart';

/// Scratch space for one-shot TTS audio, shared by every engine: the
/// OS-managed temp dir, timestamp-named WAVs deleted after playback and
/// swept after 10 minutes as a safety net.
abstract final class TtsScratchFiles {
  static Timer? _sweepTimer;

  /// Starts the periodic sweep of stale WAVs (idempotent).
  static void ensureSweeping() {
    _sweepTimer ??= Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(_cleanOldWavFiles()),
    );
  }

  static void stopSweeping() {
    _sweepTimer?.cancel();
    _sweepTimer = null;
  }

  static Future<String> directoryPath() async {
    final Directory tempDir = await getTemporaryDirectory();
    return tempDir.path;
  }

  /// A fresh `<temp>/<millisecondsSinceEpoch>.wav` path.
  static Future<String> newWavPath() async =>
      '${await directoryPath()}/${DateTime.now().millisecondsSinceEpoch}.wav';

  /// Best-effort delete of a played file.
  static Future<void> delete(String path) async {
    if (kIsWeb) {
      return;
    }
    try {
      final File file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      AppLogger.debug('Failed to delete TTS file: $e', tag: 'TtsService');
    }
  }

  /// Deletes timestamp-named wav files older than 10 minutes.
  static Future<void> _cleanOldWavFiles() async {
    try {
      final Directory dir = Directory(await directoryPath());
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
}
