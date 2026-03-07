import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/logger.dart';
import '../../domain/repositories/home_repository.dart';

/// Implementation of HomeRepository using just_audio
class HomeRepositoryImpl implements HomeRepository {
  final AudioPlayer _ttsPlayer = AudioPlayer();

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

      // Load and play the TTS audio file
      await _ttsPlayer.setFilePath(audioPath);

      // Set up completion handler
      _ttsPlayer.playerStateStream
          .where(
            (PlayerState state) =>
                state.processingState == ProcessingState.completed ||
                state.processingState == ProcessingState.idle,
          )
          .take(1)
          .listen((_) {
        // Remove file if requested
        if (removeFile) {
          try {
            File(audioPath).deleteSync();
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
      });

      // Start playback
      await _ttsPlayer.play();
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
  void dispose() {
    _ttsPlayer.dispose();
  }
}
