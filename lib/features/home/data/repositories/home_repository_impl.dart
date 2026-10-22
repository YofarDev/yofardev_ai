import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/logger.dart';
import '../../../../core/utils/volume_fader.dart';
import '../../domain/repositories/home_repository.dart';

/// Implementation of HomeRepository using audioplayers
class HomeRepositoryImpl implements HomeRepository {
  final AudioPlayer _ttsPlayer = AudioPlayer();
  ProgressiveVolumeControl? _volumeControl;

  @override
  Future<void> playTts(
    String audioPath, {
    bool removeFile = true,
    bool soundEffectsEnabled = true,
    VoidCallback? onComplete,
  }) async {
    try {
      // Stop any currently playing audio
      await _ttsPlayer.stop();

      // Set up completion handler
      late final StreamSubscription<void> subscription;
      subscription = _ttsPlayer.onPlayerComplete.listen((_) {
        // Remove file if requested
        if (removeFile) {
          try {
            final File file = File(audioPath);
            if (file.existsSync()) {
              file.deleteSync();
            }
          } catch (e) {
            AppLogger.warning(
              'Failed to delete TTS file: $audioPath',
              tag: 'HomeRepository',
            );
          }
        }

        // Call completion callback
        if (onComplete != null) {
          onComplete();
        }
        subscription.cancel();
      });

      // Load and play the TTS audio file
      await _ttsPlayer.setSource(DeviceFileSource(audioPath));
      await _ttsPlayer.resume();
    } catch (e) {
      AppLogger.error('Error playing TTS', tag: 'HomeRepository', error: e);
      // Still call onComplete even on error to avoid hanging
      if (onComplete != null) {
        onComplete();
      }
      rethrow;
    }
  }

  @override
  Future<void> stopTts() async {
    try {
      await _ttsPlayer.stop();
    } catch (e) {
      AppLogger.error('Error stopping TTS', tag: 'HomeRepository', error: e);
    }
  }

  @override
  Future<void> startVolumeFade(bool fadeIn) async {
    if (kIsWeb || Platform.isMacOS) {
      // Volume control is unstable on macOS and unsupported on web.
      return;
    }

    // Initialize volume control on first use
    _volumeControl ??= ProgressiveVolumeControl();

    try {
      // Add a small delay to sync volume fade with the visual animation
      await Future<void>.delayed(const Duration(milliseconds: 800));
      _volumeControl!.startVolumeFade(fadeIn);
    } catch (e) {
      AppLogger.error('Error fading volume', tag: 'HomeRepository', error: e);
    }
  }

  @override
  void dispose() {
    _volumeControl?.cancel();
    _ttsPlayer.dispose();
  }
}
